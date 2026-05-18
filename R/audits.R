#' @title Vault audits
#' @description Read-only audits that surface duplicate-looking pages
#' and tag-vocabulary drift. Both write proposals to
#' \code{<vault>/_proposals/} for human review. Pensar never
#' auto-merges or auto-renames.

#' Find candidate duplicate pages
#'
#' Compares every non-system page pair by Jaro-Winkler title similarity
#' and tag-set Jaccard overlap. Pairs whose combined score exceeds
#' \code{threshold} are written to \code{_proposals/dedup.md} for human
#' review.
#'
#' The combined score weights title similarity at 0.6 and tag overlap
#' at 0.4 (\code{0.6 * jw_sim + 0.4 * tag_jaccard}). Title similarity
#' is computed on lowercased trimmed titles; pages with no title fall
#' back to \code{node_id}.
#'
#' Pensar never auto-merges. The proposals file is for human review.
#'
#' @param vault Vault path.
#' @param threshold Minimum combined score, in [0, 1]. Default 0.7.
#' @return A data.frame of proposed pairs (invisibly):
#'   \code{page_a}, \code{page_b}, \code{title_similarity},
#'   \code{tag_overlap}, \code{combined_score}. Sorted by combined
#'   score descending.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("A.", type = "articles", source = "alpha-foo", vault = v)
#' ingest("B.", type = "articles", source = "alpha-foos", vault = v)
#' dedup(v)
#' unlink(v, recursive = TRUE)
#' @export
dedup <- function(vault = default_vault(), threshold = 0.7) {
    if (!requireNamespace("stringdist", quietly = TRUE)) {
        stop("dedup() requires the 'stringdist' package.",
             call. = FALSE)
    }
    vault <- normalizePath(vault, mustWork = TRUE)

    reg <- vault_registry(vault)
    pages <- reg[!reg$system_file, , drop = FALSE]
    n <- nrow(pages)
    if (n < 2L) {
        proposals <- empty_dedup_result()
        write_dedup_proposals(vault, proposals)
        return(invisible(proposals))
    }

    titles <- ifelse(!is.na(pages$title) & nzchar(pages$title),
                     tolower(trimws(pages$title)),
                     tolower(pages$node_id))

    page_a <- character(0L)
    page_b <- character(0L)
    title_sim <- numeric(0L)
    tag_overlap <- integer(0L)
    combined <- numeric(0L)

    for (i in seq_len(n - 1L)) {
        for (j in seq.int(i + 1L, n)) {
            jw_dist <- stringdist::stringdist(titles[i], titles[j],
                                              method = "jw")
            sim <- 1 - jw_dist
            jacc <- tag_jaccard(pages$tags[[i]], pages$tags[[j]])
            score <- 0.6 * sim + 0.4 * jacc
            if (score >= threshold) {
                page_a <- c(page_a, pages$path[i])
                page_b <- c(page_b, pages$path[j])
                title_sim <- c(title_sim, sim)
                tag_overlap <- c(
                    tag_overlap,
                    length(intersect(pages$tags[[i]],
                                     pages$tags[[j]])))
                combined <- c(combined, score)
            }
        }
    }

    proposals <- data.frame(page_a = page_a, page_b = page_b,
                            title_similarity = title_sim,
                            tag_overlap = tag_overlap,
                            combined_score = combined,
                            stringsAsFactors = FALSE)
    if (nrow(proposals) > 0L) {
        proposals <- proposals[order(-proposals$combined_score), ,
                               drop = FALSE]
        rownames(proposals) <- NULL
    }
    write_dedup_proposals(vault, proposals)
    invisible(proposals)
}

#' @noRd
empty_dedup_result <- function() {
    data.frame(page_a = character(0L), page_b = character(0L),
               title_similarity = numeric(0L),
               tag_overlap = integer(0L),
               combined_score = numeric(0L),
               stringsAsFactors = FALSE)
}

#' Jaccard overlap of two tag sets
#' @noRd
tag_jaccard <- function(a, b) {
    if (length(a) == 0L && length(b) == 0L) {
        return(0)
    }
    inter <- length(intersect(a, b))
    uni <- length(union(a, b))
    if (uni == 0L) {
        return(0)
    }
    inter / uni
}

#' Write the dedup proposals report
#' @noRd
write_dedup_proposals <- function(vault, proposals) {
    out_dir <- file.path(vault, "_proposals")
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    out_path <- file.path(out_dir, "dedup.md")

    if (nrow(proposals) == 0L) {
        writeLines(c("---",
                     "title: Dedup proposals",
                     sprintf("updated: %s", now_ts()),
                     "---",
                     "",
                     "# Dedup proposals",
                     "",
                     "No candidate duplicates above threshold."),
                   out_path)
        return(invisible(out_path))
    }

    lines <- c("---",
               "title: Dedup proposals",
               sprintf("updated: %s", now_ts()),
               "---",
               "",
               "# Dedup proposals",
               "",
               sprintf("%d candidate pair(s) above threshold.",
                       nrow(proposals)),
               "")
    for (i in seq_len(nrow(proposals))) {
        lines <- c(lines,
                   sprintf("## Pair %d  (score: %.3f)", i,
                           proposals$combined_score[i]),
                   sprintf("- A: `%s`", proposals$page_a[i]),
                   sprintf("- B: `%s`", proposals$page_b[i]),
                   sprintf("- title similarity (Jaro-Winkler): %.3f",
                           proposals$title_similarity[i]),
                   sprintf("- tag overlap (intersection size): %d",
                           proposals$tag_overlap[i]),
                   "")
    }

    writeLines(lines, out_path)
    invisible(out_path)
}

#' Audit tag usage against a controlled vocabulary
#'
#' Reads every tag from the registry, optionally compares against a
#' taxonomy file (\code{_meta/taxonomy.md}, a markdown bullet list of
#' allowed tags), and writes a proposals report to
#' \code{_proposals/tags.md}. Unknown tags get near-miss suggestions
#' via Jaro-Winkler distance against the taxonomy.
#'
#' Pensar never auto-renames. The proposals file is for human review.
#'
#' @param vault Vault path.
#' @param taxonomy Optional path to a taxonomy file. Defaults to
#'   \code{<vault>/_meta/taxonomy.md} when present, otherwise no
#'   taxonomy is loaded and the report lists all used tags by
#'   frequency.
#' @param near_miss_threshold Maximum Jaro-Winkler distance for an
#'   unknown tag to be suggested as a typo of a taxonomy entry.
#'   Default 0.15.
#' @return A list with components \code{used} (data.frame of tag /
#'   count), \code{unknown} (data.frame of unknown tags with optional
#'   suggestions), and \code{unused_taxonomy} (character vector of
#'   taxonomy entries with zero usage). Invisible.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("hi", type = "articles", source = "demo",
#'        tags = c("foo", "bar"), vault = v)
#' tags(v)
#' unlink(v, recursive = TRUE)
#' @export
tags <- function(vault = default_vault(), taxonomy = NULL,
                 near_miss_threshold = 0.15) {
    vault <- normalizePath(vault, mustWork = TRUE)

    if (is.null(taxonomy)) {
        default_taxonomy <- file.path(vault, "_meta", "taxonomy.md")
        if (file.exists(default_taxonomy)) {
            taxonomy <- default_taxonomy
        }
    }
    allowed <- if (is.null(taxonomy) || !file.exists(taxonomy)) {
        character(0L)
    } else {
        read_taxonomy(taxonomy)
    }

    reg <- vault_registry(vault)
    pages <- reg[!reg$system_file, , drop = FALSE]

    all_tags <- unlist(pages$tags, use.names = FALSE)
    if (is.null(all_tags)) {
        all_tags <- character(0L)
    }

    if (length(all_tags) == 0L) {
        used <- data.frame(tag = character(0L), count = integer(0L),
                           stringsAsFactors = FALSE)
    } else {
        counts <- sort(table(all_tags), decreasing = TRUE)
        used <- data.frame(tag = names(counts),
                           count = as.integer(counts),
                           stringsAsFactors = FALSE)
    }

    unknown <- if (length(allowed) == 0L || nrow(used) == 0L) {
        data.frame(tag = character(0L), count = integer(0L),
                   suggestion = character(0L),
                   stringsAsFactors = FALSE)
    } else {
        unk_mask <- !(used$tag %in% allowed)
        if (!any(unk_mask)) {
            data.frame(tag = character(0L), count = integer(0L),
                       suggestion = character(0L),
                       stringsAsFactors = FALSE)
        } else {
            unk_tags <- used$tag[unk_mask]
            suggestion <- vapply(unk_tags,
                                 function(t) {
                                     near_miss(t, allowed,
                                               near_miss_threshold)
                                 },
                                 character(1L))
            data.frame(tag = unk_tags,
                       count = used$count[unk_mask],
                       suggestion = suggestion,
                       stringsAsFactors = FALSE)
        }
    }

    unused_taxonomy <- if (length(allowed) == 0L) {
        character(0L)
    } else {
        sort(setdiff(allowed, used$tag))
    }

    write_tags_proposals(vault, used, unknown, unused_taxonomy,
                         taxonomy)
    invisible(list(used = used, unknown = unknown,
                   unused_taxonomy = unused_taxonomy))
}

#' Read a controlled-vocabulary taxonomy from a markdown bullet list
#'
#' Lines matching \code{- <tag>} (with optional leading whitespace) are
#' taken as taxonomy entries. Other lines are ignored, so the file can
#' carry headings and prose around the bullet list.
#' @noRd
read_taxonomy <- function(taxonomy_path) {
    lines <- readLines(taxonomy_path, warn = FALSE)
    # POSIX character classes: [:space:] inside the class is portable
    # across R's default regex engine. `\\s` is not.
    pat <- "^[[:space:]]*[-*][[:space:]]+`?([^`[:space:]]+)`?[[:space:]]*$"
    m <- regmatches(lines, regexec(pat, lines))
    tags <- vapply(m, function(x) if (length(x) >= 2L) x[[2L]]
                   else NA_character_, character(1L))
    tags <- tags[!is.na(tags) & nzchar(tags)]
    unique(tags)
}

#' Best near-miss suggestion for an unknown tag
#'
#' Returns the closest taxonomy entry by Jaro-Winkler distance, or
#' \code{NA_character_} when no entry is within \code{threshold}.
#' @noRd
near_miss <- function(tag, allowed, threshold) {
    if (length(allowed) == 0L) {
        return(NA_character_)
    }
    if (!requireNamespace("stringdist", quietly = TRUE)) {
        return(NA_character_)
    }
    dists <- stringdist::stringdist(tag, allowed, method = "jw")
    idx <- which.min(dists)
    if (length(idx) == 0L || dists[idx] > threshold) {
        return(NA_character_)
    }
    allowed[idx]
}

#' Write the tags proposals report
#' @noRd
write_tags_proposals <- function(vault, used, unknown,
                                 unused_taxonomy, taxonomy_path) {
    out_dir <- file.path(vault, "_proposals")
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    out_path <- file.path(out_dir, "tags.md")

    lines <- c("---",
               "title: Tag audit",
               sprintf("updated: %s", now_ts()),
               "---",
               "",
               "# Tag audit",
               "")

    if (is.null(taxonomy_path) || !file.exists(taxonomy_path)) {
        lines <- c(lines,
                   "No taxonomy file found at `_meta/taxonomy.md`.",
                   "Listing all used tags by frequency:", "")
    } else {
        lines <- c(lines, sprintf("Taxonomy: `%s`", taxonomy_path), "")
    }

    if (nrow(used) == 0L) {
        lines <- c(lines, "_(no tags in vault)_")
    } else {
        lines <- c(lines, "## All used tags", "")
        for (i in seq_len(nrow(used))) {
            lines <- c(lines, sprintf("- `%s` (%d)",
                                      used$tag[i], used$count[i]))
        }
        lines <- c(lines, "")
    }

    if (nrow(unknown) > 0L) {
        lines <- c(lines, "## Unknown tags (not in taxonomy)", "")
        for (i in seq_len(nrow(unknown))) {
            suggestion <- if (is.na(unknown$suggestion[i])) {
                ""
            } else {
                sprintf(" -- did you mean `%s`?",
                        unknown$suggestion[i])
            }
            lines <- c(lines, sprintf("- `%s` (%d)%s",
                                      unknown$tag[i], unknown$count[i],
                                      suggestion))
        }
        lines <- c(lines, "")
    }

    if (length(unused_taxonomy) > 0L) {
        lines <- c(lines, "## Unused taxonomy entries", "")
        for (t in unused_taxonomy) {
            lines <- c(lines, sprintf("- `%s`", t))
        }
        lines <- c(lines, "")
    }

    writeLines(lines, out_path)
    invisible(out_path)
}
