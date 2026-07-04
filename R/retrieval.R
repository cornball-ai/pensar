#' @title Retrieval primitives
#' @description Read-only queries over a vault's page registry: search,
#' page context, related pages, and recent activity. Built on
#' \code{vault_registry()}; no disk writes.

#' Search pages by title, tags, aliases, or (optionally) body
#'
#' Substring match (case-insensitive). Default scope is registry-only
#' fields: \code{title}, \code{tags}, and frontmatter \code{aliases}.
#' With \code{in_body = TRUE} the body of each page is scanned too;
#' that reads every file and is slower.
#'
#' @param query Substring to search for.
#' @param vault Vault path.
#' @param type Optional type filter. When supplied, only pages whose
#'   registry \code{type} field equals \code{type} are considered.
#' @param in_body If \code{TRUE}, also search the body of each page.
#' @return A data.frame with columns \code{path}, \code{node_id},
#'   \code{title}, \code{type}, and \code{matched_in} (character
#'   identifying where the substring was found: \code{"title"},
#'   \code{"tag:<tag>"}, \code{"alias:<alias>"}, or \code{"body"}).
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("Body cites [[other]].", type = "articles",
#'        source = "demo-article", vault = v)
#' search_pages("demo", vault = v)
#' unlink(v, recursive = TRUE)
#' @export
search_pages <- function(query, vault = default_vault(), type = NULL,
                         in_body = FALSE) {
    if (!nzchar(query)) {
        return(empty_search_result())
    }
    vault <- normalizePath(vault, mustWork = TRUE)
    reg <- vault_registry(vault)
    if (nrow(reg) == 0L) {
        return(empty_search_result())
    }
    # Drop system control files (schema.md, log.md, index.md) so a
    # query like "vault" doesn't surface the seeded index/log/schema.
    reg <- reg[!reg$system_file,, drop = FALSE]
    if (!is.null(type)) {
        reg <- reg[!is.na(reg$type) & reg$type == type,, drop = FALSE]
    }
    if (nrow(reg) == 0L) {
        return(empty_search_result())
    }

    pat <- tolower(query)
    paths <- character(0L)
    nodes <- character(0L)
    titles <- character(0L)
    types <- character(0L)
    where <- character(0L)
    for (i in seq_len(nrow(reg))) {
        title <- reg$title[i]
        if (!is.na(title) && grepl(pat, tolower(title), fixed = TRUE)) {
            paths <- c(paths, reg$path[i])
            nodes <- c(nodes, reg$node_id[i])
            titles <- c(titles, title)
            types <- c(types, reg$type[i] %||% NA_character_)
            where <- c(where, "title")
        }
        for (tag in reg$tags[[i]]) {
            if (grepl(pat, tolower(tag), fixed = TRUE)) {
                paths <- c(paths, reg$path[i])
                nodes <- c(nodes, reg$node_id[i])
                titles <- c(titles, title %||% NA_character_)
                types <- c(types, reg$type[i] %||% NA_character_)
                where <- c(where, sprintf("tag:%s", tag))
            }
        }
        for (alias in reg$aliases[[i]]) {
            if (grepl(pat, tolower(alias), fixed = TRUE)) {
                paths <- c(paths, reg$path[i])
                nodes <- c(nodes, reg$node_id[i])
                titles <- c(titles, title %||% NA_character_)
                types <- c(types, reg$type[i] %||% NA_character_)
                where <- c(where, sprintf("alias:%s", alias))
            }
        }
        if (isTRUE(in_body)) {
            body <- extract_body(file.path(vault, reg$path[i]))
            if (nzchar(body) && grepl(pat, tolower(body), fixed = TRUE)) {
                paths <- c(paths, reg$path[i])
                nodes <- c(nodes, reg$node_id[i])
                titles <- c(titles, title %||% NA_character_)
                types <- c(types, reg$type[i] %||% NA_character_)
                where <- c(where, "body")
            }
        }
    }
    data.frame(path = paths, node_id = nodes, title = titles, type = types,
               matched_in = where, stringsAsFactors = FALSE)
}

#' @noRd
empty_search_result <- function() {
    data.frame(path = character(0L), node_id = character(0L),
               title = character(0L), type = character(0L),
               matched_in = character(0L), stringsAsFactors = FALSE)
}

#' Structured context for a single page
#'
#' Returns the frontmatter, a short body head, the page's outlinks, and
#' its backlinks in one struct so callers don't have to call four
#' functions. Resolves \code{name} through the registry, so a query
#' like \code{"Notes/Foo"} works alongside the basename style.
#'
#' @param name Page name, path, alias, or page_uid.
#' @param vault Vault path.
#' @param body_chars Maximum chars of body to return. Default 300.
#' @return A list with components \code{path} (relative path),
#'   \code{node_id}, \code{frontmatter} (named list), \code{body_head}
#'   (string), \code{outlinks} (data.frame), \code{backlinks}
#'   (data.frame), \code{class = "pensar_page_context"}.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' fp <- ingest("Body text here.", type = "articles", source = "demo",
#'              vault = v)
#' ctx <- page_context(tools::file_path_sans_ext(basename(fp)),
#'                     vault = v)
#' names(ctx)
#' unlink(v, recursive = TRUE)
#' @export
page_context <- function(name, vault = default_vault(), body_chars = 300L) {
    vault <- normalizePath(vault, mustWork = TRUE)
    fp <- find_page(name, vault)
    if (is.null(fp)) {
        stop("Page not found: ", name)
    }
    rel <- substring(fp, nchar(vault) + 2L)
    reg <- vault_registry(vault)
    row <- reg[reg$path == rel,, drop = FALSE]
    fm <- parse_frontmatter(fp)
    body <- extract_body(fp, body_chars)

    ol <- tryCatch(outlinks(name, vault = vault),
                   error = function(e) {
        data.frame(target = character(0L), exists = logical(0L),
                   stringsAsFactors = FALSE)
    })
    bl <- backlinks(name, vault = vault)

    structure(
              list(path = rel,
                   node_id = row$node_id %||% name,
                   frontmatter = fm,
                   body_head = body,
                   outlinks = ol,
                   backlinks = bl),
              class = "pensar_page_context"
    )
}

#' Pages related to a target by shared tags + co-citation
#'
#' Heuristic scoring: \code{score = #shared tags + #shared outlinks}.
#' Both are unweighted set intersections. The target page itself is
#' excluded from the result. Ties are broken by alphabetical
#' \code{path}.
#'
#' @param name Page to find related pages for. Same resolution as
#'   \code{find_page()}.
#' @param vault Vault path.
#' @param k Number of related pages to return. Default 10.
#' @return A data.frame with columns \code{path}, \code{node_id},
#'   \code{title}, \code{score}, sorted by score descending then path.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' fp <- ingest("[[other]]", type = "articles", source = "a",
#'              tags = c("x", "y"), vault = v)
#' ingest("[[other]]", type = "articles", source = "b",
#'        tags = c("x"), vault = v)
#' related_pages(tools::file_path_sans_ext(basename(fp)),
#'               vault = v, k = 5)
#' unlink(v, recursive = TRUE)
#' @export
related_pages <- function(name, vault = default_vault(), k = 10L) {
    vault <- normalizePath(vault, mustWork = TRUE)
    fp <- find_page(name, vault)
    if (is.null(fp)) {
        stop("Page not found: ", name)
    }
    target_rel <- substring(fp, nchar(vault) + 2L)

    reg <- vault_registry(vault)
    self_row <- reg[reg$path == target_rel,, drop = FALSE]
    if (nrow(self_row) == 0L) {
        return(empty_related_result())
    }
    target_tags <- self_row$tags[[1L]]
    target_links <- self_row$links_out[[1L]]

    others <- reg[reg$path != target_rel & !reg$system_file,,
        drop = FALSE]
    if (nrow(others) == 0L) {
        return(empty_related_result())
    }

    # Canonicalize the target's outlinks to resolved relative paths.
    # Co-citation scoring then intersects on path, so [[Foo]] and
    # [[Notes/Foo]] are recognized as the same target.
    target_link_paths <- resolved_link_set(target_links, vault)

    scores <- integer(nrow(others))
    for (i in seq_len(nrow(others))) {
        shared_tags <- length(intersect(target_tags, others$tags[[i]]))
        peer_link_paths <- resolved_link_set(others$links_out[[i]], vault)
        shared_links <- length(intersect(target_link_paths, peer_link_paths))
        scores[i] <- shared_tags + shared_links
    }
    keep <- scores > 0L
    if (!any(keep)) {
        return(empty_related_result())
    }
    others <- others[keep,, drop = FALSE]
    scores <- scores[keep]
    ord <- order(-scores, others$path)
    top <- utils::head(ord, k)
    data.frame(path = others$path[top], node_id = others$node_id[top],
               title = others$title[top], score = scores[top],
               stringsAsFactors = FALSE)
}

#' Resolve a set of wikilink targets to unique relative paths
#'
#' Unresolvable targets drop out. Used by \code{related_pages()} so
#' co-citation scoring treats \code{[[Foo]]} and \code{[[Notes/Foo]]}
#' as the same target when both resolve to \code{Notes/Foo.md}.
#' @noRd
resolved_link_set <- function(links, vault) {
    if (length(links) == 0L) {
        return(character(0L))
    }
    resolved <- vapply(links, resolve_target_path, character(1L), vault = vault)
    unique(resolved[!is.na(resolved)])
}

#' @noRd
empty_related_result <- function() {
    data.frame(path = character(0L), node_id = character(0L),
               title = character(0L), score = integer(0L),
               stringsAsFactors = FALSE)
}

#' Recent vault activity from log.md
#'
#' Parses entries from \code{log.md} (the format written by
#' \code{log_entry()}). Returns entries from the last \code{days} days,
#' newest first.
#'
#' @param vault Vault path.
#' @param days Window in days. Default 7.
#' @return A data.frame with columns \code{timestamp} (POSIXct),
#'   \code{operation}, \code{message}, sorted newest first.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' recent_activity(v, days = 30)
#' unlink(v, recursive = TRUE)
#' @export
recent_activity <- function(vault = default_vault(), days = 7L) {
    vault <- normalizePath(vault, mustWork = TRUE)
    log_path <- file.path(vault, "log.md")
    if (!file.exists(log_path)) {
        return(empty_activity_result())
    }
    lines <- readLines(log_path, warn = FALSE)
    pat <- "^- \\*\\*([^*]+)\\*\\* \\[([^]]+)\\] (.*)$"
    matches <- regmatches(lines, regexec(pat, lines))
    parsed <- Filter(function(m) length(m) == 4L, matches)
    if (length(parsed) == 0L) {
        return(empty_activity_result())
    }
    ts_str <- vapply(parsed, function(m) m[[2L]], character(1L))
    op <- vapply(parsed, function(m) m[[3L]], character(1L))
    msg <- vapply(parsed, function(m) m[[4L]], character(1L))

    ts <- as.POSIXct(ts_str, format = "%Y-%m-%dT%H:%M:%S", tz = "")
    cutoff <- Sys.time() - as.difftime(days, units = "days")
    keep <- !is.na(ts) & ts >= cutoff
    if (!any(keep)) {
        return(empty_activity_result())
    }
    ts <- ts[keep]
    op <- op[keep]
    msg <- msg[keep]
    ord <- order(ts, decreasing = TRUE)
    data.frame(timestamp = ts[ord], operation = op[ord], message = msg[ord],
               stringsAsFactors = FALSE)
}

#' @noRd
empty_activity_result <- function() {
    data.frame(timestamp = as.POSIXct(character(0L)),
               operation = character(0L), message = character(0L),
               stringsAsFactors = FALSE)
}

#' Extract the body of a page (sans frontmatter)
#'
#' Returns the first \code{n_chars} characters of the body, or all of
#' it when \code{n_chars} is \code{NULL}.
#' @noRd
extract_body <- function(filepath, n_chars = NULL) {
    lines <- readLines(filepath, warn = FALSE)
    if (length(lines) > 0L && trimws(lines[1L]) == "---") {
        end <- which(trimws(lines[-1L]) == "---")[1L]
        if (!is.na(end)) {
            start <- end + 2L
            if (start > length(lines)) {
                return("")
            }
            lines <- lines[start:length(lines)]
        }
    }
    body <- trimws(paste(lines, collapse = "\n"))
    if (is.null(n_chars) || nchar(body) <= n_chars) {
        body
    } else {
        substring(body, 1L, n_chars)
    }
}
