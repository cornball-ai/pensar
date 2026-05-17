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
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' # Returns FALSE invisibly: no .git in this temp vault.
#' vault_commit("noop", vault = v, push = FALSE)
#' unlink(v, recursive = TRUE)
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

#' Detect whether a directory is safe for pensar to scaffold and commit into
#'
#' Called by \code{init_vault()} only after the early-return on an
#' existing \code{schema.md}. By that point we know there is no pensar
#' vault here; the question is whether the directory is empty enough
#' (or contains only benign development scaffolding) that pensar can
#' safely write its layout in.
#'
#' "Pensar-owned" here means: nothing in the way. Empty directories
#' qualify; directories containing only \code{.gitignore},
#' \code{README.md}, \code{.Rproj} / \code{.Rproj.user}, or a \code{.git}
#' dir whose history contains only those same benign files, qualify.
#'
#' Top-level \code{raw/} or \code{wiki/} without \code{schema.md} does
#' \strong{not} count as pensar-owned: those could be a foreign project's
#' directories, and a wrongly-positive check would have pensar
#' overwriting non-pensar content.
#' @noRd
vault_is_pensar_owned <- function(path) {
    if (!dir.exists(path)) {
        return(TRUE)
    }

    benign_top <- c(".gitignore", "README.md", ".git", ".Rproj.user")
    rproj_pattern <- "\\.Rproj$"

    top <- list.files(path, all.files = TRUE, no.. = TRUE)
    is_benign <- top %in% benign_top | grepl(rproj_pattern, top)
    if (any(!is_benign)) {
        return(FALSE)
    }

    if (!dir.exists(file.path(path, ".git"))) {
        return(TRUE)
    }
    if (nchar(Sys.which("git")) == 0L) {
        return(TRUE)
    }
    log_out <- suppressWarnings(system2("git",
                                        c("-C", path, "log", "--oneline", "-1"),
                                        stdout = TRUE, stderr = FALSE))
    if (length(log_out) == 0L) {
        return(TRUE)
    }
    tracked <- suppressWarnings(system2("git",
                                        c("-C", path, "ls-tree", "-r", "HEAD",
                                          "--name-only"),
                                        stdout = TRUE, stderr = FALSE))
    if (length(tracked) == 0L) {
        return(TRUE)
    }
    tracked_pattern <- "^\\.gitignore$|^README\\.md$|\\.Rproj$"
    foreign_tracked <- !grepl(tracked_pattern, tracked)
    !any(foreign_tracked)
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
                 system2("git", c("-C", vault, "push", r), stdout = FALSE,
                         stderr = FALSE),
                 error = function(e) NULL
        )
    }
    invisible(NULL)
}

