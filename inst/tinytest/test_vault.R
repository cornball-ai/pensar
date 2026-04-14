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

unlink(tmp, recursive = TRUE)

# --- rproj = FALSE skips the Rproj file ---
tmp2 <- file.path(tempdir(),
                  paste0("vault-no-rproj-", format(Sys.time(), "%H%M%S")))
init_vault(tmp2, rproj = FALSE)
rproj_files <- list.files(tmp2, pattern = "\\.Rproj$")
expect_equal(length(rproj_files), 0L)
unlink(tmp2, recursive = TRUE)
