#' @title Suggest typed relations
#' @description Propose typed edges from untyped wikilinks.

#' Suggest typed relations from untyped links
#'
#' Examines untyped wikilinks and proposes typed relations based on
#' heuristics: folder co-location, heading context, and link frequency.
#' Suggestions are written to the index with \code{confirmed = 0}.
#'
#' @param vault_path Path to the markdown vault directory.
#' @return A data.frame of suggestions with columns: subject, relation_type,
#'   object, reason.
#' @export
suggest <- function(vault_path = file.path(tools::R_user_dir("pensar", "cache"),
        "index")) {
    vault_path <- normalizePath(vault_path, mustWork = TRUE)
    idx <- load_index(vault_path)

    md_files <- list.files(vault_path, pattern = "\\.md$", recursive = TRUE,
                           full.names = TRUE)
    md_files <- md_files[!grepl("^\\.pensar", basename(dirname(md_files)))]

    suggestions <- data.frame(subject = character(0L),
                              relation_type = character(0L),
                              object = character(0L), reason = character(0L),
                              stringsAsFactors = FALSE)

    terms <- idx$terms
    term_names <- terms$name

    for (fp in md_files) {
        name <- name_from_path(fp)
        wikilinks <- parse_wikilinks(fp)
        typed <- parse_typed_links(fp)
        # Untyped = wikilinks that aren't already typed
        untyped <- setdiff(wikilinks, typed$target)
        # Only suggest for targets that are known terms
        untyped <- untyped[untyped %in% term_names]

        if (length(untyped) == 0L) {
            next
        }

        # Heuristic: co-location suggests part_of
        file_dir <- dirname(fp)
        for (target in untyped) {
            target_row <- terms[terms$name == target,, drop = FALSE]
            if (nrow(target_row) == 0L || is.na(target_row$filepath[1L])) {
                next
            }
            target_path <- file.path(vault_path, target_row$filepath[1L])
            if (file.exists(target_path) && dirname(target_path) == file_dir) {
                suggestions <- rbind(suggestions,
                                     data.frame(subject = name, relation_type = "related_to",
                        object = target,
                        reason = "co-located in same folder",
                        stringsAsFactors = FALSE))
            }
        }

        # Heuristic: heading context
        lines <- readLines(fp, warn = FALSE)
        for (target in untyped) {
            link_lines <- grep(sprintf("\\[\\[%s\\]\\]",
                                       gsub("([.|()\\^{}+$*?\\\\\\[\\]])", "\\\\\\1", target)),
                               lines)
            for (ll in link_lines) {
                headings_above <- which(grepl("^##+ ", lines[seq_len(ll)]))
                if (length(headings_above) > 0L) {
                    heading <- tolower(lines[max(headings_above)])
                    if (grepl("method|technique|approach", heading)) {
                        suggestions <- rbind(suggestions,
                            data.frame(subject = name, relation_type = "uses",
                                       object = target,
                                       reason = sprintf("under heading: %s",
                                    trimws(lines[max(headings_above)])), stringsAsFactors = FALSE))
                    } else if (grepl("type|kind|categor", heading)) {
                        suggestions <- rbind(suggestions,
                            data.frame(subject = name, relation_type = "is_a",
                                       object = target,
                                       reason = sprintf("under heading: %s",
                                    trimws(lines[max(headings_above)])), stringsAsFactors = FALSE))
                    }
                }
            }
        }
    }

    # Deduplicate
    if (nrow(suggestions) > 0L) {
        key <- paste(suggestions$subject, suggestions$relation_type,
                     suggestions$object, sep = "|")
        suggestions <- suggestions[!duplicated(key),, drop = FALSE]

        # Write to index as unconfirmed
        for (i in seq_len(nrow(suggestions))) {
            subj <- suggestions$subject[i]
            rel <- suggestions$relation_type[i]
            obj <- suggestions$object[i]

            # Check for duplicate
            dup <- idx$relations$subject_id == subj &
            idx$relations$relation_type == rel &
            idx$relations$object_id == obj
            if (any(dup)) {
                next
            }

            idx$relations <- rbind(idx$relations,
                                   data.frame(subject_id = subj, relation_type = rel,
                    object_id = obj, confirmed = 0L,
                    source = "suggested", stringsAsFactors = FALSE))
        }
        save_index(idx, vault_path)
    }

    suggestions
}
