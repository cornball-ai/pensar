#' @title Vault index
#' @description Regenerate the vault index as a markdown catalog.

#' Update the vault index
#'
#' Scans all markdown files in the vault and regenerates \code{index.md}
#' as a categorized catalog with wikilinks and titles.
#'
#' @param vault Path to the vault directory.
#' @return The path to \code{index.md}, invisibly.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("Body.", type = "articles", source = "demo", vault = v)
#' update_index(v)
#' unlink(v, recursive = TRUE)
#' @export
update_index <- function(vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

    if (vault_is_adopted(vault)) {
        return(update_index_adopted(vault))
    }

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    control <- c("index.md", "log.md", "schema.md")
    all_md <- all_md[!basename(all_md) %in% control |
        dirname(all_md) != vault]

    categories <- list(
                       "Raw: Articles" = file.path(vault, "raw", "articles"),
                       "Raw: Chats" = file.path(vault, "raw", "chats"),
                       "Raw: Briefings" = file.path(vault, "raw", "briefings"),
                       "Raw: Matrix" = file.path(vault, "raw", "matrix"),
                       "Raw: Repos" = file.path(vault, "raw", "repos"),
                       "Wiki" = file.path(vault, "wiki")
    )

    lines <- c(
               "---",
               "title: Vault Index",
               sprintf("updated: %s", now_ts()),
               "---",
               "",
               "# Vault Index",
               ""
    )

    for (cat_name in names(categories)) {
        cat_dir <- normalizePath(categories[[cat_name]], mustWork = FALSE)
        cat_files <- all_md[startsWith(
                                       normalizePath(all_md, mustWork = FALSE), cat_dir
            )]
        lines <- c(lines,
                   sprintf("## %s (%d)", cat_name, length(cat_files)),
                   "")
        for (fp in sort(cat_files)) {
            page_name <- name_from_path(fp)
            fm <- parse_frontmatter(fp)
            title <- fm$title %||% page_name
            lines <- c(lines, sprintf("- [[%s]] -- %s", page_name, title))
        }
        lines <- c(lines, "")
    }

    writeLines(lines, file.path(vault, "index.md"))
    invisible(file.path(vault, "index.md"))
}

#' Registry-driven index for adopted vaults
#'
#' Groups pages by frontmatter \code{type} (or \code{category} when
#' \code{type} is absent). Falls into an "(untyped)" bucket otherwise.
#' Does not assume the native \code{raw/}/\code{wiki/} layout.
#' @noRd
update_index_adopted <- function(vault) {
    reg <- vault_registry(vault)
    page_rows <- reg[!reg$system_file,, drop = FALSE]

    lines <- c("---", "title: Vault Index", sprintf("updated: %s", now_ts()),
               "---", "", "# Vault Index", "",
               "(Adopted vault: pages grouped by ", "frontmatter `type`.)",
               "")

    if (nrow(page_rows) == 0L) {
        lines <- c(lines, "(no pages found)")
    } else {
        effective <- ifelse(is.na(page_rows$type) | page_rows$type == "",
                            page_rows$category, page_rows$type)
        type_col <- ifelse(is.na(effective) | effective == "",
                           "(untyped)", effective)
        # Disambiguate links: when node_id is unique, link as
        # `[[node_id]]`. When two or more pages share a node_id, link
        # as `[[path/without-ext]]` so the index doesn't emit two
        # identical wikilinks that both resolve to the same page.
        nid_counts <- table(page_rows$node_id)
        ambiguous <- names(nid_counts)[nid_counts > 1L]
        link_text <- ifelse(page_rows$node_id %in% ambiguous,
                            tools::file_path_sans_ext(page_rows$path),
                            page_rows$node_id)
        sorted_types <- sort(unique(type_col))
        for (t in sorted_types) {
            in_type_idx <- type_col == t
            in_type <- page_rows[in_type_idx, , drop = FALSE]
            in_type_links <- link_text[in_type_idx]
            lines <- c(lines, sprintf("## %s (%d)", t, nrow(in_type)),
                       "")
            for (i in seq_len(nrow(in_type))) {
                title <- if (!is.na(in_type$title[i]) &&
                             nzchar(in_type$title[i])) {
                    in_type$title[i]
                } else {
                    in_type$node_id[i]
                }
                lines <- c(lines,
                           sprintf("- [[%s]] -- %s",
                                   in_type_links[i], title))
            }
            lines <- c(lines, "")
        }
    }

    writeLines(lines, file.path(vault, "index.md"))
    invisible(file.path(vault, "index.md"))
}

