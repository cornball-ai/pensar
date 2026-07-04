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
#' step. Otherwise, pushes to every configured remote. A rejected
#' push (another author pushed first) is retried once after
#' \code{git pull --rebase}; concurrent appends to \code{log.md}
#' rebase cleanly because \code{init_vault()} marks it
#' \code{merge=union}. A rebase that hits a real conflict is aborted,
#' leaving the local commit unpushed for manual reconciliation.
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
#' concurrent log appends (#52). A rebase stopped only by derived
#' files (\code{index.md}, \code{.pensar/manifest.yml}) is resolved
#' mechanically via \code{resolve_derived_conflicts()}; any other
#' conflict aborts the whole rebase, so the vault is never left
#' mid-rebase.
#' @noRd
push_all_remotes <- function(vault) {
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
        if (pushed == 0L || length(branch) != 1L || branch == "HEAD") {
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
            tryCatch(resolve_derived_conflicts(vault),
                     error = function(e) FALSE)
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

#' Is a rebase currently stopped in this repo?
#' @noRd
rebase_in_progress <- function(vault) {
    dir.exists(file.path(vault, ".git", "rebase-merge")) ||
    dir.exists(file.path(vault, ".git", "rebase-apply"))
}

#' Resolve a stopped rebase whose conflicts are all derived files
#'
#' \code{index.md} is regenerated from the merged tree (it's fully
#' derived); \code{.pensar/manifest.yml} is unioned by path and pruned
#' to the tree (it's provenance, so it can't be regenerated). The
#' rebase is then continued, repeating for sequentially conflicting
#' picks. Returns \code{TRUE} when the rebase ran to completion,
#' \code{FALSE} on any conflict outside the derived set or any
#' unexpected stop -- the caller aborts the whole rebase then, so a
#' partial resolution never survives.
#' @noRd
resolve_derived_conflicts <- function(vault) {
    derived <- c("index.md", ".pensar/manifest.yml")
    for (i in seq_len(50L)) {
        if (!rebase_in_progress(vault)) {
            return(TRUE)
        }
        conflicted <- tryCatch(
                               suppressWarnings(system2("git",
                                                        c("-C", vault, "diff", "--name-only",
                                                          "--diff-filter=U"),
                                                        stdout = TRUE, stderr = FALSE)),
                               error = function(e) character(0L)
        )
        if (length(conflicted) == 0L || !all(conflicted %in% derived)) {
            return(FALSE)
        }
        if (".pensar/manifest.yml" %in% conflicted &&
            !merge_conflicted_manifest(vault)) {
            return(FALSE)
        }
        if ("index.md" %in% conflicted) {
            update_index(vault)
        }
        added <- system2("git", c("-C", vault, "add", "--", conflicted),
                         stdout = FALSE, stderr = FALSE)
        if (added != 0L) {
            return(FALSE)
        }
        # An empty pick (regeneration reproduced HEAD exactly) can't
        # be committed; skip it instead.
        staged <- system2("git", c("-C", vault, "diff", "--cached", "--quiet"),
                          stdout = FALSE, stderr = FALSE)
        if (staged == 0L) {
            system2("git", c("-C", vault, "rebase", "--skip"),
                    stdout = FALSE, stderr = FALSE)
        } else {
            system2("git",
                    c("-C", vault, "-c", "core.editor=true", "rebase",
                      "--continue"),
                    stdout = FALSE, stderr = FALSE)
        }
    }
    FALSE
}

#' Merge a conflicted .pensar/manifest.yml from its git index stages
#'
#' Reads ours (stage 2) and theirs (stage 3) out of the git index,
#' unions them by path against the merged working tree, and writes the
#' result over the conflict markers. A side whose stage is missing
#' (delete/modify, add/add) or unparseable contributes nothing.
#' @noRd
merge_conflicted_manifest <- function(vault) {
    read_stage <- function(stage) {
        txt <- tryCatch(
                        suppressWarnings(system2("git",
                                                 c("-C", vault, "show",
                                                   sprintf(":%d:.pensar/manifest.yml", stage)),
                                                 stdout = TRUE, stderr = FALSE)),
                        error = function(e) character(0L)
        )
        parsed <- tryCatch(yaml::yaml.load(paste(txt, collapse = "\n")),
                           error = function(e) NULL)
        suppressWarnings(normalize_manifest(parsed))
    }
    merged <- merge_manifest_structs(read_stage(2L), read_stage(3L), vault)
    tryCatch({
        yaml::write_yaml(merged, file.path(vault, ".pensar", "manifest.yml"))
        TRUE
    }, error = function(e) FALSE)
}
