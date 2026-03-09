#' @title Add terms and relations programmatically
#' @description Bulk-insert terms and relations into the ontology, with
#'   optional persistent annotation files.

#' Add terms and relations to the ontology
#'
#' Insert terms and/or relations directly into the index. Optionally
#' writes a markdown annotation file to persist additions across re-indexes.
#'
#' @param terms Character vector of term names to add.
#' @param relations A data.frame with columns: subject, relation_type, object.
#' @param vault_path Path to the vault.
#' @param annotations_dir Directory for persistent annotation files. Set to
#'   NULL to skip writing annotations. Default: \code{~/.cache/R/pensar/annotations}.
#' @return A list with counts of terms and relations added (invisibly).
#' @export
add <- function(terms = NULL, relations = NULL,
                vault_path = file.path(tools::R_user_dir("pensar", "cache"), "index"),
                annotations_dir = file.path(tools::R_user_dir("pensar", "cache"),
        "annotations")) {
    idx <- load_index(vault_path)

    n_terms <- 0L
    n_rels <- 0L

    # Insert terms
    if (!is.null(terms) && length(terms) > 0L) {
        for (t in terms) {
            if (t %in% idx$terms$id) {
                next
            }
            idx$terms <- rbind(idx$terms,
                               data.frame(id = t, name = t, filepath = NA_character_,
                    aliases = "", promoted = 0L,
                    updated_at = now_ts(), stringsAsFactors = FALSE))
            n_terms <- n_terms + 1L
        }
    }

    # Insert relations
    if (!is.null(relations) && nrow(relations) > 0L) {
        expected <- c("subject", "relation_type", "object")
        if (!all(expected %in% names(relations))) {
            stop("relations must have columns: subject, relation_type, object")
        }
        for (i in seq_len(nrow(relations))) {
            subj <- relations$subject[i]
            rel <- relations$relation_type[i]
            obj <- relations$object[i]

            # Ensure subject and object exist as terms
            if (!subj %in% idx$terms$id) {
                idx$terms <- rbind(idx$terms,
                                   data.frame(id = subj, name = subj,
                        filepath = NA_character_, aliases = "",
                        promoted = 0L, updated_at = now_ts(),
                        stringsAsFactors = FALSE))
            }
            if (!obj %in% idx$terms$id) {
                idx$terms <- rbind(idx$terms,
                                   data.frame(id = obj, name = obj,
                        filepath = NA_character_, aliases = "",
                        promoted = 0L, updated_at = now_ts(),
                        stringsAsFactors = FALSE))
            }

            # Check for duplicate
            dup <- idx$relations$subject_id == subj &
            idx$relations$relation_type == rel &
            idx$relations$object_id == obj
            if (any(dup)) {
                next
            }

            idx$relations <- rbind(idx$relations,
                                   data.frame(subject_id = subj, relation_type = rel,
                    object_id = obj, confirmed = 1L,
                    source = "manual", stringsAsFactors = FALSE))
            n_rels <- n_rels + 1L
        }
    }

    save_index(idx, vault_path)

    # Write persistent annotation file
    if (!is.null(annotations_dir)) {
        write_annotation(annotations_dir, terms, relations)
    }

    message(sprintf("Added %d term(s), %d relation(s)", n_terms, n_rels))
    invisible(list(terms = n_terms, relations = n_rels))
}

#' Write an annotation markdown file to persist additions
#' @noRd
write_annotation <- function(annotations_dir, terms, relations) {
    dir.create(annotations_dir, recursive = TRUE, showWarnings = FALSE)

    timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
    outfile <- file.path(annotations_dir, paste0("add-", timestamp, ".md"))

    lines <- c("---", "source: pensar::add",
               sprintf("created: %s", Sys.time()), "---")

    if (!is.null(terms) && length(terms) > 0L) {
        lines <- c(lines, "", "## Terms", "")
        for (t in terms) {
            lines <- c(lines, sprintf("- %s", t))
        }
    }

    if (!is.null(relations) && nrow(relations) > 0L) {
        lines <- c(lines, "", "## Relations", "")
        for (i in seq_len(nrow(relations))) {
            lines <- c(lines,
                       sprintf("- %s %s %s", relations$subject[i],
                               relations$relation_type[i], relations$object[i]))
        }
    }

    writeLines(lines, outfile)
    outfile
}
