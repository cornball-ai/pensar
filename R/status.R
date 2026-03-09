#' @title Ontology status summary
#' @description Summary stats for the ontology index.

#' Get ontology status summary
#'
#' Returns summary statistics about the ontology: term count, relation count,
#' promoted terms, and unconfirmed suggestions.
#'
#' @param vault_path Path to the vault.
#' @return A list with class \code{pensar_status}.
#' @export
status <- function(vault_path = file.path(tools::R_user_dir("pensar", "cache"),
        "index")) {
    idx <- load_index(vault_path)

    confirmed <- idx$relations[idx$relations$confirmed == 1L,, drop = FALSE]
    suggested <- idx$relations[idx$relations$confirmed == 0L,, drop = FALSE]

    rel_types <- as.data.frame(table(confirmed$relation_type),
                               stringsAsFactors = FALSE)
    names(rel_types) <- c("relation_type", "n")

    result <- list(terms = nrow(idx$terms),
                   promoted = sum(idx$terms$promoted == 1L),
                   relations = nrow(confirmed), suggestions = nrow(suggested),
                   relation_types = rel_types)
    class(result) <- "pensar_status"
    result
}

#' @export
print.pensar_status <- function(x, ...) {
    cat("Ontology status:\n")
    cat(sprintf("  Terms:       %d (%d promoted)\n", x$terms, x$promoted))
    cat(sprintf("  Relations:   %d confirmed\n", x$relations))
    cat(sprintf("  Suggestions: %d unconfirmed\n", x$suggestions))
    if (nrow(x$relation_types) > 0L) {
        cat("  By type:\n")
        for (i in seq_len(nrow(x$relation_types))) {
            cat(sprintf("    %s: %d\n", x$relation_types$relation_type[i],
                        x$relation_types$n[i]))
        }
    }
    invisible(x)
}
