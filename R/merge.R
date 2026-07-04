#' @title Vault merge resolution
#' @description Mechanical resolution of stopped git merges and rebases.

#' Resolve a stopped git merge or rebase in the vault
#'
#' Resolves every conflicted path mechanically where the correct
#' result is computable, and files genuine divergence into a committed
#' digest at \code{.pensar/merge-conflicts.md} for later synthesis.
#' The vault is never left mid-merge: after resolution the rebase is
#' continued (or the merge committed).
#'
#' Resolution by class:
#' \itemize{
#'   \item \code{index.md}: regenerated from the merged tree.
#'   \item \code{.pensar/manifest.yml}: unioned by path and pruned to
#'     the merged tree (see \code{merge_manifest_structs()}).
#'   \item \code{log.md} and the digest itself: line union (both
#'     sides' appended lines survive), covering vaults whose
#'     \code{.gitattributes} predates the union-merge scaffold.
#'   \item Raw add/add collisions: both files kept; the incoming side
#'     is renamed with a numeric suffix and its manifest record is
#'     re-keyed. Raw is ground truth; nothing is discarded.
#'   \item Wiki (and other markdown) pages: a strict superset side
#'     wins outright; otherwise the side with valid frontmatter and
#'     strictly fewer broken wikilinks wins and the discarded version
#'     goes to the digest; otherwise the current branch's side is kept
#'     and both full versions go to the digest.
#' }
#'
#' Digest entries carry a content-derived id (path + both blob shas +
#' class), so re-running the resolution is idempotent. Entries embed
#' both full versions inside code fences and use plain paths, never
#' wikilinks, so the digest stays out of the link graph.
#'
#' @param vault Path to the vault directory.
#' @return Invisibly, a data frame with one row per resolved path
#'   (columns \code{path}, \code{class}, \code{kept}, \code{digested}),
#'   or \code{NULL} when no merge or rebase was in progress.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' # No git repo, nothing stopped: returns NULL with a message.
#' vault_merge(v)
#' unlink(v, recursive = TRUE)
#' @export
vault_merge <- function(vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)
    if (!dir.exists(file.path(vault, ".git")) ||
        nchar(Sys.which("git")) == 0L) {
        message("No merge or rebase in progress.")
        return(invisible(NULL))
    }

    if (rebase_in_progress(vault)) {
        plans <- collect_rebase_resolutions(vault)
        if (is.null(plans)) {
            message("Could not resolve the stopped rebase mechanically; ",
                    "it was left in place for manual resolution.")
            return(invisible(NULL))
        }
        report_merge_summary(plans)
        return(invisible(plans))
    }

    if (file.exists(file.path(vault, ".git", "MERGE_HEAD"))) {
        plans <- tryCatch(resolve_stopped_merge(vault),
                          error = function(e) NULL)
        if (is.null(plans)) {
            message("Could not resolve the stopped merge mechanically; ",
                    "it was left in place for manual resolution.")
            return(invisible(NULL))
        }
        committed <- system2("git",
                             c("-C", vault, "-c", "core.editor=true",
                               "commit", "--no-edit"),
                             stdout = FALSE, stderr = FALSE)
        if (committed != 0L) {
            message("Conflicts resolved and staged, but the merge ",
                    "commit failed; finish with `git commit`.")
            return(invisible(plans))
        }
        report_merge_summary(plans)
        return(invisible(plans))
    }

    message("No merge or rebase in progress.")
    invisible(NULL)
}

#' Run the rebase-stop resolver loop, accumulating plans for reporting
#'
#' Same loop as \code{resolve_rebase_stops()} but keeps the per-stop
#' plans so \code{vault_merge()} can report. Returns \code{NULL} when
#' a stop could not be resolved (the rebase is left in place).
#' @noRd
collect_rebase_resolutions <- function(vault) {
    all_plans <- empty_merge_summary()
    for (i in seq_len(50L)) {
        if (!rebase_in_progress(vault)) {
            return(all_plans)
        }
        plans <- tryCatch(resolve_stopped_merge(vault),
                          error = function(e) NULL)
        if (is.null(plans)) {
            return(NULL)
        }
        all_plans <- rbind(all_plans, plans)
        if (!continue_rebase(vault)) {
            return(NULL)
        }
    }
    NULL
}

#' Continue (or skip) a stopped rebase after conflicts were staged
#' @noRd
continue_rebase <- function(vault) {
    staged <- system2("git", c("-C", vault, "diff", "--cached", "--quiet"),
                      stdout = FALSE, stderr = FALSE)
    if (staged == 0L) {
        # An empty pick (resolution reproduced HEAD exactly) can't be
        # committed; skip it instead.
        status <- system2("git", c("-C", vault, "rebase", "--skip"),
                          stdout = FALSE, stderr = FALSE)
    } else {
        status <- system2("git",
                          c("-C", vault, "-c", "core.editor=true", "rebase",
                            "--continue"),
                          stdout = FALSE, stderr = FALSE)
    }
    # A non-zero status with the rebase still alive means the next
    # pick conflicted, which the caller's loop handles.
    status == 0L || rebase_in_progress(vault)
}

#' @noRd
report_merge_summary <- function(plans) {
    if (nrow(plans) == 0L) {
        message("Nothing to resolve.")
        return(invisible(NULL))
    }
    message(sprintf("Resolved %d conflicted path(s): %d mechanical, %d digested.",
                    nrow(plans), sum(!plans$digested), sum(plans$digested)))
    if (any(plans$digested)) {
        message("Review .pensar/merge-conflicts.md to synthesize the ",
                "digested divergence.")
    }
    invisible(NULL)
}

#' @noRd
empty_merge_summary <- function() {
    data.frame(path = character(0L), class = character(0L),
               kept = character(0L), digested = logical(0L),
               stringsAsFactors = FALSE)
}

#' Resolve every conflicted path of a stopped merge/rebase (one stop)
#'
#' Two phases, digest first: (1) classify every conflicted path and
#' build digest entries from the in-memory stage contents; (2) write
#' the digest, then apply resolutions to the working tree, then stage
#' everything. A crash mid-apply leaves the digest on disk with both
#' versions preserved. Does not continue the rebase or commit the
#' merge; callers do that.
#'
#' Returns a summary data frame, or errors when there is nothing it
#' can do (no conflicted paths, or a git command failed).
#' @noRd
resolve_stopped_merge <- function(vault) {
    stages <- conflicted_stages(vault)
    if (nrow(stages) == 0L) {
        stop("no conflicted paths in a stopped state")
    }

    # Phase 1: classify. No tree writes happen here.
    plans <- lapply(unique(stages$path), function(p) {
        classify_conflict(p, stages[stages$path == p, , drop = FALSE], vault)
    })

    # Phase 2a: the digest is written before any resolution touches
    # the working tree, so both versions survive a crash mid-apply.
    entries <- Filter(Negate(is.null), lapply(plans, function(pl) pl$entry))
    digest_written <- length(entries) > 0L
    if (digest_written) {
        append_digest(vault, entries)
    }

    # Phase 2b: apply. Raw renames go first so the manifest union can
    # hash-match records against the renamed files.
    renames <- list()
    for (pl in plans) {
        if (pl$class == "raw-collision") {
            writeLines(pl$ours, file.path(vault, pl$path))
            to_abs <- unique_path(file.path(vault, pl$path))
            writeLines(pl$theirs, to_abs)
            renames[[pl$path]] <- substring(to_abs, nchar(vault) + 2L)
        }
    }
    for (pl in plans) {
        if (pl$class %in% c("raw-collision", "index-regen",
                            "manifest-union")) {
            next
        }
        if (is.null(pl$kept_lines)) {
            # Opaque (non-text) content: resolve via git, don't touch bytes.
            side <- if (identical(pl$kept, "theirs")) "--theirs" else "--ours"
            system2("git",
                    c("-C", vault, "checkout", side, "--", shQuote(pl$path)),
                    stdout = FALSE, stderr = FALSE)
        } else {
            writeLines(pl$kept_lines, file.path(vault, pl$path))
        }
    }
    classes <- vapply(plans, function(pl) pl$class, character(1L))
    if ("manifest-union" %in% classes) {
        if (!merge_conflicted_manifest(vault, renames)) {
            stop("manifest union failed")
        }
    } else if (length(renames) > 0L) {
        rekey_manifest_on_disk(vault, renames)
    }
    if ("index-regen" %in% classes) {
        update_index(vault)
    }

    to_stage <- c(vapply(plans, function(pl) pl$path, character(1L)),
                  unlist(renames, use.names = FALSE),
                  if (digest_written) ".pensar/merge-conflicts.md",
                  if (length(renames) > 0L) ".pensar/manifest.yml")
    added <- system2("git",
                     c("-C", vault, "add", "--",
                       vapply(unique(to_stage), shQuote, character(1L))),
                     stdout = FALSE, stderr = FALSE)
    if (added != 0L) {
        stop("git add failed")
    }

    do.call(rbind, c(list(empty_merge_summary()), lapply(plans, function(pl) {
        data.frame(path = pl$path, class = pl$class, kept = pl$kept,
                   digested = !is.null(pl$entry), stringsAsFactors = FALSE)
    })))
}

#' Parse `git ls-files -u` into a data frame of conflicted stages
#' @noRd
conflicted_stages <- function(vault) {
    out <- tryCatch(
                    suppressWarnings(system2("git", c("-C", vault, "ls-files", "-u"),
                                             stdout = TRUE, stderr = FALSE)),
                    error = function(e) character(0L)
    )
    if (length(out) == 0L) {
        return(data.frame(path = character(0L), stage = integer(0L),
                          sha = character(0L), stringsAsFactors = FALSE))
    }
    # Format: "<mode> <sha> <stage>\t<path>"
    tab <- regexpr("\t", out, fixed = TRUE)
    meta <- strsplit(substr(out, 1L, tab - 1L), " ", fixed = TRUE)
    data.frame(path = substring(out, tab + 1L),
               stage = as.integer(vapply(meta, `[`, character(1L), 3L)),
               sha = vapply(meta, `[`, character(1L), 2L),
               stringsAsFactors = FALSE)
}

#' Read one side of a conflicted path from the git index
#' @noRd
read_stage_lines <- function(vault, stage, path) {
    lines <- tryCatch(
                      suppressWarnings(system2("git",
                                               c("-C", vault, "show",
                                                 sprintf(":%d:%s", stage, shQuote(path))),
                                               stdout = TRUE, stderr = FALSE)),
                      error = function(e) NULL
    )
    status <- attr(lines, "status")
    if (!is.null(status) && status != 0L) {
        return(NULL)
    }
    lines
}

#' Classify one conflicted path and precompute its resolution
#'
#' Returns a list with \code{path}, \code{class}, \code{kept}
#' ("ours"/"theirs"/"both"/"union"/"regen"), \code{kept_lines}
#' (\code{NULL} for opaque or deferred classes), \code{ours}/
#' \code{theirs} line vectors where relevant, and \code{entry}
#' (digest entry lines, or \code{NULL} when nothing is lost).
#' @noRd
classify_conflict <- function(path, stages, vault) {
    sha_of <- function(stage) {
        s <- stages$sha[stages$stage == stage]
        if (length(s) == 1L) s else NA_character_
    }
    ours_sha <- sha_of(2L)
    theirs_sha <- sha_of(3L)
    plan <- list(path = path, ours_sha = ours_sha, theirs_sha = theirs_sha,
                 entry = NULL)

    if (path == "index.md") {
        plan$class <- "index-regen"
        plan$kept <- "regen"
        return(plan)
    }
    if (path == ".pensar/manifest.yml") {
        plan$class <- "manifest-union"
        plan$kept <- "union"
        return(plan)
    }

    text_like <- grepl("\\.(md|yml|yaml|txt)$", path) ||
    path == ".gitattributes"
    ours <- if (!is.na(ours_sha)) read_stage_lines(vault, 2L, path)
    theirs <- if (!is.na(theirs_sha)) read_stage_lines(vault, 3L, path)

    if (path %in% c("log.md", ".pensar/merge-conflicts.md")) {
        plan$class <- "line-union"
        plan$kept <- "union"
        plan$kept_lines <- union_lines(ours, theirs)
        return(plan)
    }

    if (!text_like) {
        # Opaque content: keep whichever side exists (ours on a tie),
        # resolve via git checkout, digest a note without bytes.
        plan$class <- "opaque-divergence"
        plan$kept <- if (is.na(ours_sha)) "theirs" else "ours"
        plan$kept_lines <- NULL
        plan$entry <- digest_entry(plan, vault, embed = FALSE)
        return(plan)
    }

    delete_side <- is.na(ours_sha) || is.na(theirs_sha)
    if (startsWith(path, "raw/")) {
        if (!delete_side && !any(stages$stage == 1L)) {
            # add/add: two authors independently created the same
            # slug. Raw is immutable ground truth; keep both.
            plan$class <- "raw-collision"
            plan$kept <- "both"
            plan$ours <- ours
            plan$theirs <- theirs
            plan$entry <- digest_entry(plan, vault, embed = FALSE)
            return(plan)
        }
        # Raw modify/modify or delete/modify should not happen (raw is
        # immutable after ingest). Preserve content, flag the anomaly.
        plan$class <- "raw-anomaly"
        plan$kept <- if (is.na(ours_sha)) "theirs" else "ours"
        plan$kept_lines <- if (is.na(ours_sha)) theirs else ours
        plan$ours <- ours
        plan$theirs <- theirs
        plan$entry <- digest_entry(plan, vault)
        return(plan)
    }

    if (delete_side) {
        # Deleted on one side, edited on the other: keep the content
        # side (nothing is lost that way), digest the disagreement.
        plan$class <- "delete-modify"
        plan$kept <- if (is.na(ours_sha)) "theirs" else "ours"
        plan$kept_lines <- if (is.na(ours_sha)) theirs else ours
        plan$ours <- ours
        plan$theirs <- theirs
        plan$entry <- digest_entry(plan, vault)
        return(plan)
    }

    if (is_strict_subsequence(theirs, ours)) {
        # Ours contains everything theirs has, in order: pure addition.
        plan$class <- "superset"
        plan$kept <- "ours"
        plan$kept_lines <- ours
        return(plan)
    }
    if (is_strict_subsequence(ours, theirs)) {
        plan$class <- "superset"
        plan$kept <- "theirs"
        plan$kept_lines <- theirs
        return(plan)
    }

    lo <- candidate_lint(ours, vault)
    lt <- candidate_lint(theirs, vault)
    if (lint_dominates(lo, lt) || lint_dominates(lt, lo)) {
        ours_wins <- lint_dominates(lo, lt)
        plan$class <- "lint-preferred"
        plan$kept <- if (ours_wins) "ours" else "theirs"
        plan$kept_lines <- if (ours_wins) ours else theirs
        plan$ours <- ours
        plan$theirs <- theirs
        # Lint is a soft signal and the losing side may hold real
        # prose; digest it so nothing is silently discarded.
        plan$entry <- digest_entry(plan, vault, lint = list(ours = lo,
                                                            theirs = lt))
        return(plan)
    }

    plan$class <- "prose-divergence"
    plan$kept <- "ours"
    plan$kept_lines <- ours
    plan$ours <- ours
    plan$theirs <- theirs
    plan$entry <- digest_entry(plan, vault, lint = list(ours = lo,
                                                        theirs = lt))
    plan
}

#' Is `small` a strict ordered subsequence of `big`?
#' @noRd
is_strict_subsequence <- function(small, big) {
    if (is.null(small) || is.null(big) || length(small) >= length(big)) {
        return(FALSE)
    }
    j <- 1L
    for (i in seq_along(big)) {
        if (j > length(small)) {
            break
        }
        if (identical(big[i], small[j])) {
            j <- j + 1L
        }
    }
    j > length(small)
}

#' Frontmatter validity and broken-wikilink count for candidate text
#' @noRd
candidate_lint <- function(lines, vault) {
    tmp <- tempfile(fileext = ".md")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(lines, tmp)
    fm <- tryCatch(parse_frontmatter(tmp), error = function(e) list())
    links <- tryCatch(parse_wikilinks(tmp), error = function(e) character(0L))
    broken <- 0L
    for (l in links) {
        resolved <- tryCatch(resolve_target_path(l, vault),
                             error = function(e) NA_character_)
        if (is.na(resolved)) {
            broken <- broken + 1L
        }
    }
    list(fm_ok = length(fm) > 0L, broken = broken)
}

#' Does lint result `a` strictly dominate `b`?
#'
#' No worse on both dimensions (frontmatter validity, broken-link
#' count) and strictly better on at least one.
#' @noRd
lint_dominates <- function(a, b) {
    a_bad <- as.integer(!a$fm_ok)
    b_bad <- as.integer(!b$fm_ok)
    (a_bad <= b_bad && a$broken <= b$broken) &&
    (a_bad < b_bad || a$broken < b$broken)
}

#' Union two line vectors, preserving ours order then theirs additions
#'
#' The in-package equivalent of git's built-in union merge driver,
#' used when a vault's .gitattributes predates the union scaffold.
#' @noRd
union_lines <- function(ours, theirs) {
    if (is.null(ours)) {
        return(theirs)
    }
    if (is.null(theirs)) {
        return(ours)
    }
    c(ours, theirs[!(theirs %in% ours)])
}

#' Content-derived digest entry id
#'
#' path + both blob shas + class. Re-running the same resolution
#' produces the same id, which \code{append_digest()} dedupes on.
#' @noRd
digest_entry_id <- function(path, ours_sha, theirs_sha, class) {
    short <- function(s) {
        if (is.na(s)) "absent" else substr(s, 1L, 7L)
    }
    sprintf("%s %s..%s %s", path, short(ours_sha), short(theirs_sha), class)
}

#' Build the digest entry lines for one resolved conflict
#'
#' Plain paths and code fences only -- never wikilinks -- so the
#' digest stays out of the link graph and lint's backlog.
#' @noRd
digest_entry <- function(plan, vault, embed = TRUE, lint = NULL) {
    id <- digest_entry_id(plan$path, plan$ours_sha, plan$theirs_sha,
                          plan$class)
    page <- name_from_path(plan$path)
    bl <- tryCatch(backlinks(page, vault)$file, error = function(e) character(0L))
    out <- c(sprintf("## %s", id), "",
             sprintf("- path: `%s`", plan$path),
             sprintf("- class: %s", plan$class),
             sprintf("- kept: %s", plan$kept),
             sprintf("- merged_at: %s", now_ts()))
    if (length(bl) > 0L) {
        out <- c(out, sprintf("- backlinks: %s",
                              paste0("`", bl, "`", collapse = ", ")))
    }
    if (!is.null(lint)) {
        out <- c(out, sprintf("- lint: ours %s frontmatter, %d broken; theirs %s frontmatter, %d broken",
                              if (lint$ours$fm_ok) "valid" else "invalid",
                              lint$ours$broken,
                              if (lint$theirs$fm_ok) "valid" else "invalid",
                              lint$theirs$broken))
    }
    if (plan$class == "raw-collision") {
        out <- c(out, "- note: both raw files kept; the incoming side was renamed with a numeric suffix and its manifest record re-keyed. Review for near-duplicates.")
    }
    out <- c(out, "")
    if (!embed) {
        note <- if (plan$class == "raw-collision") {
            "(Nothing discarded; both files are in the tree.)"
        } else {
            "(Content not embedded; both versions are in git history.)"
        }
        return(c(out, note, ""))
    }
    fence <- "````"
    if (!is.null(plan$ours)) {
        out <- c(out, sprintf("### Ours (%s)%s",
                              substr(plan$ours_sha, 1L, 7L),
                              if (plan$kept == "ours") " -- kept" else ""),
                 "", fence, plan$ours, fence, "")
    }
    if (!is.null(plan$theirs)) {
        out <- c(out, sprintf("### Theirs (%s)%s",
                              substr(plan$theirs_sha, 1L, 7L),
                              if (plan$kept == "theirs") " -- kept" else ""),
                 "", fence, plan$theirs, fence, "")
    }
    out
}

#' Append digest entries to .pensar/merge-conflicts.md, deduped by id
#' @noRd
append_digest <- function(vault, entries) {
    fp <- file.path(vault, ".pensar", "merge-conflicts.md")
    dir.create(dirname(fp), recursive = TRUE, showWarnings = FALSE)
    existing <- if (file.exists(fp)) readLines(fp, warn = FALSE) else digest_seed()
    existing_ids <- sub("^## ", "", grep("^## ", existing, value = TRUE))
    fresh <- Filter(function(e) {
        !(sub("^## ", "", e[1L]) %in% existing_ids)
    }, entries)
    if (length(fresh) == 0L) {
        if (!file.exists(fp)) {
            writeLines(existing, fp)
        }
        return(invisible(fp))
    }
    writeLines(c(existing, unlist(fresh)), fp)
    invisible(fp)
}

#' Digest file seed (header + resolution instructions)
#' @noRd
digest_seed <- function() {
    c("---", "title: Merge Conflicts", "type: merge-digest", "---", "",
      "# Merge Conflicts", "",
      "Divergence preserved by automatic merge resolution, pending",
      "synthesis. For each entry: read both versions, drill down into",
      "cited sources, edit the wiki page to synthesize what both",
      "authors meant, then delete the entry. Delete this file when no",
      "entries remain, then commit.", "")
}

#' Re-key manifest records for renamed raw files (unconflicted manifest)
#'
#' Used when raw add/add renames happened but the manifest itself did
#' not conflict. A record keyed at the old path whose hash matches the
#' renamed file (and not the file still at the old path) moves to the
#' new path.
#' @noRd
rekey_manifest_on_disk <- function(vault, renames) {
    m <- read_manifest(vault)
    changed <- FALSE
    for (from in names(renames)) {
        to <- renames[[from]]
        rec <- m$sources[[from]]
        if (!is.list(rec) || is.null(rec$hash)) {
            next
        }
        hash_at <- function(p) {
            tryCatch(paste0("sha1:",
                            digest::digest(file = file.path(vault, p),
                                           algo = "sha1")),
                     error = function(e) NA_character_)
        }
        if (identical(rec$hash, hash_at(to)) &&
            !identical(rec$hash, hash_at(from))) {
            m$sources[[to]] <- rec
            m$sources[[from]] <- NULL
            changed <- TRUE
        }
        uid <- m$address_map[[from]]
        if (!is.null(uid) && is.null(m$address_map[[to]]) &&
            !is.null(m$sources[[to]])) {
            m$address_map[[to]] <- uid
            changed <- TRUE
        }
    }
    if (changed) {
        fp <- file.path(vault, ".pensar", "manifest.yml")
        dir.create(dirname(fp), recursive = TRUE, showWarnings = FALSE)
        yaml::write_yaml(m, fp)
    }
    invisible(changed)
}
