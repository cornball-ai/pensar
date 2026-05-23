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
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("Refers to [[absent]].", type = "articles", source = "demo",
#'        vault = v)
#' lint(v)
#' unlink(v, recursive = TRUE)
#' @export
lint <- function(vault = default_vault(), min_cluster_size = 3L) {
    vault <- normalizePath(vault, mustWork = TRUE)

    # Registry-driven so existence checks, orphan calculations, and
    # link extraction all agree with find_page() / outlinks() /
    # backlinks() on path-style links and aliases.
    reg <- vault_registry(vault)
    page_rows <- reg[!reg$system_file,, drop = FALSE]
    all_md <- file.path(vault, page_rows$path)
    page_names <- page_rows$node_id
    page_paths <- page_rows$path

    is_wiki <- startsWith(normalizePath(all_md, mustWork = FALSE),
                          normalizePath(file.path(vault, "wiki"), mustWork = FALSE))

    # Build link graph: resolve every outbound link to its target path.
    # Broken links are the ones that don't resolve at all.
    referenced_paths <- character(0L)
    broken_source <- character(0L)
    broken_link <- character(0L)
    broken_file <- character(0L)
    wiki_idx <- which(is_wiki)
    for (i in wiki_idx) {
        links <- page_rows$links_out[[i]]
        if (length(links) == 0L) {
            next
        }
        for (link in links) {
            resolved <- resolve_target_path(link, vault)
            if (is.na(resolved)) {
                broken_source <- c(broken_source, page_rows$node_id[i])
                broken_link <- c(broken_link, link)
                broken_file <- c(broken_file, page_rows$path[i])
            } else {
                referenced_paths <- c(referenced_paths, resolved)
            }
        }
    }

    # Orphan pages: paths that nothing points to.
    referenced_paths <- unique(referenced_paths)
    wiki_paths <- page_paths[is_wiki]
    wiki_names <- page_names[is_wiki]
    orphan_idx <- !(wiki_paths %in% referenced_paths)
    orphan_names <- sort(wiki_names[orphan_idx])

    broken_df <- data.frame(source = broken_source, link = broken_link,
                            file = broken_file, stringsAsFactors = FALSE)
    broken_df <- unique(broken_df)
    rownames(broken_df) <- NULL

    # Tag clusters: tags shared by >= min_cluster_size raw pages,
    # with no wiki page tagged the same. Data is read from the registry
    # so we don't rescan files.
    raw_tags <- list()
    wiki_tags <- character(0L)
    for (i in seq_len(nrow(page_rows))) {
        tags <- page_rows$tags[[i]]
        if (length(tags) == 0L) {
            next
        }
        if (is_wiki[i]) {
            wiki_tags <- c(wiki_tags, tags)
        } else {
            # Key by relative path so two raw pages with the same
            # basename in different folders don't overwrite each other
            # and undercount tag clusters.
            raw_tags[[page_paths[i]]] <- tags
        }
    }
    wiki_tag_set <- unique(wiki_tags)
    all_tag_values <- unlist(raw_tags)
    if (length(all_tag_values) == 0L) {
        cluster_df <- data.frame(
                                 tag = character(0L),
                                 raw_pages = integer(0L),
                                 has_wiki = logical(0L),
                                 stringsAsFactors = FALSE
        )
    } else {
        tag_counts <- table(all_tag_values)
        cluster_df <- data.frame(
                                 tag = names(tag_counts),
                                 raw_pages = as.integer(tag_counts),
                                 has_wiki = names(tag_counts) %in%
                                 wiki_tag_set,
                                 stringsAsFactors = FALSE
        )
    }
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
            cat(sprintf("  - [[%s]] in %s\n", x$broken_links$link[i],
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

