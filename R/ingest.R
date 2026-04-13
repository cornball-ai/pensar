#' @title Source ingestion
#' @description Ingest content into a pensar vault.

#' Ingest content into the vault
#'
#' Writes content to \code{raw/{type}/}, generates a filename from source
#' and date, adds YAML frontmatter, updates \code{index.md}, and appends
#' to \code{log.md}.
#'
#' @param content Character string or character vector (lines) of content.
#' @param type Content type: \code{"articles"}, \code{"chats"},
#'   \code{"briefings"}, or \code{"matrix"}.
#' @param source Short identifier for the content source (e.g., URL,
#'   session ID, project name).
#' @param title Optional title. If \code{NULL}, derived from source.
#' @param tags Optional character vector of tags.
#' @param vault Path to the vault directory.
#' @return The path to the written file, invisibly.
#' @export
ingest <- function(content,
                   type = c("articles", "chats", "briefings", "matrix"),
                   source, title = NULL, tags = NULL,
                   vault = default_vault()) {
    type <- match.arg(type)
    vault <- normalizePath(vault, mustWork = TRUE)

    if (!file.exists(file.path(vault, "schema.md"))) {
        stop("Not a pensar vault: ", vault, ". Run init_vault() first.")
    }

    slug <- slugify(source)
    date_str <- format(Sys.Date(), "%Y-%m-%d")
    filename <- paste0(date_str, "-", slug, ".md")
    outpath <- unique_path(file.path(vault, "raw", type, filename))

    title <- title %||% source
    fm <- list(title = title, type = type, source = source,
               date = date_str)
    if (!is.null(tags)) {
        fm$tags <- tags
    }

    fm_yaml <- yaml::as.yaml(fm)
    lines <- c("---", sub("\n$", "", fm_yaml), "---", "",
               if (is.character(content)) content else as.character(content))
    writeLines(lines, outpath)

    update_index(vault)
    log_entry(sprintf("Ingested %s: %s", type, basename(outpath)),
              operation = "ingest", vault = vault)

    message("Ingested: ", basename(outpath))
    invisible(outpath)
}
