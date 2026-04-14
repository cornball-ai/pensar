#' @title Vault lint
#' @description Health check for a pensar vault.

#' Vault health check
#'
#' Scans the vault for orphan pages (no incoming wikilinks), broken
#' wikilinks (pointing to nonexistent pages), and tag clusters with no
#' wiki synthesis.
#'
#' @param vault Path to the vault directory.
#' @param min_cluster_size Minimum number of raw pages sharing a tag to
#'   suggest a wiki page. Default 3.
#' @return A list with class \code{pensar_lint}.
#' @export
lint <- function(vault = default_vault(), min_cluster_size = 3L) {
    vault <- normalizePath(vault, mustWork = TRUE)

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    control <- c("index.md", "log.md", "schema.md")
    all_md <- all_md[!basename(all_md) %in% control |
        dirname(all_md) != vault]

    page_names <- vapply(all_md, name_from_path, character(1L))
    is_wiki <- startsWith(normalizePath(all_md, mustWork = FALSE),
                          normalizePath(file.path(vault, "wiki"), mustWork = FALSE))

    # Build link graph
    all_links <- character(0L)
    link_source <- character(0L)
    link_file <- character(0L)
    for (fp in all_md) {
        links <- parse_wikilinks(fp)
        if (length(links) > 0L) {
            all_links <- c(all_links, links)
            link_source <- c(link_source, rep(name_from_path(fp),
                    length(links)))
            link_file <- c(link_file, rep(make_relative(fp, vault),
                    length(links)))
        }
    }

    # Orphan pages: pages with no incoming wikilinks
    referenced <- unique(all_links)
    orphan_names <- setdiff(page_names, referenced)

    # Broken wikilinks: targets that don't exist as pages
    broken <- !all_links %in% page_names
    broken_df <- data.frame(
                            source = link_source[broken],
                            link = all_links[broken],
                            file = link_file[broken],
                            stringsAsFactors = FALSE
    )
    broken_df <- unique(broken_df)

    # Tag clusters: tags shared by >= min_cluster_size raw pages,
    # with no wiki page tagged the same
    raw_tags <- list()
    wiki_tags <- character(0L)
    for (i in seq_along(all_md)) {
        fm <- parse_frontmatter(all_md[i])
        tags <- fm$tags
        if (is.null(tags) || length(tags) == 0L) {
            next
        }
        if (is_wiki[i]) {
            wiki_tags <- c(wiki_tags, tags)
        } else {
            raw_tags[[page_names[i]]] <- tags
        }
    }
    tag_counts <- table(unlist(raw_tags))
    wiki_tag_set <- unique(wiki_tags)
    cluster_df <- data.frame(
                             tag = names(tag_counts),
                             raw_pages = as.integer(tag_counts),
                             has_wiki = names(tag_counts) %in% wiki_tag_set,
                             stringsAsFactors = FALSE
    )
    cluster_df <- cluster_df[cluster_df$raw_pages >= min_cluster_size &
        !cluster_df$has_wiki,, drop = FALSE]
    cluster_df <- cluster_df[order(-cluster_df$raw_pages),, drop = FALSE]
    rownames(cluster_df) <- NULL

    result <- list(
                   orphans = sort(orphan_names),
                   broken_links = broken_df,
                   suggested_clusters = cluster_df[, c("tag", "raw_pages"),
                   drop = FALSE],
                   vault = vault
    )
    class(result) <- "pensar_lint"
    result
}

#' @export
print.pensar_lint <- function(x, ...) {
    cat("Vault lint:", x$vault, "\n\n")

    cat(sprintf("Orphan pages (%d):\n", length(x$orphans)))
    if (length(x$orphans) > 0L) {
        head_n <- min(10L, length(x$orphans))
        for (o in x$orphans[seq_len(head_n)]) {
            cat("  -", o, "\n")
        }
        if (length(x$orphans) > head_n) {
            cat(sprintf("  ... and %d more\n", length(x$orphans) - head_n))
        }
    }

    cat(sprintf("\nBroken wikilinks (%d):\n", nrow(x$broken_links)))
    if (nrow(x$broken_links) > 0L) {
        head_n <- min(10L, nrow(x$broken_links))
        for (i in seq_len(head_n)) {
            cat(sprintf("  - [[%s]] in %s\n",
                        x$broken_links$link[i],
                        x$broken_links$file[i]))
        }
        if (nrow(x$broken_links) > head_n) {
            cat(sprintf("  ... and %d more\n", nrow(x$broken_links) - head_n))
        }
    }

    cat(sprintf("\nTag clusters without wiki pages (%d):\n",
                nrow(x$suggested_clusters)))
    if (nrow(x$suggested_clusters) > 0L) {
        for (i in seq_len(nrow(x$suggested_clusters))) {
            cat(sprintf("  - %s (%d raw pages)\n",
                        x$suggested_clusters$tag[i],
                        x$suggested_clusters$raw_pages[i]))
        }
    }

    invisible(x)
}

