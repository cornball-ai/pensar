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
    if (!is.character(slug) || length(slug) != 1L || is.na(slug) ||
        !nzchar(trimws(slug))) {
        stop("`slug` must be a single non-empty string.", call. = FALSE)
    }
    slug <- trimws(slug)
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

    if (existed) {
        frontmatter <- .merge_wiki_frontmatter(path, frontmatter)
    }
    fm_yaml <- sub("\n$", "", yaml::as.yaml(frontmatter))
    writeLines(c("---", fm_yaml, "---", "", body), path)
    data.frame(slug = slug,
               path = substring(path, nchar(vault) + 2L),
               action = if (existed) "updated" else "created",
               stringsAsFactors = FALSE)
}

#' Merge new frontmatter over existing without losing untouched fields
#'
#' Reads the existing page's frontmatter and merges \code{new} over it.
#' Caller-supplied fields replace existing values. \code{tags} is the
#' one merge exception: existing tags + new tags, set-union, original
#' order preserved. Fields present in the existing frontmatter but not
#' in \code{new} (\code{id}, \code{aliases}, custom fields like
#' \code{status}, \code{related}, etc.) survive untouched.
#'
#' @noRd
.merge_wiki_frontmatter <- function(path, new) {
    existing <- tryCatch(parse_frontmatter(path), error = function(e) list())
    if (!is.list(existing)) {
        existing <- list()
    }
    merged <- existing
    for (nm in names(new)) {
        if (identical(nm, "tags") && !is.null(existing$tags)) {
            old_tags <- as.character(existing$tags)
            new_tags <- as.character(new$tags)
            merged$tags <- unique(c(old_tags, new_tags))
        } else {
            merged[[nm]] <- new[[nm]]
        }
    }
    merged
}
