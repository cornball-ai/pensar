#' @title Emit OBO format
#' @description Snapshot the ontology to OBO format.

#' Emit the ontology in OBO format
#'
#' Writes the current ontology to a file in OBO 1.4 format.
#'
#' @param vault_path Path to the vault.
#' @param outfile Path to write the OBO file. If NULL, writes to stdout.
#' @return The output path (invisibly), or NULL if written to stdout.
#' @export
emit_obo <- function(vault_path = file.path(tools::R_user_dir("pensar",
            "cache"),
        "index"),
                     outfile = NULL) {
    idx <- load_index(vault_path)

    terms <- idx$terms
    relations <- idx$relations[idx$relations$confirmed == 1L,, drop = FALSE]

    lines <- character(0L)

    # Header
    lines <- c(lines, "format-version: 1.4",
               sprintf("date: %s", format(Sys.time(), "%d:%m:%Y %H:%M")),
               sprintf("saved-by: pensar %s", utils::packageVersion("pensar")),
               "")

    # Term stanzas
    for (i in seq_len(nrow(terms))) {
        t <- terms[i,]
        lines <- c(lines, "[Term]")
        lines <- c(lines, sprintf("id: %s", t$id))
        lines <- c(lines, sprintf("name: %s", t$name))

        # Aliases as synonyms (pipe-separated)
        if (!is.na(t$aliases) && nchar(t$aliases) > 0L) {
            als <- strsplit(t$aliases, "\\|")[[1L]]
            for (a in trimws(als)) {
                lines <- c(lines, sprintf('synonym: "%s" RELATED []', a))
            }
        }

        # Relations
        term_rels <- relations[relations$subject_id == t$id,, drop = FALSE]
        for (j in seq_len(nrow(term_rels))) {
            r <- term_rels[j,]
            obj_name <- terms$name[terms$id == r$object_id]
            if (length(obj_name) == 0L) {
                obj_name <- r$object_id
            }
            if (r$relation_type == "is_a") {
                lines <- c(lines,
                           sprintf("is_a: %s ! %s", r$object_id, obj_name))
            } else {
                lines <- c(lines,
                           sprintf("relationship: %s %s ! %s", r$relation_type,
                                   r$object_id, obj_name))
            }
        }

        lines <- c(lines, "")
    }

    if (is.null(outfile)) {
        writeLines(lines)
        invisible(NULL)
    } else {
        writeLines(lines, outfile)
        invisible(outfile)
    }
}
