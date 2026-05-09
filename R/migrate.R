#' @title Migration helpers
#' @description Move legacy raw/briefings/ content into raw/repos/<repo>/.

#' Migrate legacy briefings to the repo provenance layout
#'
#' Walks \code{raw/briefings/}, classifies each file as a briefing or AST
#' artifact, maps the slug to a repo name, keeps the newest file per
#' \code{(repo, artifact)} pair, and moves it to
#' \code{raw/repos/<repo>/<artifact>.md}. Older duplicates are dropped if
#' \code{drop_old = TRUE} (git history retains them).
#'
#' Wikilinks are rewritten in \code{wiki/*.md} only -- \code{raw/} is left
#' untouched, per the immutability rule. Aliases (e.g.
#' \code{[[2026-04-30-corteza|corteza]]}) are preserved.
#'
#' Run with \code{dry_run = TRUE} (the default) first and review the
#' planned operations before committing.
#'
#' @param vault Path to the vault.
#' @param dry_run If \code{TRUE} (default), prints planned moves and link
#'   rewrites without touching files. Set \code{FALSE} to apply.
#' @param drop_old If \code{TRUE} (default), removes superseded dated
#'   briefings after the chosen file is moved. If \code{FALSE}, leaves
#'   them in place.
#' @param rename_map Named character vector mapping legacy slug stems to
#'   current repo names. Defaults handle the \code{llamaR -> corteza}
#'   rename. Pass an extended map if your vault carries other renames.
#' @return Invisibly, a data.frame with columns \code{file},
#'   \code{repo}, \code{artifact}, \code{action}, \code{destination}.
#' @export
migrate_briefings_to_repos <- function(vault = default_vault(),
                                       dry_run = TRUE, drop_old = TRUE,
                                       rename_map = c(llamaR = "corteza", llamar = "corteza")) {
    vault <- normalizePath(vault, mustWork = TRUE)
    briefings_dir <- file.path(vault, "raw", "briefings")
    if (!dir.exists(briefings_dir)) {
        message("No raw/briefings/ directory; nothing to migrate.")
        return(invisible(empty_migration_plan()))
    }

    files <- list.files(briefings_dir, pattern = "\\.md$", full.names = TRUE)
    if (length(files) == 0L) {
        message("raw/briefings/ is empty; nothing to migrate.")
        return(invisible(empty_migration_plan()))
    }

    plan <- classify_briefings(files, rename_map)
    plan <- pick_newest_per_artifact(plan)

    if (dry_run) {
        print_migration_plan(plan, drop_old)
        return(invisible(plan))
    }

    apply_migration_plan(plan, vault, drop_old)
    update_index(vault)
    log_entry(sprintf("Migrated %d briefing(s) to raw/repos/",
                      sum(plan$action == "move")),
              operation = "migrate", vault = vault)
    vault_commit("Migrate briefings to repos layout", vault = vault)
    invisible(plan)
}

#' @noRd
empty_migration_plan <- function() {
    data.frame(file = character(0L), repo = character(0L),
               artifact = character(0L), action = character(0L),
               destination = character(0L), date = character(0L),
               stringsAsFactors = FALSE)
}

#' Classify each briefing file by (repo, artifact)
#' @noRd
classify_briefings <- function(files, rename_map) {
    n <- length(files)
    out <- data.frame(file = files,
                      repo = character(n), artifact = character(n),
                      date = character(n),
                      stringsAsFactors = FALSE)
    for (i in seq_len(n)) {
        fp <- files[i]
        fm <- parse_frontmatter(fp)
        slug <- name_from_path(fp)

        # Filename like 2026-04-13-ast-llamar.md or 2026-04-30-corteza.md.
        # Strip leading YYYY-MM-DD-, trailing -N (dated regen suffix).
        date_match <- regmatches(slug, regexpr("^\\d{4}-\\d{2}-\\d{2}", slug))
        if (length(date_match)) {
            date_str <- date_match[[1L]]
        } else {
            date_str <- (fm$date %||% "")
        }

        stem <- sub("^\\d{4}-\\d{2}-\\d{2}-", "", slug)
        stem <- sub("-\\d+$", "", stem)

        is_ast <- startsWith(stem, "ast-")
        if (is_ast) {
            stem <- sub("^ast-", "", stem)
        }

        # Frontmatter source can override stem-based naming.
        src <- fm$source %||% stem
        src_clean <- sub("^ast-", "", src)
        repo <- src_clean
        if (repo %in% names(rename_map)) {
            repo <- rename_map[[repo]]
        } else if (tolower(repo) %in% tolower(names(rename_map))) {
            ix <- match(tolower(repo), tolower(names(rename_map)))
            repo <- rename_map[[ix]]
        }

        out$repo[i] <- repo
        if (is_ast) {
            out$artifact[i] <- "ast"
        } else {
            out$artifact[i] <- "briefing"
        }
        out$date[i] <- date_str
    }
    out
}

#' Keep newest file per (repo, artifact); mark others for drop
#' @noRd
pick_newest_per_artifact <- function(plan) {
    plan$action <- "drop"
    plan$destination <- ""
    keys <- paste(plan$repo, plan$artifact, sep = "::")
    for (k in unique(keys)) {
        ix <- which(keys == k)
        if (length(ix) == 0L) {
            next
        }
        # Newest by frontmatter/filename date string (lexicographic on YYYY-MM-DD).
        winner <- ix[order(plan$date[ix], decreasing = TRUE)][1L]
        plan$action[winner] <- "move"
    }
    movers <- plan$action == "move"
    plan$destination[movers] <- file.path("raw", "repos",
        plan$repo[movers],
        paste0(plan$artifact[movers], ".md"))
    plan
}

#' @noRd
print_migration_plan <- function(plan, drop_old) {
    n_move <- sum(plan$action == "move")
    n_drop <- sum(plan$action == "drop")
    cat(sprintf("Migration plan: %d move(s), %d drop(s)%s\n\n",
                n_move, n_drop,
            if (drop_old) "" else " [drop_old=FALSE: drops kept in place]"))
    cat("Moves:\n")
    movers <- plan[plan$action == "move",, drop = FALSE]
    if (nrow(movers) == 0L) {
        cat("  (none)\n")
    }
    for (i in seq_len(nrow(movers))) {
        cat(sprintf("  %s -> %s\n",
                    sub(".*/raw/", "raw/", movers$file[i]),
                    movers$destination[i]))
    }
    if (drop_old && n_drop > 0L) {
        cat("\nDrops (superseded):\n")
        drops <- plan[plan$action == "drop",, drop = FALSE]
        for (i in seq_len(nrow(drops))) {
            cat(sprintf("  %s\n", sub(".*/raw/", "raw/", drops$file[i])))
        }
    }
    cat("\nRun with dry_run = FALSE to apply.\n")
}

#' @noRd
apply_migration_plan <- function(plan, vault, drop_old) {
    movers <- plan[plan$action == "move",, drop = FALSE]
    drops <- plan[plan$action == "drop",, drop = FALSE]

    rename_pairs <- character(0L)

    for (i in seq_len(nrow(movers))) {
        src <- movers$file[i]
        dst <- file.path(vault, movers$destination[i])
        dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
        ok <- file.copy(src, dst, overwrite = TRUE)
        if (!ok) {
            warning("Failed to copy ", src, " -> ", dst)
            next
        }
        rewrite_artifact_type(dst, movers$artifact[i], movers$repo[i])
        old_slug <- name_from_path(src)
        new_slug <- paste0(movers$repo[i], "/", movers$artifact[i])
        rename_pairs <- c(rename_pairs, setNames(new_slug, old_slug))
        file.remove(src)
    }

    if (drop_old) {
        for (i in seq_len(nrow(drops))) {
            file.remove(drops$file[i])
            rename_pairs <- c(rename_pairs,
                              setNames("", name_from_path(drops$file[i])))
        }
    }

    rewrite_wikilinks_in_wiki(vault, rename_pairs)
}

#' Update the type field in frontmatter of a moved artifact
#' @noRd
rewrite_artifact_type <- function(path, artifact, repo) {
    lines <- readLines(path, warn = FALSE)
    if (length(lines) < 2L || trimws(lines[1L]) != "---") {
        return(invisible())
    }
    end <- which(trimws(lines[-1L]) == "---")[1L]
    if (is.na(end)) {
        return(invisible())
    }
    end <- end + 1L
    fm_lines <- lines[2L:(end - 1L)]
    new_type <- paste0("repo-", artifact)
    if (any(grepl("^type:", fm_lines))) {
        fm_lines <- sub("^type:.*", paste0("type: ", new_type), fm_lines)
    } else {
        fm_lines <- c(fm_lines, paste0("type: ", new_type))
    }
    title_idx <- grep("^title:", fm_lines)
    if (length(title_idx) == 1L) {
        fm_lines[title_idx] <- sprintf("title: '%s @ migrated (%s)'",
                                       repo, artifact)
    }
    writeLines(c(lines[1L], fm_lines, lines[end:length(lines)]), path)
}

#' Rewrite [[old_slug]] -> [[new_slug]] across wiki/*.md
#'
#' Drops are written with empty new_slug and are surfaced as a warning
#' rather than rewritten (so a human can decide what to do with stale
#' links).
#'
#' @noRd
rewrite_wikilinks_in_wiki <- function(vault, rename_pairs) {
    if (length(rename_pairs) == 0L) {
        return(invisible())
    }
    wiki_dir <- file.path(vault, "wiki")
    if (!dir.exists(wiki_dir)) {
        return(invisible())
    }

    files <- list.files(wiki_dir, pattern = "\\.md$",
                        recursive = TRUE, full.names = TRUE)
    moves <- rename_pairs[nzchar(rename_pairs)]
    drops <- names(rename_pairs)[!nzchar(rename_pairs)]

    stale_hits <- character(0L)
    for (fp in files) {
        text <- paste(readLines(fp, warn = FALSE), collapse = "\n")
        changed <- FALSE
        for (i in seq_along(moves)) {
            old_slug <- names(moves)[i]
            new_slug <- moves[[i]]
            pat <- sprintf("\\[\\[\\Q%s\\E(\\|[^\\]]+)?\\]\\]", old_slug)
            replacement <- sprintf("[[%s\\1]]", new_slug)
            new_text <- gsub(pat, replacement, text, perl = TRUE)
            if (!identical(new_text, text)) {
                text <- new_text
                changed <- TRUE
            }
        }
        for (slug in drops) {
            pat <- sprintf("\\[\\[\\Q%s\\E(\\|[^\\]]+)?\\]\\]", slug)
            if (grepl(pat, text, perl = TRUE)) {
                stale_hits <- c(stale_hits,
                                sprintf("%s in %s", slug, basename(fp)))
            }
        }
        if (changed) {
            writeLines(strsplit(text, "\n", fixed = TRUE)[[1L]], fp)
        }
    }

    if (length(stale_hits) > 0L) {
        warning("Wikilinks point at dropped briefings (left as-is for ",
                "manual review):\n  ",
                paste(stale_hits, collapse = "\n  "), call. = FALSE)
    }
    invisible()
}

