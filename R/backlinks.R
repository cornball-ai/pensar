#' @title Backlink discovery
#' @description Find pages that link to a given page via wikilinks.

#' Find backlinks to a page
#'
#' Scans all markdown files in the vault for \code{[[wikilinks]]} that
#' reference the target page.
#'
#' @param page Page name (without \code{.md} extension).
#' @param vault Path to the vault directory.
#' @return A data.frame with columns \code{source} (page name) and
#'   \code{file} (path relative to the vault).
#' @export
backlinks <- function(page, vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    control <- c("index.md", "log.md", "schema.md")
    all_md <- all_md[!basename(all_md) %in% control |
        dirname(all_md) != vault]

    sources <- character(0L)
    files <- character(0L)

    for (fp in all_md) {
        links <- parse_wikilinks(fp)
        if (page %in% links) {
            sources <- c(sources, name_from_path(fp))
            files <- c(files, make_relative(fp, vault))
        }
    }

    data.frame(source = sources, file = files, stringsAsFactors = FALSE)
}

