#!/usr/bin/env Rscript
# pensar - ingest saber briefing into vault at session start.
# Runs after saber's SessionStart hook. Delegates to
# pensar::ingest_briefing(), which uses the user-configured vault
# (PENSAR_VAULT, walk-up schema.md, or options("pensar.vault")).
# Bails out silently if no vault is configured -- per CRAN policy
# pensar never writes to a default home-filespace location, so a
# session-start hook must not auto-create one either.

tryCatch({
    pensar::ingest_briefing()
}, error = function(e) invisible(NULL))
