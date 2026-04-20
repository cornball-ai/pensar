#' @title Briefing ingestion
#' @description Generate a saber briefing and ingest it into the vault.

#' Generate and ingest a saber briefing
#'
#' Calls \code{saber::briefing(project)} to produce a project briefing
#' and ingests it into the vault as a \code{briefings} raw source.
#' Requires the \code{saber} package.
#'
#' @param project Project name. If \code{NULL}, inferred from the git
#'   root of the current working directory.
#' @param vault Path to the vault directory.
#' @return The path to the ingested briefing file, invisibly. Returns
#'   \code{NULL} invisibly if \code{saber} is not installed or the
#'   project cannot be inferred.
#' @export
ingest_briefing <- function(project = NULL, vault = default_vault()) {
    if (!requireNamespace("saber", quietly = TRUE)) {
        stop("Package 'saber' is required for ingest_briefing(). ",
             "Install it from https://github.com/cornball-ai/saber")
    }

    if (is.null(project)) {
        project <- infer_project_from_git()
        if (is.null(project)) {
            stop("Could not infer project from git root. ",
                 "Pass project = \"name\" explicitly.")
        }
    }

    content <- saber::briefing(project)
    ingest(content, type = "briefings", source = project,
           title = paste0("Briefing: ", project), vault = vault)
}

#' Infer project name from git root of current working directory
#' @noRd
infer_project_from_git <- function() {
    root <- suppressWarnings(tryCatch(
                                      trimws(system2("git", c("-C", getwd(), "rev-parse",
                        "--show-toplevel"),
                    stdout = TRUE, stderr = FALSE)[[1L]]),
                                      error = function(e) ""
        ))
    if (length(root) == 0L || !nzchar(root)) {
        return(NULL)
    }
    basename(root)
}

