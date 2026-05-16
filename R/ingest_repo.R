#' @title Repo ingestion
#' @description Ingest a git repo's metadata, briefing, and AST into the vault.

#' Ingest a repository snapshot into the vault
#'
#' Captures repo state pinned to a commit SHA so wiki claims can cite a
#' specific point in time. Writes one or more artifacts under
#' \code{raw/repos/<name>/<artifact>.md}:
#' \describe{
#'   \item{briefing.md}{\code{type: repo-briefing} -- saber digest of HEAD
#'     (regenerable). Requires the \code{saber} package.}
#'   \item{ast.md}{\code{type: repo-ast} -- exported and internal symbols
#'     from \code{saber::symbols()} (regenerable). Requires \code{saber}.}
#'   \item{snapshot.md}{\code{type: repo-snapshot} -- commit-pinned
#'     metadata: SHA, origin URL, branch, tracked file listing, recent
#'     commits.}
#' }
#'
#' Re-running overwrites the artifact files in place; git tracks history.
#' This supersedes \code{ingest_briefing()}, which is now deprecated.
#'
#' @param path Path to a local git repo. Tilde-expanded.
#' @param name Repo identifier used as the directory name under
#'   \code{raw/repos/}. Defaults to \code{basename(path)}.
#' @param ref Git ref to snapshot. Default \code{"HEAD"}.
#' @param enrich One of \code{"auto"} (detect R package and enrich),
#'   \code{"package"} (force package digest; errors if no DESCRIPTION),
#'   or \code{"none"} (snapshot only). Default \code{"auto"}.
#' @param artifacts Subset of \code{c("briefing", "ast", "snapshot")} to
#'   write. Default writes all that apply for the chosen enrich mode.
#' @param files Optional file globs (relative to the repo root) whose
#'   tracked paths are listed in \code{snapshot.md}. Contents are not
#'   stored. Default \code{"R/*.R"} for R packages, \code{NULL} otherwise.
#' @param tags Optional character vector of tags applied to every written
#'   artifact.
#' @param vault Path to the vault directory.
#' @return Character vector of paths written, invisibly.
#' @examples
#' \dontrun{
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest_repo("~/corteza", vault = v)
#' }
#' @export
ingest_repo <- function(path, name = NULL, ref = "HEAD",
                        enrich = c("auto", "package", "none"),
                        artifacts = c("briefing", "ast", "snapshot"),
                        files = NULL, tags = NULL, vault = default_vault()) {
    enrich <- match.arg(enrich)
    artifacts <- match.arg(artifacts, several.ok = TRUE)

    path <- normalizePath(path, mustWork = TRUE)
    name <- name %||% basename(path)
    vault <- normalizePath(vault, mustWork = TRUE)

    if (!file.exists(file.path(vault, "schema.md"))) {
        stop("Not a pensar vault: ", vault, ". Run init_vault() first.")
    }
    if (!file.exists(file.path(path, ".git"))) {
        stop("Not a git repository: ", path, call. = FALSE)
    }

    has_desc <- file.exists(file.path(path, "DESCRIPTION"))
    if (enrich == "auto") {
        if (has_desc) {
            enrich <- "package"
        } else {
            enrich <- "none"
        }
    }
    if (enrich == "package" && !has_desc) {
        stop("enrich = 'package' but no DESCRIPTION at ", path, call. = FALSE)
    }
    if (enrich == "package" && !requireNamespace("saber", quietly = TRUE)) {
        stop("enrich = 'package' requires the 'saber' package.", call. = FALSE)
    }

    git_meta <- repo_git_meta(path, ref)
    if (is.null(files)) {
        if (enrich == "package") {
            files <- "R/*.R"
        }
    }

    repo_dir <- file.path(vault, "raw", "repos", name)
    dir.create(repo_dir, recursive = TRUE, showWarnings = FALSE)

    written <- character(0L)

    if ("briefing" %in% artifacts && enrich == "package") {
        content <- saber::briefing(name, scan_dir = dirname(path))
        outpath <- file.path(repo_dir, "briefing.md")
        write_repo_artifact(outpath, "repo-briefing", name, git_meta,
                            content, tags)
        written <- c(written, outpath)
    }

    if ("ast" %in% artifacts && enrich == "package") {
        content <- format_repo_ast(name, path)
        outpath <- file.path(repo_dir, "ast.md")
        write_repo_artifact(outpath, "repo-ast", name, git_meta, content, tags)
        written <- c(written, outpath)
    }

    if ("snapshot" %in% artifacts) {
        content <- format_repo_snapshot(path, git_meta, files)
        outpath <- file.path(repo_dir, "snapshot.md")
        write_repo_artifact(outpath, "repo-snapshot", name, git_meta,
                            content, tags)
        written <- c(written, outpath)
    }

    update_index(vault)
    log_entry(sprintf("Ingested repo: %s @ %s", name, git_meta$short_sha),
              operation = "ingest_repo", vault = vault)
    vault_commit(sprintf("Ingest repo: %s @ %s", name, git_meta$short_sha),
                 vault = vault)

    message(sprintf("Ingested repo: %s (%d artifacts)", name, length(written)))
    invisible(written)
}

#' Capture git metadata for a repo at a given ref
#' @noRd
repo_git_meta <- function(path, ref = "HEAD") {
    git1 <- function(...) {
        out <- suppressWarnings(tryCatch(
                system2("git", c("-C", path, ...), stdout = TRUE,
                        stderr = FALSE),
                error = function(e) character(0L)))
        if (length(out) == 0L) {
            ""
        } else {
            out[[1L]]
        }
    }
    sha <- git1("rev-parse", ref)
    list(
         path = path,
         sha = sha,
         short_sha = if (nzchar(sha)) substr(sha, 1L, 7L) else "",
         branch = git1("rev-parse", "--abbrev-ref", ref),
         origin = git1("config", "--get", "remote.origin.url"),
         commit_date = git1("log", "-1", "--format=%cI", ref),
         commit_subject = git1("log", "-1", "--format=%s", ref)
    )
}

#' Write a repo artifact file with structured frontmatter
#' @noRd
write_repo_artifact <- function(outpath, type, name, git_meta, content,
                                tags = NULL) {
    artifact <- sub("^repo-", "", type)
    title <- sprintf("%s @ %s (%s)", name,
        if (nzchar(git_meta$short_sha)) git_meta$short_sha
        else "unpinned",
                     artifact)
    fm <- list(
               title = title,
               type = type,
               source = if (nzchar(git_meta$origin)) git_meta$origin else
               git_meta$path,
               date = format(Sys.Date(), "%Y-%m-%d"),
               repo = list(name = name, path = git_meta$path,
                           origin = git_meta$origin, branch = git_meta$branch,
                           commit = git_meta$sha, commit_short = git_meta$short_sha,
                           commit_date = git_meta$commit_date,
                           commit_subject = git_meta$commit_subject)
    )
    if (!is.null(tags)) {
        fm$tags <- tags
    }
    fm_yaml <- yaml::as.yaml(fm)
    if (is.character(content)) {
        body <- content
    } else {
        body <- as.character(content)
    }
    lines <- c("---", sub("\n$", "", fm_yaml), "---", "", body)
    writeLines(lines, outpath)
}

#' Format a saber::symbols() index as a markdown AST briefing
#' @noRd
format_repo_ast <- function(name, path) {
    sym <- tryCatch(saber::symbols(path), error = function(e) NULL)
    if (is.null(sym) || nrow(sym$defs) == 0L) {
        return(c(sprintf("# AST: %s", name), "", "_(no symbols found)_"))
    }
    defs <- sym$defs
    n_def <- nrow(defs)
    n_exp <- sum(defs$exported)
    n_calls <- nrow(sym$calls)
    exp_defs <- defs[defs$exported,, drop = FALSE]
    int_defs <- defs[!defs$exported,, drop = FALSE]

    fmt_def <- function(d) {
        sprintf("- `%s` (%s:%d)", d$name, basename(d$file), d$line)
    }
    fmt_block <- function(rows) {
        if (nrow(rows) == 0L) {
            return("_(none)_")
        }
        vapply(seq_len(nrow(rows)),
               function(i) fmt_def(rows[i,, drop = FALSE]), character(1L))
    }

    c(sprintf("# AST: %s", name),
        sprintf("_Generated %s via saber::symbols()_",
                format(Sys.time(), "%Y-%m-%d %H:%M")),
        "",
        "## Summary",
        sprintf("- Definitions: %d (%d exported)", n_def, n_exp),
        sprintf("- Call edges: %d", n_calls),
        "",
        "## Exported functions",
        fmt_block(exp_defs),
        "",
        "## Internal functions",
        fmt_block(int_defs))
}

#' Format a snapshot artifact body: file listing + recent commits
#' @noRd
format_repo_snapshot <- function(path, git_meta, files) {
    file_lines <- if (length(files) > 0L) {
        listing <- character(0L)
        for (pat in files) {
            out <- suppressWarnings(tryCatch(
                    system2("git", c("-C", path, "ls-files", pat),
                            stdout = TRUE, stderr = FALSE),
                    error = function(e) character(0L)))
            listing <- c(listing, out)
        }
        listing <- sort(unique(listing))
        if (length(listing) == 0L) {
            "_(none matched)_"
        } else {
            paste0("- `", listing, "`")
        }

    } else {
        "_(no file globs supplied)_"
    }

    recent <- suppressWarnings(tryCatch(
                                        system2("git", c("-C", path, "log", "-5", "--format=%h %s"),
                stdout = TRUE, stderr = FALSE),
                                        error = function(e) character(0L)))
    if (length(recent) == 0L) {
        recent_lines <- "_(none)_"
    } else {
        recent_lines <- paste0("- ", recent)
    }

    if (nzchar(git_meta$short_sha)) {
        short <- git_meta$short_sha
    } else {
        short <- "unpinned"
    }
    c(sprintf("# %s @ %s", basename(path), short),
        "",
        "## Files",
        file_lines,
        "",
        "## Recent commits",
        recent_lines)
}

