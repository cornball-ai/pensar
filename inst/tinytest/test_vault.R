# Tests for vault.R (init_vault)

library(pensar)

# --- init_vault creates directory structure ---
tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
v <- init_vault(tmp)
expect_equal(v, normalizePath(tmp))
expect_true(dir.exists(file.path(tmp, "raw", "articles")))
expect_true(dir.exists(file.path(tmp, "raw", "chats")))
expect_true(dir.exists(file.path(tmp, "raw", "briefings")))
expect_true(dir.exists(file.path(tmp, "raw", "matrix")))
expect_true(dir.exists(file.path(tmp, "wiki")))
expect_true(file.exists(file.path(tmp, "schema.md")))
expect_true(file.exists(file.path(tmp, "index.md")))
expect_true(file.exists(file.path(tmp, "log.md")))

# --- schema.md has expected content ---
schema <- readLines(file.path(tmp, "schema.md"))
expect_true(any(grepl("Vault Schema", schema)))
expect_true(any(grepl("wikilinks", schema)))

# --- log.md records initialization ---
log <- readLines(file.path(tmp, "log.md"))
expect_true(any(grepl("init", log)))

# --- idempotent: re-init does not error ---
v2 <- init_vault(tmp)
expect_equal(v2, v)

# --- Rproj is written by default ---
expect_true(file.exists(file.path(tmp, paste0(basename(tmp), ".Rproj"))))

# --- Agent instructions written by default ---
expect_true(file.exists(file.path(tmp, "CLAUDE.md")))
expect_true(file.exists(file.path(tmp, "AGENTS.md")))
# Same content
expect_equal(readLines(file.path(tmp, "CLAUDE.md")),
             readLines(file.path(tmp, "AGENTS.md")))

unlink(tmp, recursive = TRUE)

# --- rproj = FALSE skips the Rproj file ---
tmp2 <- file.path(tempdir(),
                  paste0("vault-no-rproj-", format(Sys.time(), "%H%M%S")))
init_vault(tmp2, rproj = FALSE, agent_instructions = FALSE)
rproj_files <- list.files(tmp2, pattern = "\\.Rproj$")
expect_equal(length(rproj_files), 0L)
expect_false(file.exists(file.path(tmp2, "CLAUDE.md")))
expect_false(file.exists(file.path(tmp2, "AGENTS.md")))
unlink(tmp2, recursive = TRUE)
