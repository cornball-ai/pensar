#' @title Wiki page writing
#' @description Internal writer for validated pensar wiki pages.

#' Write a wiki page through package-owned safety gates
#'
#' @param slug Filename slug without extension.
#' @param frontmatter Named list written as YAML frontmatter.
#' @param body Markdown body.
#' @param vault Vault path.
#' @param overwrite Logical. If \code{FALSE}, existing files error.
#' @param force Logical. Allow writes into adopted vaults.
#' @return A data.frame with \code{slug}, \code{path}, and \code{action}.
#' @noRd
write_wiki_page <- function(slug, frontmatter, body, vault = default_vault(),
                            overwrite = TRUE, force = FALSE) {
    vault <- normalizePath(vault, mustWork = TRUE)
    if (vault_is_adopted(vault) && !isTRUE(force)) {
        stop("Adopt mode: this vault is read-only. Pass force = TRUE ",
             "to write into the adopted vault tree.", call. = FALSE)
    }
    if (!is.character(slug) || length(slug) != 1L || !nzchar(slug)) {
        stop("`slug` must be a single non-empty string.", call. = FALSE)
    }
    if (grepl("[:/\\\\]", slug) || grepl("\\.md$", slug, ignore.case = TRUE)) {
        stop("`slug` must not contain ':', path separators, or '.md'.",
             call. = FALSE)
    }
    if (!is.list(frontmatter) || is.null(names(frontmatter))) {
        stop("`frontmatter` must be a named list.", call. = FALSE)
    }
    required <- c("title", "type", "source")
    missing <- required[!required %in% names(frontmatter)]
    if (length(missing) > 0L) {
        stop("`frontmatter` missing required field(s): ",
             paste(missing, collapse = ", "), call. = FALSE)
    }
    if (!is.character(body) || length(body) != 1L) {
        stop("`body` must be a single character string.", call. = FALSE)
    }

    wiki_dir <- file.path(vault, "wiki")
    dir.create(wiki_dir, showWarnings = FALSE, recursive = TRUE)
    path <- file.path(wiki_dir, paste0(slug, ".md"))
    existed <- file.exists(path)
    if (existed && !isTRUE(overwrite)) {
        stop("Wiki page already exists: ", path, call. = FALSE)
    }

    fm_yaml <- sub("\n$", "", yaml::as.yaml(frontmatter))
    writeLines(c("---", fm_yaml, "---", "", body), path)
    data.frame(slug = slug,
               path = substring(path, nchar(vault) + 2L),
               action = if (existed) "updated" else "created",
               stringsAsFactors = FALSE)
}

