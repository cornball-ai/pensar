#' @title Index storage helpers
#' @description Load and save the ontology index as TSV files.

#' Get the index directory for a vault
#' @noRd
index_dir <- function(vault_path) {
    file.path(vault_path, ".pensar")
}

#' Empty index
#' @noRd
empty_index <- function() {
    list(terms = data.frame(id = character(), name = character(),
                            filepath = character(), aliases = character(),
                            promoted = integer(), updated_at = character(),
                            stringsAsFactors = FALSE),
         relations = data.frame(subject_id = character(),
                                relation_type = character(),
                                object_id = character(), confirmed = integer(),
                                source = character(), stringsAsFactors = FALSE), files = data.frame(filepath = character(),
            hash = character(), parsed_at = character(),
            stringsAsFactors = FALSE))
}

#' Load the ontology index from TSV files
#'
#' @param vault_path Path to the markdown vault.
#' @param create If TRUE, return empty index instead of erroring when missing.
#' @return A list with components: terms, relations, files.
#' @noRd
load_index <- function(vault_path, create = FALSE) {
    idx_d <- index_dir(vault_path)

    if (!dir.exists(idx_d)) {
        if (!create) {
            stop("Index not found: ", idx_d, ". Run index_vault() first.")
        }
        return(empty_index())
    }

    result <- empty_index()

    terms_f <- file.path(idx_d, "terms.tsv")
    if (file.exists(terms_f) && file.size(terms_f) > 0L) {
        result$terms <- read.delim(terms_f, stringsAsFactors = FALSE,
                                   colClasses = "character")
        result$terms$promoted <- as.integer(result$terms$promoted)
    }

    rels_f <- file.path(idx_d, "relations.tsv")
    if (file.exists(rels_f) && file.size(rels_f) > 0L) {
        result$relations <- read.delim(rels_f, stringsAsFactors = FALSE,
                                       colClasses = "character")
        result$relations$confirmed <- as.integer(result$relations$confirmed)
    }

    files_f <- file.path(idx_d, "files.tsv")
    if (file.exists(files_f) && file.size(files_f) > 0L) {
        result$files <- read.delim(files_f, stringsAsFactors = FALSE,
                                   colClasses = "character")
    }

    result
}

#' Save the ontology index to TSV files
#'
#' @param idx A list with components: terms, relations, files.
#' @param vault_path Path to the markdown vault.
#' @noRd
save_index <- function(idx, vault_path) {
    d <- index_dir(vault_path)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)

    write.table(idx$terms, file.path(d, "terms.tsv"), sep = "\t",
                row.names = FALSE, quote = FALSE)
    write.table(idx$relations, file.path(d, "relations.tsv"), sep = "\t",
                row.names = FALSE, quote = FALSE)
    write.table(idx$files, file.path(d, "files.tsv"), sep = "\t",
                row.names = FALSE, quote = FALSE)

    invisible(d)
}

#' Timestamp helper
#' @noRd
now_ts <- function() {
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
}
