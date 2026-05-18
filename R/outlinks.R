#' @title Outlink discovery
#' @description Find the pages a given page cites via wikilinks.

#' Find outlinks from a page
#'
#' Scans a single page for \code{[[wikilinks]]} and returns the targets.
#' Mirror of \code{backlinks()} in the forward direction.
#'
#' @param page Page name (without \code{.md} extension).
#' @param vault Path to the vault directory.
#' @return A data.frame with columns \code{target} (page name) and
#'   \code{exists} (logical: whether the target page exists in the vault).
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' fp <- ingest("Cites [[seed]] and [[missing]].", type = "articles",
#'              source = "demo", vault = v)
#' outlinks(tools::file_path_sans_ext(basename(fp)), vault = v)
#' unlink(v, recursive = TRUE)
#' @export
outlinks <- function(page, vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

    fp <- find_page(page, vault)
    if (is.null(fp)) {
        stop("Page not found: ", page)
    }

    links <- parse_wikilinks(fp)
    if (length(links) == 0L) {
        return(data.frame(target = character(0L), exists = logical(0L),
                          stringsAsFactors = FALSE))
    }

    unique_links <- unique(links)
    # Existence check goes through find_page() so path-style links
    # (`[[Notes/Foo]]`), .md-suffix links, frontmatter aliases, and
    # block-anchor variants all resolve correctly. Ambiguity warnings
    # from find_page() surface to the caller; this is an interactive
    # entry point and the user wants to know.
    exists_vec <- vapply(unique_links,
                         function(t) !is.null(find_page(t, vault)),
                         logical(1L))
    data.frame(target = unique_links, exists = exists_vec,
               stringsAsFactors = FALSE)
}

#' Resolve a wikilink target to a relative vault path
#'
#' Thin wrapper over \code{find_page()} that returns the canonical
#' relative path the target resolves to (or \code{NA_character_} if
#' nothing matches). Used by graph consumers (\code{backlinks()},
#' \code{lint()}) so two queries pointing at the same page (e.g.,
#' \code{"Foo"} and \code{"Notes/Foo"}) compare equal.
#'
#' Suppresses the ambiguous-basename warning from \code{find_page()};
#' graph operations don't surface it on every iteration. Interactive
#' callers of \code{find_page()} / \code{outlinks()} still see it.
#' @noRd
resolve_target_path <- function(query, vault) {
    fp <- withCallingHandlers(find_page(query, vault),
                              warning = function(w) {
                                  invokeRestart("muffleWarning")
                              })
    if (is.null(fp)) {
        return(NA_character_)
    }
    substring(fp, nchar(vault) + 2L)
}

#' Find a page file by name
#'
#' Registry-aware resolution. The query is first normalized by
#' \code{normalize_wikilink_target()} so anchors (\code{#section},
#' \code{#^block-id}) and surrounding whitespace are stripped.
#' Resolution order:
#' \enumerate{
#'   \item exact relative-path match (with or without a \code{.md} suffix);
#'   \item path match against \code{tools::file_path_sans_ext(reg$path)}
#'     so \code{[[Notes/Foo]]} resolves to \code{Notes/Foo.md};
#'   \item exact \code{page_uid} match (from frontmatter
#'     \code{id}/\code{address});
#'   \item unique \code{node_id} (basename) match;
#'   \item ambiguous \code{node_id} - warns and returns the first-sorted
#'     candidate, preserving today's silent first-match behavior;
#'   \item frontmatter \code{aliases} match.
#' }
#' Returns \code{NULL} when nothing matches.
#' @noRd
find_page <- function(page, vault) {
    page <- normalize_wikilink_target(page)
    if (!nzchar(page)) {
        return(NULL)
    }

    reg <- vault_registry(vault)
    if (nrow(reg) == 0L) {
        return(NULL)
    }

    path_candidates <- c(page, paste0(page, ".md"))
    path_match <- reg$path %in% path_candidates
    if (any(path_match)) {
        return(file.path(vault, reg$path[which(path_match)[1L]]))
    }

    paths_no_ext <- tools::file_path_sans_ext(reg$path)
    no_ext_match <- paths_no_ext == page
    if (any(no_ext_match)) {
        return(file.path(vault, reg$path[which(no_ext_match)[1L]]))
    }

    # Fuzzy resolution (page_uid, node_id, alias) prefers non-system
    # rows so that, e.g., bare `[[tags]]` resolves to a user-authored
    # `wiki/tags.md` rather than `_proposals/tags.md`. Exact-path
    # queries above can still target system files when the caller
    # writes the full path.
    content <- reg[!reg$system_file, , drop = FALSE]

    uid_match <- !is.na(content$page_uid) & content$page_uid == page
    if (any(uid_match)) {
        return(file.path(vault,
                         content$path[which(uid_match)[1L]]))
    }

    nid_match <- content$node_id == page
    nmatches <- sum(nid_match)
    if (nmatches == 1L) {
        return(file.path(vault, content$path[nid_match]))
    }
    if (nmatches > 1L) {
        candidates <- sort(content$path[nid_match])
        warning("ambiguous wikilink: '", page, "' matches ", nmatches,
                " pages: ", paste(candidates, collapse = ", "),
                call. = FALSE)
        return(file.path(vault, candidates[1L]))
    }

    alias_match <- vapply(content$aliases,
                          function(a) is.character(a) && page %in% a,
                          logical(1L))
    if (any(alias_match)) {
        return(file.path(vault,
                         content$path[which(alias_match)[1L]]))
    }

    NULL
}

