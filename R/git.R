#' @title Vault git operations
#' @description Auto-commit and push for pensar vaults that are git repos.

#' Commit vault changes to git
#'
#' No-op if the vault is not a git repo or if there are no changes.
#' Stages all changes (respecting \code{.gitignore}), commits with the
#' given message, and optionally pushes to remotes.
#'
#' Honors the \code{PENSAR_AUTO_PUSH} environment variable: if set to
#' \code{"0"} or \code{"false"} (case-insensitive), skips the push
#' step. Otherwise, pushes to every configured remote.
#'
#' @param message Commit message.
#' @param vault Path to the vault directory.
#' @param push If \code{NULL} (default), honors \code{PENSAR_AUTO_PUSH}.
#'   Pass \code{TRUE} or \code{FALSE} to override.
#' @return \code{TRUE} if a commit was made, \code{FALSE} otherwise
#'   (invisibly).
#' @export
vault_commit <- function(message, vault = default_vault(), push = NULL) {
    vault <- normalizePath(vault, mustWork = TRUE)
    if (!dir.exists(file.path(vault, ".git"))) {
        return(invisible(FALSE))
    }
    if (nchar(Sys.which("git")) == 0L) {
        return(invisible(FALSE))
    }

    # Stage all changes
    system2("git", c("-C", vault, "add", "-A"), stdout = FALSE, stderr = FALSE)

    # Check if anything to commit
    status <- system2("git", c("-C", vault, "status", "--porcelain"),
                      stdout = TRUE, stderr = FALSE)
    if (length(status) == 0L) {
        return(invisible(FALSE))
    }

    commit_status <- system2("git",
                             c("-C", vault, "commit", "-m", shQuote(message)),
                             stdout = FALSE, stderr = FALSE)
    if (commit_status != 0L) {
        return(invisible(FALSE))
    }

    if (should_push(push)) {
        push_all_remotes(vault)
    }
    invisible(TRUE)
}

#' @noRd
should_push <- function(push) {
    if (!is.null(push)) {
        return(isTRUE(push))
    }
    env <- tolower(Sys.getenv("PENSAR_AUTO_PUSH", unset = "true"))
    !(env %in% c("0", "false", "no", "off", ""))
}

#' Push to all configured remotes (best-effort, errors swallowed)
#' @noRd
push_all_remotes <- function(vault) {
    remotes <- tryCatch(
                        system2("git", c("-C", vault, "remote"), stdout = TRUE, stderr = FALSE),
                        error = function(e) character(0L)
    )
    if (length(remotes) == 0L) {
        return(invisible(NULL))
    }
    for (r in remotes) {
        tryCatch(
                 system2("git", c("-C", vault, "push", r),
                         stdout = FALSE, stderr = FALSE),
                 error = function(e) NULL
        )
    }
    invisible(NULL)
}

