#' @title Page inspection
#' @description Drill down into a page: content, outlinks, and backlinks.

#' Show a page with its connections
#'
#' Returns the page content alongside its outgoing and incoming wikilinks.
#' Use this when you need to review or edit a page: the outlinks show what
#' raw sources the page cites; the backlinks show what depends on it.
#'
#' @param page Page name (without \code{.md} extension).
#' @param vault Path to the vault directory.
#' @return A list with class \code{pensar_page}.
#' @export
show_page <- function(page, vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)
    fp <- find_page(page, vault)
    if (is.null(fp)) {
        stop("Page not found: ", page)
    }

    content <- readLines(fp, warn = FALSE)
    fm <- parse_frontmatter(fp)
    out <- outlinks(page, vault)
    back <- backlinks(page, vault)

    result <- list(
                   page = page,
                   file = make_relative(fp, vault),
                   title = fm$title %||% page,
                   type = fm$type %||% NA_character_,
                   tags = fm$tags %||% character(0L),
                   content = content,
                   outlinks = out,
                   backlinks = back,
                   vault = vault
    )
    class(result) <- "pensar_page"
    result
}

#' @export
print.pensar_page <- function(x, ...) {
    cat("Page:", x$page, "\n")
    cat("File:", x$file, "\n")
    cat("Title:", x$title, "\n")
    if (!is.na(x$type)) {
        cat("Type:", x$type, "\n")
    }
    if (length(x$tags) > 0L) {
        cat("Tags:", paste(x$tags, collapse = ", "), "\n")
    }

    cat(sprintf("\nOutlinks (%d): what this page cites\n", nrow(x$outlinks)))
    if (nrow(x$outlinks) > 0L) {
        for (i in seq_len(nrow(x$outlinks))) {
            if (x$outlinks$exists[i]) {
                marker <- " "
            } else {
                marker <- "!"
            }
            cat(sprintf("  %s [[%s]]\n", marker, x$outlinks$target[i]))
        }
        if (any(!x$outlinks$exists)) {
            cat("  (! = broken link, target does not exist)\n")
        }
    }

    cat(sprintf("\nBacklinks (%d): what cites this page\n", nrow(x$backlinks)))
    if (nrow(x$backlinks) > 0L) {
        for (i in seq_len(nrow(x$backlinks))) {
            cat(sprintf("  <- [[%s]] (%s)\n",
                        x$backlinks$source[i],
                        x$backlinks$file[i]))
        }
    }

    cat("\n--- Content ---\n")
    cat(x$content, sep = "\n")

    invisible(x)
}

