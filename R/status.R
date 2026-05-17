#' @title Vault status
#' @description Summary stats for a pensar vault.

#' Vault status summary
#'
#' Returns page counts by category, total pages, and wikilink count.
#' When \code{vault} is \code{NULL} (default), the vault is resolved
#' via \code{PENSAR_VAULT}, walk-up from \code{getwd()}, or
#' \code{options("pensar.vault")}, and the source of the match is
#' recorded for display.
#'
#' @param vault Path to the vault directory. \code{NULL} (default)
#'   triggers automatic resolution.
#' @return A list with class \code{pensar_status}, including the
#'   resolved \code{vault} path and a \code{source} label
#'   (\code{"env"}, \code{"walkup"}, \code{"walkup-subdir"},
#'   \code{"option"}, or \code{"explicit"}).
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' status(v)
#' unlink(v, recursive = TRUE)
#' @export
status <- function(vault = NULL) {
    if (is.null(vault)) {
        resolved <- resolve_vault()
        vault <- normalizePath(resolved$path, mustWork = TRUE)
        src <- resolved$source
    } else {
        vault <- normalizePath(vault, mustWork = TRUE)
        src <- "explicit"
    }

    count_md <- function(dir) {
        if (!dir.exists(dir)) {
            return(0L)
        }
        length(list.files(dir, pattern = "\\.md$", recursive = TRUE))
    }

    raw_articles <- count_md(file.path(vault, "raw", "articles"))
    raw_chats <- count_md(file.path(vault, "raw", "chats"))
    raw_briefings <- count_md(file.path(vault, "raw", "briefings"))
    raw_matrix <- count_md(file.path(vault, "raw", "matrix"))
    wiki <- count_md(file.path(vault, "wiki"))
    total <- raw_articles + raw_chats + raw_briefings + raw_matrix + wiki

    result <- list(raw_articles = raw_articles, raw_chats = raw_chats,
                   raw_briefings = raw_briefings, raw_matrix = raw_matrix,
                   wiki = wiki, total = total, vault = vault, source = src)
    class(result) <- "pensar_status"
    result
}

#' @export
print.pensar_status <- function(x, ...) {
    label <- switch(x$source, env = "PENSAR_VAULT", walkup = "walk-up",
                    "walkup-subdir" = "./vault walk-up",
                    option = "options(\"pensar.vault\")",
                    explicit = "explicit vault argument", x$source)
    cat(sprintf("Vault status: %s (via %s)\n", x$vault, label))
    cat(sprintf("  Raw: articles  %d\n", x$raw_articles))
    cat(sprintf("  Raw: chats     %d\n", x$raw_chats))
    cat(sprintf("  Raw: briefings %d\n", x$raw_briefings))
    cat(sprintf("  Raw: matrix    %d\n", x$raw_matrix))
    cat(sprintf("  Wiki           %d\n", x$wiki))
    cat(sprintf("  Total          %d\n", x$total))
    invisible(x)
}

