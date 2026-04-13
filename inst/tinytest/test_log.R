# Tests for log.R (log_entry)

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# --- Append entries ---
log_entry("First operation", operation = "test", vault = tmp)
log_entry("Second operation", operation = "manual", vault = tmp)

log <- readLines(file.path(tmp, "log.md"))
expect_true(sum(grepl("\\[test\\]", log)) >= 1L)
expect_true(sum(grepl("\\[manual\\]", log)) >= 1L)

# --- Entries contain timestamps ---
expect_true(all(grepl("\\d{4}-\\d{2}-\\d{2}", log[grepl("\\[test\\]", log)])))

unlink(tmp, recursive = TRUE)
