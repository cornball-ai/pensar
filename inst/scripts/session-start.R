#!/usr/bin/env Rscript
# pensar - ingest saber briefing into vault at session start
# Runs after saber's SessionStart hook. Reads the cached briefing
# and archives it in the pensar vault.

tryCatch({
    session_cwd <- getwd()

    # Detect project from git root
    root <- tryCatch(
        trimws(system2("git", c("-C", session_cwd, "rev-parse",
                                "--show-toplevel"),
                        stdout = TRUE, stderr = FALSE)[[1L]]),
        error = function(e) ""
    )
    if (nchar(root) == 0L) return(invisible())
    project <- basename(root)

    # Find saber's cached briefing
    brief_path <- file.path(tools::R_user_dir("saber", "cache"),
                            "briefs", paste0(project, ".md"))
    if (!file.exists(brief_path)) return(invisible())

    # Auto-init vault if needed
    vault <- tools::R_user_dir("pensar", "data")
    if (!file.exists(file.path(vault, "schema.md"))) {
        pensar::init_vault(vault)
    }

    # Ingest the briefing
    content <- readLines(brief_path, warn = FALSE)
    pensar::ingest(content, type = "briefings", source = project,
                   title = paste0("Briefing: ", project),
                   vault = vault)
},
error = function(e) invisible(NULL))
