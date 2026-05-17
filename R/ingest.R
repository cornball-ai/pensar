#' @title Source ingestion
#' @description Ingest content into a pensar vault.

#' Ingest content into the vault
#'
#' Writes content to \code{raw/{type}/}, generates a filename from source
#' and date, adds YAML frontmatter, updates \code{index.md}, and appends
#' to \code{log.md}.
#'
#' @param content Character string or character vector (lines) of content.
#' @param type Content type: \code{"articles"}, \code{"chats"}, or
#'   \code{"matrix"}. The legacy type \code{"briefings"} is still accepted
#'   but deprecated; for repo artifacts use \code{\link{ingest_repo}()}.
#' @param source Short identifier for the content source (e.g., URL,
#'   session ID, project name).
#' @param title Optional title. If \code{NULL}, derived from source.
#' @param tags Optional character vector of tags.
#' @param vault Path to the vault directory.
#' @param force In adopted vaults (\code{init_vault(adopt = TRUE)}),
#'   \code{ingest()} refuses to write by default. Pass \code{TRUE} to
#'   write into the adopted tree anyway. Native vaults ignore this
#'   parameter.
#' @return The path to the written file, invisibly.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("Hello, world.", type = "articles", source = "demo",
#'        vault = v)
#' status(v)
#' unlink(v, recursive = TRUE)
#' @export
ingest <- function(content,
                   type = c("articles", "chats", "briefings", "matrix"),
                   source, title = NULL, tags = NULL,
                   vault = default_vault(), force = FALSE) {
    type <- match.arg(type)
    vault <- normalizePath(vault, mustWork = TRUE)

    if (!file.exists(file.path(vault, "schema.md"))) {
        stop("Not a pensar vault: ", vault, ". Run init_vault() first.")
    }

    if (vault_is_adopted(vault) && !isTRUE(force)) {
        stop("Adopt mode: this vault is read-only. Pass force = TRUE ",
             "to write into the adopted vault tree.", call. = FALSE)
    }

    # raw/{type}/ may not exist in adopted vaults; create lazily.
    type_dir <- file.path(vault, "raw", type)
    if (!dir.exists(type_dir)) {
        dir.create(type_dir, recursive = TRUE, showWarnings = FALSE)
    }

    slug <- slugify(source)
    date_str <- format(Sys.Date(), "%Y-%m-%d")
    filename <- paste0(date_str, "-", slug, ".md")
    outpath <- unique_path(file.path(vault, "raw", type, filename))

    title <- title %||% source
    fm <- list(title = title, type = type, source = source, date = date_str)
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
    vault_commit(sprintf("Ingest %s: %s", type,
                         tools::file_path_sans_ext(basename(outpath))),
                 vault = vault)

    message("Ingested: ", basename(outpath))
    invisible(outpath)
}

