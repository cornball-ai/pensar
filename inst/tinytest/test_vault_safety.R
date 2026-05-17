# Tests for the init_vault() safety gate (PR 1).
# Covers vault_is_pensar_owned() ownership detection plus the adopt /
# commit / force parameter matrix on init_vault().

library(pensar)

# --- helpers ---
make_dir <- function(files = NULL, git = FALSE, commit_initial = FALSE) {
    d <- file.path(tempdir(),
                   paste0("vault-safety-", format(Sys.time(), "%H%M%OS3"),
                          "-", sample.int(1e6, 1L)))
    dir.create(d, recursive = TRUE)
    if (!is.null(files)) {
        for (f in names(files)) {
            fp <- file.path(d, f)
            dir.create(dirname(fp), recursive = TRUE, showWarnings = FALSE)
            writeLines(files[[f]], fp)
        }
    }
    if (isTRUE(git)) {
        system2("git", c("-C", d, "init", "-q"),
                stdout = FALSE, stderr = FALSE)
        if (isTRUE(commit_initial) && !is.null(files)) {
            system2("git", c("-C", d, "add", "-A"),
                    stdout = FALSE, stderr = FALSE)
            system2("git",
                    c("-C", d, "-c", "user.email=test@example.invalid",
                      "-c", "user.name=test", "commit", "-m", "initial",
                      "-q"),
                    stdout = FALSE, stderr = FALSE)
        }
    }
    d
}
has_init_commit <- function(d) {
    log_out <- suppressWarnings(system2("git",
                                        c("-C", d, "log", "--oneline"),
                                        stdout = TRUE, stderr = FALSE))
    any(grepl("Vault initialized", log_out))
}

# --- 1. Empty dir → scaffolds, no commit (no .git) ---
d1 <- make_dir()
v <- init_vault(d1, rproj = FALSE, agent_instructions = FALSE)
expect_equal(v, normalizePath(d1))
expect_true(file.exists(file.path(d1, "schema.md")))
expect_true(dir.exists(file.path(d1, "raw", "articles")))
unlink(d1, recursive = TRUE)

# --- 2. Empty dir with .git/ (no commits yet) → scaffolds and commits ---
d2 <- make_dir(git = TRUE)
init_vault(d2, rproj = FALSE, agent_instructions = FALSE)
expect_true(file.exists(file.path(d2, "schema.md")))
expect_true(has_init_commit(d2))
unlink(d2, recursive = TRUE)

# --- 3. Foreign git repo → refuse, no writes, no commit ---
d3 <- make_dir(files = list("Notes/foo.md" = "foreign content"),
               git = TRUE, commit_initial = TRUE)
result <- init_vault(d3, rproj = FALSE, agent_instructions = FALSE)
expect_null(result)
expect_false(file.exists(file.path(d3, "schema.md")))
expect_false(dir.exists(file.path(d3, "raw")))
expect_false(has_init_commit(d3))
unlink(d3, recursive = TRUE)

# --- 4. Foreign git repo, force = TRUE → scaffolds, no commit ---
d4 <- make_dir(files = list("Notes/foo.md" = "foreign content"),
               git = TRUE, commit_initial = TRUE)
init_vault(d4, rproj = FALSE, agent_instructions = FALSE, force = TRUE)
expect_true(file.exists(file.path(d4, "schema.md")))
expect_false(has_init_commit(d4))
unlink(d4, recursive = TRUE)

# --- 5. Foreign git repo, force = TRUE + commit = TRUE → scaffolds + commits ---
d5 <- make_dir(files = list("Notes/foo.md" = "foreign content"),
               git = TRUE, commit_initial = TRUE)
init_vault(d5, rproj = FALSE, agent_instructions = FALSE, force = TRUE,
           commit = TRUE)
expect_true(file.exists(file.path(d5, "schema.md")))
expect_true(has_init_commit(d5))
unlink(d5, recursive = TRUE)

# --- 6. adopt = TRUE → no scaffolding even with foreign content ---
d6 <- make_dir(files = list("Notes/foo.md" = "foreign content"))
init_vault(d6, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
expect_false(file.exists(file.path(d6, "schema.md")))
unlink(d6, recursive = TRUE)

# --- 7. Existing pensar vault re-init → early return, unchanged ---
d7 <- make_dir()
init_vault(d7, rproj = FALSE, agent_instructions = FALSE)
schema_before <- readLines(file.path(d7, "schema.md"))
init_vault(d7, rproj = FALSE, agent_instructions = FALSE)
schema_after <- readLines(file.path(d7, "schema.md"))
expect_identical(schema_before, schema_after)
unlink(d7, recursive = TRUE)

# --- 8. commit = FALSE in pensar-owned dir with .git/ → no commit ---
d8 <- make_dir(git = TRUE)
init_vault(d8, rproj = FALSE, agent_instructions = FALSE, commit = FALSE)
expect_true(file.exists(file.path(d8, "schema.md")))
expect_false(has_init_commit(d8))
unlink(d8, recursive = TRUE)

# --- 9. Dir with pensar-shape README.md (no git) → still treated as owned ---
d9 <- make_dir(files = list("README.md" = "my notes"))
init_vault(d9, rproj = FALSE, agent_instructions = FALSE)
expect_true(file.exists(file.path(d9, "schema.md")))
unlink(d9, recursive = TRUE)

# --- 10. vault_is_pensar_owned() internal: empty dir → TRUE ---
d10 <- make_dir()
expect_true(pensar:::vault_is_pensar_owned(d10))
unlink(d10, recursive = TRUE)

# --- 11. vault_is_pensar_owned() internal: foreign file → FALSE ---
d11 <- make_dir(files = list("random.txt" = "foreign"))
expect_false(pensar:::vault_is_pensar_owned(d11))
unlink(d11, recursive = TRUE)

# --- 12. Foreign dir with top-level wiki/ but no schema.md → not owned ---
d12 <- make_dir(files = list("wiki/Foo.md" = "foreign wiki content"))
expect_false(pensar:::vault_is_pensar_owned(d12))
result <- init_vault(d12, rproj = FALSE, agent_instructions = FALSE)
expect_null(result)
expect_false(file.exists(file.path(d12, "schema.md")))
expect_true(file.exists(file.path(d12, "wiki", "Foo.md")))
unlink(d12, recursive = TRUE)

# --- 13. Foreign dir with top-level raw/ but no schema.md → not owned ---
d13 <- make_dir(files = list("raw/articles/foo.md" = "foreign raw content"))
expect_false(pensar:::vault_is_pensar_owned(d13))
result <- init_vault(d13, rproj = FALSE, agent_instructions = FALSE)
expect_null(result)
expect_false(file.exists(file.path(d13, "schema.md")))
expect_true(file.exists(file.path(d13, "raw", "articles", "foo.md")))
unlink(d13, recursive = TRUE)

# --- 14. Foreign git repo with tracked wiki/ → not owned ---
d14 <- make_dir(files = list("wiki/Foo.md" = "foreign wiki content"),
                git = TRUE, commit_initial = TRUE)
expect_false(pensar:::vault_is_pensar_owned(d14))
unlink(d14, recursive = TRUE)
