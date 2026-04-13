#' @title Vault status
#' @description Summary stats for a pensar vault.

#' Vault status summary
#'
#' Returns page counts by category, total pages, and wikilink count.
#'
#' @param vault Path to the vault directory.
#' @return A list with class \code{pensar_status}.
#' @export
status <- function(vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

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

    result <- list(
        raw_articles = raw_articles,
        raw_chats = raw_chats,
        raw_briefings = raw_briefings,
        raw_matrix = raw_matrix,
        wiki = wiki,
        total = total,
        vault = vault
    )
    class(result) <- "pensar_status"
    result
}

#' @export
print.pensar_status <- function(x, ...) {
    cat("Vault status:", x$vault, "\n")
    cat(sprintf("  Raw: articles  %d\n", x$raw_articles))
    cat(sprintf("  Raw: chats     %d\n", x$raw_chats))
    cat(sprintf("  Raw: briefings %d\n", x$raw_briefings))
    cat(sprintf("  Raw: matrix    %d\n", x$raw_matrix))
    cat(sprintf("  Wiki           %d\n", x$wiki))
    cat(sprintf("  Total          %d\n", x$total))
    invisible(x)
}
