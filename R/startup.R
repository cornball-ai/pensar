#' @title Startup: discover project metadata and build unified ontology
#' @description Scan home directory for project metadata, auto-register
#'   projects as terms, and infer relations from DESCRIPTION files.

#' Build a unified ontology from project metadata files
#'
#' Scans for CLAUDE.md, AGENT.md, fyi.md, README.md, and DESCRIPTION files
#' across project directories. Also discovers Claude Code memory files from
#' \code{~/.claude/projects/*/memory/*.md}. Every project with recognized
#' metadata becomes a term automatically. R package dependencies from
#' DESCRIPTION files generate \code{uses} relations. Central annotation
#' files from \code{annotations_dir} are parsed for typed links.
#'
#' Files are read in place. The index (three TSV files) is written to
#' \code{cache_dir}.
#'
#' @param scan_dir Directory to scan for projects (default: home directory).
#' @param cache_dir Directory for the ontology index and annotations
#'   (default: \code{tools::R_user_dir("pensar", "cache")}).
#' @param claude_dir Directory where Claude Code reads its global CLAUDE.md.
#'   Used only to check if the instructions file needs updating. Set to NULL
#'   to suppress the copy hint. Nothing is written to this directory.
#' @param memory_dir Directory containing Claude Code project memory files
#'   (default: \code{~/.claude/projects}). Set to NULL to skip.
#' @return An \code{pensar_status} object (invisibly).
#' @export
startup <- function(scan_dir = path.expand("~"),
                    cache_dir = tools::R_user_dir("pensar", "cache"),
                    claude_dir = file.path(path.expand("~"), ".cache", "claude"),
                    memory_dir = file.path(path.expand("~"), ".claude", "projects")) {
    scan_dir <- normalizePath(scan_dir, mustWork = TRUE)
    annotations_dir <- file.path(cache_dir, "annotations")
    index_path <- file.path(cache_dir, "index")
    dir.create(index_path, recursive = TRUE, showWarnings = FALSE)

    # Discover project directories
    project_dirs <- list.dirs(scan_dir, recursive = FALSE, full.names = TRUE)

    # Which files to look for
    md_targets <- c("CLAUDE.md", "AGENT.md", "fyi.md", "README.md")

    # Gather metadata files and identify projects
    found_md <- character(0L)
    found_desc <- character(0L)
    project_names <- character(0L)

    for (d in project_dirs) {
        has_metadata <- FALSE
        for (t in md_targets) {
            fp <- file.path(d, t)
            if (file.exists(fp)) {
                found_md <- c(found_md, fp)
                has_metadata <- TRUE
            }
        }
        desc_fp <- file.path(d, "DESCRIPTION")
        if (file.exists(desc_fp)) {
            found_desc <- c(found_desc, desc_fp)
            has_metadata <- TRUE
        }
        if (has_metadata) {
            project_names <- c(project_names, basename(d))
        }
    }

    # Discover Claude Code memory files (~/.claude/projects/*/memory/*.md)
    found_memories <- character(0L)
    if (!is.null(memory_dir) && dir.exists(memory_dir)) {
        mem_dirs <- list.dirs(memory_dir, recursive = FALSE, full.names = TRUE)
        for (md in mem_dirs) {
            mem_path <- file.path(md, "memory")
            if (dir.exists(mem_path)) {
                mfiles <- list.files(mem_path, pattern = "\\.md$",
                                     full.names = TRUE)
                if (length(mfiles) > 0L) {
                    found_memories <- c(found_memories, mfiles)
                }
            }
        }
    }

    # Discover annotation files
    found_annotations <- character(0L)
    if (dir.exists(annotations_dir)) {
        found_annotations <- list.files(annotations_dir, pattern = "\\.md$",
                                        full.names = TRUE)
    }

    if (length(project_names) == 0L) {
        message("No project metadata found in ", scan_dir)
        return(invisible(NULL))
    }

    message(sprintf("Found %d project(s) (%d markdown, %d DESCRIPTION, %d memory files)",
                    length(project_names), length(found_md),
                    length(found_desc), length(found_memories)))

    # Build index in memory
    idx <- empty_index()

    # Parse typed links from project markdown files
    all_md <- c(found_md, found_memories, found_annotations)
    for (fp in all_md) {
        links <- parse_typed_links(fp)
        if (nrow(links) == 0L) {
            next
        }

        # Derive subject from filename context
        subject <- startup_subject(fp, scan_dir, memory_dir)
        if (is.na(subject)) {
            next
        }

        new_rels <- data.frame(subject_id = rep(subject, nrow(links)),
                               relation_type = links$relation_type,
                               object_id = links$target, confirmed = 1L,
                               source = "inline", stringsAsFactors = FALSE)
        idx$relations <- rbind(idx$relations, new_rels)
    }

    # Auto-register every project as a term
    for (pname in project_names) {
        idx$terms <- rbind(idx$terms,
                           data.frame(id = pname, name = pname, filepath = NA_character_,
                                      aliases = "", promoted = 0L, updated_at = now_ts(),
                                      stringsAsFactors = FALSE))
    }

    # Parse DESCRIPTION files for dependency relations
    n_deps <- 0L
    dep_fields <- c(depends = "depends", imports = "imports",
                    suggests = "suggests", links_to = "links_to")
    for (desc_fp in found_desc) {
        info <- parse_description(desc_fp)
        if (is.na(info$package)) {
            next
        }
        pname <- basename(dirname(desc_fp))

        for (i in seq_along(dep_fields)) {
            field <- names(dep_fields)[i]
            rel_type <- dep_fields[i]
            for (dep in info[[field]]) {
                idx$relations <- rbind(idx$relations,
                                       data.frame(subject_id = pname, relation_type = rel_type,
                        object_id = dep, confirmed = 1L,
                        source = "auto", stringsAsFactors = FALSE))
                if (!dep %in% idx$terms$id) {
                    idx$terms <- rbind(idx$terms,
                                       data.frame(id = dep, name = dep,
                            filepath = NA_character_, aliases = "",
                            promoted = 0L, updated_at = now_ts(),
                            stringsAsFactors = FALSE))
                }
                n_deps <- n_deps + 1L
            }
        }
    }

    # Ensure relation targets exist as terms
    missing <- setdiff(idx$relations$object_id, idx$terms$id)
    if (length(missing) > 0L) {
        stubs <- data.frame(id = missing, name = missing,
                            filepath = NA_character_, aliases = "",
                            promoted = 0L, updated_at = now_ts(),
                            stringsAsFactors = FALSE)
        idx$terms <- rbind(idx$terms, stubs)
    }

    # Deduplicate relations
    if (nrow(idx$relations) > 0L) {
        key <- paste(idx$relations$subject_id, idx$relations$relation_type,
                     idx$relations$object_id, sep = "|")
        idx$relations <- idx$relations[!duplicated(key),, drop = FALSE]
    }

    save_index(idx, index_path)

    # Generate Claude Code instructions (if informR is installed)
    if (requireNamespace("informR", quietly = TRUE)) {
        instructions_file <- file.path(cache_dir, "instructions.md")
        informR::write_instructions(instructions_file, index_path)

        claude_target <- file.path(if (!is.null(claude_dir)) {
                claude_dir
            } else {
                file.path(path.expand("~"), ".cache", "claude")
            }, "CLAUDE.md")
        if (!file.exists(claude_target) ||
            !identical(readLines(instructions_file, warn = FALSE),
                       readLines(claude_target, warn = FALSE))) {
            message("Instructions generated at: ", instructions_file)
            message("To install: cp '", instructions_file, "' '", claude_target,
                    "'")
        }
    }

    message(sprintf("Indexed %d project(s), %d dependency relation(s).",
                    length(project_names), n_deps))

    invisible(status(vault_path = index_path))
}

#' Derive the subject term from a file path
#'
#' For project files like ~/whisper/CLAUDE.md, the subject is "whisper".
#' For memory files, extract from the encoded directory name.
#' For annotation files, return NA (annotations carry their own subjects
#' via typed links).
#' @noRd
startup_subject <- function(fp, scan_dir, memory_dir) {
    # Annotation files: subjects are in the typed links themselves
    if (grepl("annotations", dirname(fp), fixed = TRUE)) {
        return(name_from_path(fp))
    }

    # Memory files: ~/.claude/projects/-home-troy-whisper/memory/MEMORY.md
    if (!is.null(memory_dir) && startsWith(fp, memory_dir)) {
        mem_dir <- dirname(fp)
        proj_dir <- dirname(mem_dir)
        proj_encoded <- basename(proj_dir)
        return(sub("^.*-home-[^-]+-", "", proj_encoded))
    }

    # Project files: ~/whisper/CLAUDE.md -> "whisper"
    basename(dirname(fp))
}
