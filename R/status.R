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

    if (vault_is_adopted(vault)) {
        return(status_adopted(vault, src))
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
    if (isTRUE(x$adopted)) {
        cat(sprintf("Vault status: %s (via %s) [adopted]\n", x$vault, label))
        if (length(x$by_type) > 0L) {
            type_names <- names(x$by_type)
            for (i in seq_along(x$by_type)) {
                cat(sprintf("  %-14s %d\n", type_names[i], x$by_type[i]))
            }
        }
        cat(sprintf("  %-14s %d\n", "Total", x$total))
        return(invisible(x))
    }
    cat(sprintf("Vault status: %s (via %s)\n", x$vault, label))
    cat(sprintf("  Raw: articles  %d\n", x$raw_articles))
    cat(sprintf("  Raw: chats     %d\n", x$raw_chats))
    cat(sprintf("  Raw: briefings %d\n", x$raw_briefings))
    cat(sprintf("  Raw: matrix    %d\n", x$raw_matrix))
    cat(sprintf("  Wiki           %d\n", x$wiki))
    cat(sprintf("  Total          %d\n", x$total))
    invisible(x)
}

#' Registry-driven status for adopted vaults
#' @noRd
status_adopted <- function(vault, src) {
    reg <- vault_registry(vault)
    page_rows <- reg[!reg$system_file,, drop = FALSE]

    if (nrow(page_rows) == 0L) {
        by_type <- integer(0L)
        names(by_type) <- character(0L)
    } else {
        type_col <- ifelse(is.na(page_rows$type) | page_rows$type == "",
                           "(untyped)", page_rows$type)
        by_type <- sort(table(type_col), decreasing = TRUE)
    }

    result <- list(adopted = TRUE, by_type = by_type,
                   total = nrow(page_rows), vault = vault, source = src)
    class(result) <- "pensar_status"
    result
}

