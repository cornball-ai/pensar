#' @title Build or update the ontology index
#' @description Parse markdown files from a vault and populate the index.

#' Build or update the ontology index from a markdown vault
#'
#' Parses all markdown files in the vault, extracts frontmatter and typed
#' links, and writes them to the index. Performs incremental updates
#' based on file hashes.
#'
#' @param vault_path Path to the markdown vault directory.
#' @return The index directory path (invisibly).
#' @export
index_vault <- function(vault_path) {
    vault_path <- normalizePath(vault_path, mustWork = TRUE)
    idx <- load_index(vault_path, create = TRUE)

    md_files <- list.files(vault_path, pattern = "\\.md$", recursive = TRUE,
                           full.names = TRUE)
    md_files <- md_files[!grepl("^\\.pensar", basename(dirname(md_files)))]

    rel_files <- make_relative(md_files, vault_path)

    for (i in seq_along(md_files)) {
        fp <- md_files[i]
        rel <- rel_files[i]
        h <- file_hash(fp)
        prev <- idx$files$hash[idx$files$filepath == rel]
        if (length(prev) == 1L && prev == h) {
            next
        }
        idx <- index_one_file(idx, fp, rel, h)
    }

    # Remove entries for deleted files
    gone <- setdiff(idx$files$filepath, rel_files)
    if (length(gone) > 0L) {
        idx$terms <- idx$terms[!idx$terms$filepath %in% gone,, drop = FALSE]
        idx$files <- idx$files[!idx$files$filepath %in% gone,, drop = FALSE]
    }

    idx <- ensure_link_targets(idx)

    save_index(idx, vault_path)
    invisible(index_dir(vault_path))
}

#' Index a single markdown file
#' @noRd
index_one_file <- function(idx, filepath, rel_path, hash) {
    fm <- parse_frontmatter(filepath)
    links <- parse_typed_links(filepath)
    name <- name_from_path(filepath)

    is_term <- !is.null(fm[["id"]]) ||
    identical(fm[["type"]], "term") ||
    nrow(links) > 0L

    if (is_term) {
        if (!is.null(fm[["id"]])) {
            term_id <- fm[["id"]]
        } else {
            term_id <- name
        }
        aliases <- if (!is.null(fm[["aliases"]])) {
            paste(fm[["aliases"]], collapse = "|")
        } else {
            ""
        }
        promoted <- as.integer(!is.null(fm[["id"]]))

        new_term <- data.frame(id = term_id, name = name,
                               filepath = rel_path, aliases = aliases,
                               promoted = promoted, updated_at = now_ts(),
                               stringsAsFactors = FALSE)

        # Upsert: remove old, add new
        idx$terms <- idx$terms[idx$terms$id != term_id,, drop = FALSE]
        idx$terms <- rbind(idx$terms, new_term)

        # Remove old inline relations from this subject, re-insert
        idx$relations <- idx$relations[!(idx$relations$subject_id == term_id &
                idx$relations$source == "inline"),
            , drop = FALSE]

        if (nrow(links) > 0L) {
            new_rels <- data.frame(subject_id = rep(term_id, nrow(links)),
                                   relation_type = links$relation_type,
                                   object_id = links$target, confirmed = 1L,
                                   source = "inline", stringsAsFactors = FALSE)
            idx$relations <- rbind(idx$relations, new_rels)
        }
    }

    # Update file tracking
    idx$files <- idx$files[idx$files$filepath != rel_path,, drop = FALSE]
    idx$files <- rbind(idx$files,
                       data.frame(filepath = rel_path, hash = hash, parsed_at = now_ts(),
                                  stringsAsFactors = FALSE))

    idx
}

#' Resolve relation object_ids to actual term IDs where possible,
#' then ensure remaining targets exist as stub terms.
#' @noRd
ensure_link_targets <- function(idx) {
    # Resolve object_ids that match a term name to the term's actual id
    unresolved <- !idx$relations$object_id %in% idx$terms$id
    if (any(unresolved)) {
        name_lookup <- idx$terms[, c("id", "name"), drop = FALSE]
        for (i in which(unresolved)) {
            obj <- idx$relations$object_id[i]
            match_row <- name_lookup[name_lookup$name == obj,, drop = FALSE]
            if (nrow(match_row) > 0L) {
                idx$relations$object_id[i] <- match_row$id[1]
            }
        }
    }

    # Create stub terms for targets that still don't exist
    still_missing <- setdiff(idx$relations$object_id, idx$terms$id)
    if (length(still_missing) > 0L) {
        stubs <- data.frame(id = still_missing, name = still_missing,
                            filepath = NA_character_, aliases = "",
                            promoted = 0L, updated_at = now_ts(),
                            stringsAsFactors = FALSE)
        idx$terms <- rbind(idx$terms, stubs)
    }

    idx
}

#' Make paths relative to a base directory
#' @noRd
make_relative <- function(paths, base) {
    base <- paste0(normalizePath(base, mustWork = TRUE), .Platform$file.sep)
    sub(base, "", paths, fixed = TRUE)
}
