#' @title Vault index
#' @description Regenerate the vault index as a markdown catalog.

#' Update the vault index
#'
#' Scans all markdown files in the vault and regenerates \code{index.md}
#' as a categorized catalog with wikilinks and titles.
#'
#' @param vault Path to the vault directory.
#' @return The path to \code{index.md}, invisibly.
#' @export
update_index <- function(vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    control <- c("index.md", "log.md", "schema.md")
    all_md <- all_md[!basename(all_md) %in% control |
                     dirname(all_md) != vault]

    categories <- list(
        "Raw: Articles"  = file.path(vault, "raw", "articles"),
        "Raw: Chats"     = file.path(vault, "raw", "chats"),
        "Raw: Briefings" = file.path(vault, "raw", "briefings"),
        "Raw: Matrix"    = file.path(vault, "raw", "matrix"),
        "Wiki"           = file.path(vault, "wiki")
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
            lines <- c(lines,
                       sprintf("- [[%s]] -- %s", page_name, title))
        }
        lines <- c(lines, "")
    }

    writeLines(lines, file.path(vault, "index.md"))
    invisible(file.path(vault, "index.md"))
}
