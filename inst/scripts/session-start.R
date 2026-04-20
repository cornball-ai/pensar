#!/usr/bin/env Rscript
# pensar - ingest saber briefing into vault at session start.
# Runs after saber's SessionStart hook. Delegates to
# pensar::ingest_briefing(), which handles project inference,
# vault init, and the saber call.

tryCatch({
    vault <- tools::R_user_dir("pensar", "data")
    if (!file.exists(file.path(vault, "schema.md"))) {
        pensar::init_vault(vault)
    }
    pensar::ingest_briefing(vault = vault)
}, error = function(e) invisible(NULL))
