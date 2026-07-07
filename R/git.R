#' @title Vault git operations
#' @description Auto-commit and push for pensar vaults that are git repos.

#' Commit vault changes to git
#'
#' No-op if the vault is not inside a git repo or if there are no
#' changes. Stages all changes under the vault (respecting
#' \code{.gitignore}), commits with the given message, and optionally
#' pushes to remotes.
#'
#' The vault may be its own repo, or \strong{nested} inside a larger
#' repo (e.g. a project repo with the vault at \code{vault/}). Nested
#' vaults are handled conservatively: staging and the commit are
#' scoped to the vault subtree, so unrelated changes elsewhere in the
#' enclosing repo -- dirty or even already staged -- are never swept
#' into a pensar commit. Nested vaults also \strong{never auto-push}:
#' \code{PENSAR_AUTO_PUSH} is ignored, since pushing the enclosing
#' repo could carry unrelated unpushed commits. An explicit
#' \code{push = TRUE} pushes the enclosing repo's branch with a single
#' plain push (no rebase-retry automation).
#'
#' For a vault that is its own repo, the \code{PENSAR_AUTO_PUSH}
#' environment variable is honored: if set to \code{"0"} or
#' \code{"false"} (case-insensitive), the push step is skipped.
#' Otherwise, pushes to every configured remote. A rejected push
#' (another author pushed first) is retried once after
#' \code{git pull --rebase}; concurrent appends to \code{log.md}
#' rebase cleanly because \code{init_vault()} marks it
#' \code{merge=union}, and a stopped rebase is resolved by the
#' \code{vault_merge()} engine. A rebase that still fails is aborted,
#' leaving the local commit unpushed for manual reconciliation.
#'
#' @param message Commit message.
#' @param vault Path to the vault directory.
#' @param push If \code{NULL} (default), honors \code{PENSAR_AUTO_PUSH}
#'   (own-repo vaults) or skips the push (nested vaults). Pass
#'   \code{TRUE} or \code{FALSE} to override.
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
    if (nchar(Sys.which("git")) == 0L) {
        return(invisible(FALSE))
    }
    if (is.null(vault_repo_root(vault))) {
        return(invisible(FALSE))
    }
    nested <- vault_is_nested(vault)

    # Stage all changes under the vault subtree. For an own-repo vault
    # the "." pathspec covers the whole repo; for a nested vault it
    # scopes staging so the enclosing repo is never swept.
    system2("git", c("-C", vault, "add", "-A", "--", "."),
            stdout = FALSE, stderr = FALSE)

    # Check if anything to commit
    status <- system2("git", c("-C", vault, "status", "--porcelain", "--", "."),
                      stdout = TRUE, stderr = FALSE)
    if (length(status) == 0L) {
        return(invisible(FALSE))
    }

    # A nested commit names the vault pathspec explicitly: git then
    # commits the vault subtree and disregards content staged for
    # other paths (which stays staged for the user's own commit).
    commit_args <- c("-C", vault, "commit", "-m", shQuote(message))
    if (nested) {
        commit_args <- c(commit_args, "--", ".")
    }
    commit_status <- system2("git", commit_args, stdout = FALSE,
                             stderr = FALSE)
    if (commit_status != 0L) {
        return(invisible(FALSE))
    }

    do_push <- if (nested) isTRUE(push) else should_push(push)
    if (do_push) {
        push_all_remotes(vault, rebase_retry = !nested)
    }
    invisible(TRUE)
}

#' Toplevel of the git repo enclosing the vault, or NULL
#'
#' Unlike a \code{.git} directory check, this recognizes vaults nested
#' inside a larger repo (and worktree checkouts, where \code{.git} is
#' a file).
#' @noRd
vault_repo_root <- function(vault) {
    if (nchar(Sys.which("git")) == 0L) {
        return(NULL)
    }
    out <- tryCatch(
                    suppressWarnings(system2("git",
                                             c("-C", vault, "rev-parse", "--show-toplevel"),
                                             stdout = TRUE, stderr = FALSE)),
                    error = function(e) character(0L)
    )
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        return(NULL)
    }
    if (length(out) != 1L || !nzchar(out)) {
        return(NULL)
    }
    normalizePath(out, mustWork = FALSE)
}

#' Repo-relative prefix of the vault ("" for an own-repo vault)
#' @noRd
vault_git_prefix <- function(vault) {
    out <- tryCatch(
                    suppressWarnings(system2("git",
                                             c("-C", vault, "rev-parse", "--show-prefix"),
                                             stdout = TRUE, stderr = FALSE)),
                    error = function(e) NULL
    )
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        return(NULL)
    }
    if (length(out) == 0L) {
        return("")
    }
    out[1L]
}

#' Is the vault nested inside a larger repo (not the repo root)?
#' @noRd
vault_is_nested <- function(vault) {
    prefix <- vault_git_prefix(vault)
    !is.null(prefix) && nzchar(prefix)
}

#' Absolute .git directory for the repo enclosing the vault, or NULL
#' @noRd
vault_git_dir <- function(vault) {
    out <- tryCatch(
                    suppressWarnings(system2("git",
                                             c("-C", vault, "rev-parse", "--absolute-git-dir"),
                                             stdout = TRUE, stderr = FALSE)),
                    error = function(e) character(0L)
    )
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        return(NULL)
    }
    if (length(out) != 1L || !nzchar(out)) {
        return(NULL)
    }
    out
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
                                        c("-C", path, "ls-tree", "-r", "HEAD", "--name-only"),
                                        stdout = TRUE, stderr = FALSE))
    if (length(tracked) == 0L) {
        return(TRUE)
    }
    tracked_pattern <- "^\\.gitignore$|^README\\.md$|\\.Rproj$"
    foreign_tracked <- !grepl(tracked_pattern, tracked)
    !any(foreign_tracked)
}

#' Push to all configured remotes (best-effort, errors swallowed)
#'
#' A rejected push (commonly a non-fast-forward because another vault
#' author pushed first) triggers one \code{git pull --rebase} + retry.
#' \code{log.md} is union-merged via the scaffolded
#' \code{.gitattributes}, so the rebase is conflict-free for
#' concurrent log appends (#52). A stopped rebase is resolved by the
#' \code{vault_merge()} engine: derived files regenerate, raw
#' collisions keep both files, wiki divergence resolves mechanically
#' or lands in the committed conflict digest. Only an unexpected
#' failure aborts the rebase, so the vault is never left mid-rebase.
#'
#' \code{rebase_retry = FALSE} (nested vaults, explicit push) skips
#' all of that: one plain push per remote, nothing else.
#' @noRd
push_all_remotes <- function(vault, rebase_retry = TRUE) {
    remotes <- tryCatch(
                        system2("git", c("-C", vault, "remote"), stdout = TRUE, stderr = FALSE),
                        error = function(e) character(0L)
    )
    if (length(remotes) == 0L) {
        return(invisible(NULL))
    }
    branch <- tryCatch(
                       system2("git", c("-C", vault, "rev-parse", "--abbrev-ref", "HEAD"),
                               stdout = TRUE, stderr = FALSE),
                       error = function(e) character(0L)
    )
    for (r in remotes) {
        pushed <- tryCatch(
                           system2("git", c("-C", vault, "push", r), stdout = FALSE,
                                   stderr = FALSE),
                           error = function(e) 1L
        )
        if (pushed == 0L || !rebase_retry || length(branch) != 1L ||
            branch == "HEAD") {
            next
        }
        rebased <- tryCatch(
                            system2("git",
                                    c("-C", vault, "pull", "--rebase", r, branch),
                                    stdout = FALSE, stderr = FALSE),
                            error = function(e) 1L
        )
        if (rebased != 0L) {
            resolved <- rebase_in_progress(vault) &&
            !is.null(tryCatch(collect_rebase_resolutions(vault),
                              error = function(e) NULL))
            if (!resolved) {
                tryCatch(
                         system2("git", c("-C", vault, "rebase", "--abort"),
                                 stdout = FALSE, stderr = FALSE),
                         error = function(e) NULL
                )
                next
            }
        }
        tryCatch(
                 system2("git", c("-C", vault, "push", r), stdout = FALSE,
                         stderr = FALSE),
                 error = function(e) NULL
        )
    }
    invisible(NULL)
}

#' Is a rebase currently stopped in the repo enclosing the vault?
#' @noRd
rebase_in_progress <- function(vault) {
    gd <- vault_git_dir(vault)
    if (is.null(gd)) {
        return(FALSE)
    }
    dir.exists(file.path(gd, "rebase-merge")) ||
    dir.exists(file.path(gd, "rebase-apply"))
}

#' Is a merge currently stopped in the repo enclosing the vault?
#' @noRd
merge_in_progress <- function(vault) {
    gd <- vault_git_dir(vault)
    !is.null(gd) && file.exists(file.path(gd, "MERGE_HEAD"))
}

#' Merge a conflicted .pensar/manifest.yml from its git index stages
#'
#' Reads ours (stage 2) and theirs (stage 3) out of the git index,
#' unions them by path against the merged working tree, and writes the
#' result over the conflict markers. A side whose stage is missing
#' (delete/modify, add/add) or unparseable contributes nothing.
#' \code{renames} (old relative path -> new relative path, from raw
#' add/add collisions) re-keys theirs' records before the union so a
#' renamed raw file keeps its provenance.
#' @noRd
merge_conflicted_manifest <- function(vault, renames = list()) {
    read_stage <- function(stage) {
        txt <- tryCatch(
                        suppressWarnings(system2("git",
                    c("-C", vault, "show",
                        sprintf(":%d:./.pensar/manifest.yml", stage)),
                    stdout = TRUE, stderr = FALSE)),
                        error = function(e) character(0L)
        )
        parsed <- tryCatch(yaml::yaml.load(paste(txt, collapse = "\n")),
                           error = function(e) NULL)
        suppressWarnings(normalize_manifest(parsed))
    }
    theirs <- read_stage(3L)
    for (from in names(renames)) {
        to <- renames[[from]]
        if (!is.null(theirs$sources[[from]])) {
            theirs$sources[[to]] <- theirs$sources[[from]]
            theirs$sources[[from]] <- NULL
        }
        if (!is.null(theirs$address_map[[from]])) {
            theirs$address_map[[to]] <- theirs$address_map[[from]]
            theirs$address_map[[from]] <- NULL
        }
    }
    merged <- merge_manifest_structs(read_stage(2L), theirs, vault)
    tryCatch({
        yaml::write_yaml(merged, file.path(vault, ".pensar", "manifest.yml"))
        TRUE
    }, error = function(e) FALSE)
}
