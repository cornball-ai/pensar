# Tests for read-only adopt mode (PR 3).
#
# Covers init_vault(adopt = TRUE) scaffolding, vault_is_adopted()
# detection, registry-driven update_index() and status() for adopted
# vaults, and ingest()'s read-only refusal.

library(pensar)

# Copy the bundled fixture vault to a temp dir so we can write
# schema.md / log.md / index.md into it during the test.
fixture_src <- system.file("tinytest/fixtures/adopt/obsidian-mini",
                           package = "pensar")
expect_true(nzchar(fixture_src))
expect_true(dir.exists(fixture_src))

setup_fixture <- function() {
    dest <- file.path(tempdir(),
                      paste0("adopt-", format(Sys.time(), "%H%M%OS3"),
                             "-", sample.int(1e6, 1L)))
    dir.create(dest, recursive = TRUE)
    file.copy(list.files(fixture_src, full.names = TRUE), dest,
              recursive = TRUE)
    dest
}

# --- 1. init_vault(adopt = TRUE) doesn't scaffold raw/ or wiki/ ---
d1 <- setup_fixture()
init_vault(d1, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
expect_true(file.exists(file.path(d1, "schema.md")))
expect_false(dir.exists(file.path(d1, "raw")))
expect_false(dir.exists(file.path(d1, "wiki")))
expect_true(pensar:::vault_is_adopted(d1))
unlink(d1, recursive = TRUE)

# --- 2. schema.md carries adopted: true frontmatter ---
d2 <- setup_fixture()
init_vault(d2, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
schema_lines <- readLines(file.path(d2, "schema.md"))
expect_true(any(grepl("^adopted: true", schema_lines)))
unlink(d2, recursive = TRUE)

# --- 3. update_index() lists pages by frontmatter type ---
d3 <- setup_fixture()
init_vault(d3, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
update_index(d3)
ix <- readLines(file.path(d3, "index.md"))
expect_true(any(grepl("## concept \\(2\\)", ix)))
expect_true(any(grepl("## journal \\(2\\)", ix)))
expect_true(any(grepl("## clipping \\(2\\)", ix)))
expect_true(any(grepl("\\[\\[Concept-A\\]\\]", ix)))
unlink(d3, recursive = TRUE)

# --- 4. status() reports counts by frontmatter type ---
d4 <- setup_fixture()
init_vault(d4, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
st <- status(d4)
expect_true(isTRUE(st$adopted))
expect_equal(st$total, 6L)
expect_equal(unname(st$by_type[["concept"]]), 2L)
expect_equal(unname(st$by_type[["journal"]]), 2L)
expect_equal(unname(st$by_type[["clipping"]]), 2L)
# Print should mention adopted and total
captured <- capture.output(print(st))
expect_true(any(grepl("\\[adopted\\]", captured)))
expect_true(any(grepl("Total", captured)))
unlink(d4, recursive = TRUE)

# --- 5. ingest() refuses in adopt mode without force ---
d5 <- setup_fixture()
init_vault(d5, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
err <- tryCatch(ingest("body", "articles", "demo", vault = d5),
                error = function(e) conditionMessage(e))
expect_true(grepl("read-only", err))
expect_false(dir.exists(file.path(d5, "raw", "articles")))
unlink(d5, recursive = TRUE)

# --- 6. ingest(..., force = TRUE) writes into the adopted vault ---
d6 <- setup_fixture()
init_vault(d6, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
fp <- ingest("body", "articles", "demo", vault = d6, force = TRUE)
expect_true(file.exists(fp))
expect_true(dir.exists(file.path(d6, "raw", "articles")))
unlink(d6, recursive = TRUE)

# --- 7. init_vault(adopt = TRUE) does not auto-commit ---
# Set up the fixture as a git repo before adopt
d7 <- setup_fixture()
system2("git", c("-C", d7, "init", "-q"), stdout = FALSE, stderr = FALSE)
system2("git", c("-C", d7, "add", "-A"), stdout = FALSE, stderr = FALSE)
system2("git",
        c("-C", d7, "-c", "user.email=t@e.com", "-c", "user.name=t",
          "commit", "-m", "initial", "-q"),
        stdout = FALSE, stderr = FALSE)
init_vault(d7, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
log_out <- suppressWarnings(system2("git",
                                    c("-C", d7, "log", "--oneline"),
                                    stdout = TRUE, stderr = FALSE))
expect_false(any(grepl("Vault initialized", log_out)))
expect_false(any(grepl("Vault adopted", log_out)))
unlink(d7, recursive = TRUE)

# --- 8. Native vault behavior unchanged: status/update_index still
# use hard-coded categories ---
d8 <- file.path(tempdir(),
                paste0("native-", format(Sys.time(), "%H%M%OS3")))
init_vault(d8, rproj = FALSE, agent_instructions = FALSE)
st <- status(d8)
expect_false(isTRUE(st$adopted))
expect_true("raw_articles" %in% names(st))
update_index(d8)
ix <- readLines(file.path(d8, "index.md"))
expect_true(any(grepl("## Raw: Articles", ix)))
expect_true(any(grepl("## Wiki", ix)))
unlink(d8, recursive = TRUE)

# --- 9. vault_is_adopted() returns FALSE when schema.md is missing ---
d9 <- file.path(tempdir(),
                paste0("noschema-", format(Sys.time(), "%H%M%OS3")))
dir.create(d9)
expect_false(pensar:::vault_is_adopted(d9))
unlink(d9, recursive = TRUE)

# --- 10. Frontmatter `category` falls back to type for adopted vault ---
d10 <- file.path(tempdir(),
                 paste0("adopt-cat-",
                        format(Sys.time(), "%H%M%OS3")))
dir.create(d10, recursive = TRUE)
notes_dir <- file.path(d10, "Notes")
dir.create(notes_dir, recursive = TRUE)
writeLines(c("---", "title: Foo", "category: concept", "---", "",
             "# Foo"), file.path(notes_dir, "Foo.md"))
init_vault(d10, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
update_index(d10)
ix <- readLines(file.path(d10, "index.md"))
expect_true(any(grepl("^## concept ", ix)))
st <- status(d10)
expect_equal(unname(st$by_type[["concept"]]), 1L)
unlink(d10, recursive = TRUE)

# --- 11. init_vault(adopt = TRUE) on a foreign schema.md refuses ---
d11 <- file.path(tempdir(),
                 paste0("adopt-foreign-schema-",
                        format(Sys.time(), "%H%M%OS3")))
dir.create(d11, recursive = TRUE)
writeLines(c("---", "title: pre-existing schema", "type: schema",
             "---", "", "# Foreign"),
           file.path(d11, "schema.md"))
result <- init_vault(d11, rproj = FALSE, agent_instructions = FALSE,
                     adopt = TRUE)
expect_null(result)
expect_false(pensar:::vault_is_adopted(d11))
# Schema.md untouched
expect_identical(readLines(file.path(d11, "schema.md"))[2L],
                 "title: pre-existing schema")
unlink(d11, recursive = TRUE)

# --- 12. init_vault(adopt = TRUE) on an already-adopted vault returns
#    early with a message and doesn't disturb anything ---
d12 <- file.path(tempdir(),
                 paste0("adopt-re-adopt-",
                        format(Sys.time(), "%H%M%OS3")))
init_vault(d12, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
schema_before <- readLines(file.path(d12, "schema.md"))
log_before <- readLines(file.path(d12, "log.md"))
init_vault(d12, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
expect_identical(readLines(file.path(d12, "schema.md")), schema_before)
expect_identical(readLines(file.path(d12, "log.md")), log_before)
unlink(d12, recursive = TRUE)

# --- 13. init_vault(adopt = TRUE) does not append to a pre-existing
#    log.md (leaves user content untouched) ---
d13 <- file.path(tempdir(),
                 paste0("adopt-preexist-log-",
                        format(Sys.time(), "%H%M%OS3")))
dir.create(d13, recursive = TRUE)
my_log <- c("# My personal log", "", "- 2026-05-17 caught a fish")
writeLines(my_log, file.path(d13, "log.md"))
init_vault(d13, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
expect_identical(readLines(file.path(d13, "log.md")), my_log)
unlink(d13, recursive = TRUE)

# --- 14. Adopted index uses path-style links when basenames collide ---
d14 <- file.path(tempdir(),
                 paste0("adopt-idx-amb-",
                        format(Sys.time(), "%H%M%OS3")))
dir.create(d14, recursive = TRUE)
dir.create(file.path(d14, "A"), recursive = TRUE)
dir.create(file.path(d14, "B"), recursive = TRUE)
writeLines(c("---", "title: Foo A", "type: concept", "---"),
           file.path(d14, "A", "Foo.md"))
writeLines(c("---", "title: Foo B", "type: concept", "---"),
           file.path(d14, "B", "Foo.md"))
init_vault(d14, rproj = FALSE, agent_instructions = FALSE, adopt = TRUE)
update_index(d14)
ix <- readLines(file.path(d14, "index.md"))
# Both pages link as path-style targets, not the ambiguous basename
expect_true(any(grepl("\\[\\[A/Foo\\]\\]", ix)))
expect_true(any(grepl("\\[\\[B/Foo\\]\\]", ix)))
expect_false(any(grepl("\\[\\[Foo\\]\\]", ix)))
unlink(d14, recursive = TRUE)
