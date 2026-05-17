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

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    control <- c("index.md", "log.md", "schema.md")
    all_md <- all_md[!basename(all_md) %in% control |
        dirname(all_md) != vault]
    page_names <- vapply(all_md, name_from_path, character(1L))

    unique_links <- unique(links)
    data.frame(
               target = unique_links,
               exists = unique_links %in% page_names,
               stringsAsFactors = FALSE
    )
}

#' Find a page file by name
#'
#' Registry-aware resolution. Resolution order:
#' \enumerate{
#'   \item exact relative-path match;
#'   \item exact \code{page_uid} match (from frontmatter \code{id}/\code{address});
#'   \item unique \code{node_id} (basename) match;
#'   \item ambiguous \code{node_id} match - warns and returns the
#'     first-sorted candidate, preserving today's behavior;
#'   \item frontmatter \code{aliases} match.
#' }
#' Returns \code{NULL} when nothing matches.
#' @noRd
find_page <- function(page, vault) {
    reg <- vault_registry(vault)
    if (nrow(reg) == 0L) {
        return(NULL)
    }

    path_match <- reg$path == page
    if (any(path_match)) {
        return(file.path(vault, reg$path[which(path_match)[1L]]))
    }

    uid_match <- !is.na(reg$page_uid) & reg$page_uid == page
    if (any(uid_match)) {
        return(file.path(vault, reg$path[which(uid_match)[1L]]))
    }

    nid_match <- reg$node_id == page
    nmatches <- sum(nid_match)
    if (nmatches == 1L) {
        return(file.path(vault, reg$path[nid_match]))
    }
    if (nmatches > 1L) {
        candidates <- sort(reg$path[nid_match])
        warning("ambiguous wikilink: '", page, "' matches ", nmatches,
                " pages: ", paste(candidates, collapse = ", "), call. = FALSE)
        return(file.path(vault, candidates[1L]))
    }

    alias_match <- vapply(reg$aliases,
                          function(a) is.character(a) && page %in% a,
                          logical(1L))
    if (any(alias_match)) {
        return(file.path(vault, reg$path[which(alias_match)[1L]]))
    }

    NULL
}

