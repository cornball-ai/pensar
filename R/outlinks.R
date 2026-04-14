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
#' @export
outlinks <- function(page, vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

    fp <- find_page(page, vault)
    if (is.null(fp)) {
        stop("Page not found: ", page)
    }

    links <- parse_wikilinks(fp)
    if (length(links) == 0L) {
        return(data.frame(target = character(0L),
                          exists = logical(0L),
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
#' @noRd
find_page <- function(page, vault) {
    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    matches <- all_md[vapply(all_md, name_from_path, character(1L)) == page]
    if (length(matches) == 0L) {
        return(NULL)
    }
    matches[1L]
}

