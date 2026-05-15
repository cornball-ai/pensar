#' @title Briefing ingestion (deprecated)
#' @description Generate a saber briefing and ingest it into the vault.

#' Generate and ingest a saber briefing
#'
#' @description
#' \strong{Deprecated.} Use \code{\link{ingest_repo}()} with the default
#' \code{enrich = "auto"} (which writes a \code{briefing.md} for R packages
#' under \code{raw/repos/<name>/}) instead. This function now delegates to
#' \code{ingest_repo()} after warning.
#'
#' @param project Project name. If \code{NULL}, inferred from the git
#'   root of the current working directory.
#' @param scan_dir Directory to search for the project. Defaults to
#'   \code{path.expand("~")}.
#' @param vault Path to the vault directory.
#' @return Invisibly, the path(s) written by \code{ingest_repo()}.
#' @examples
#' \dontrun{
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest_briefing(project = "pensar", vault = v)
#' }
#' @export
ingest_briefing <- function(project = NULL, scan_dir = path.expand("~"),
                            vault = default_vault()) {
    .Deprecated("ingest_repo",
                msg = paste0("ingest_briefing() is deprecated; ",
                             "use ingest_repo(path) instead."))

    if (is.null(project)) {
        project <- infer_project_from_git()
        if (is.null(project)) {
            stop("Could not infer project from git root. ",
                 "Pass project = \"name\" explicitly.")
        }
    }

    repo_path <- file.path(scan_dir, project)
    if (!file.exists(repo_path)) {
        stop("Project not found at ", repo_path, call. = FALSE)
    }

    ingest_repo(path = repo_path, name = project,
                artifacts = "briefing", vault = vault)
}

#' Infer project name from git root of current working directory
#' @noRd
infer_project_from_git <- function() {
    root <- suppressWarnings(tryCatch(
                                      trimws(system2("git",
                    c("-C", getwd(), "rev-parse", "--show-toplevel"),
                    stdout = TRUE, stderr = FALSE)[[1L]]),
                                      error = function(e) ""
        ))
    if (length(root) == 0L || !nzchar(root)) {
        return(NULL)
    }
    basename(root)
}

