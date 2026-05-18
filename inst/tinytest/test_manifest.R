# Tests for manifest_path() / read_manifest() / update_manifest() and
# the ingest() / ingest_repo() hooks that populate the manifest (PR 4).

library(pensar)

# --- 1. Fresh vault: read_manifest returns empty struct, no file ---
v1 <- file.path(tempdir(), paste0("man-empty-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v1, rproj = FALSE, agent_instructions = FALSE)
m <- read_manifest(v1)
expect_true(is.list(m))
expect_equal(m$version, 1L)
expect_equal(length(m$sources), 0L)
expect_equal(length(m$address_map), 0L)
expect_false(file.exists(file.path(v1, ".pensar", "manifest.yml")))
unlink(v1, recursive = TRUE)

# --- 2. update_manifest writes only .pensar/manifest.yml ---
v2 <- file.path(tempdir(), paste0("man-write-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v2, rproj = FALSE, agent_instructions = FALSE)
update_manifest(v2, source = "https://example.com/foo",
                path = "raw/articles/example.md",
                hash = "sha1:abc")
expect_true(file.exists(file.path(v2, ".pensar", "manifest.yml")))
m <- read_manifest(v2)
expect_equal(m$sources[["raw/articles/example.md"]]$source,
             "https://example.com/foo")
expect_equal(m$sources[["raw/articles/example.md"]]$hash, "sha1:abc")
expect_true(!is.null(
    m$sources[["raw/articles/example.md"]]$ingested_at))
# No foreign manifest formats touched
expect_false(file.exists(file.path(v2, ".manifest.json")))
expect_false(file.exists(file.path(v2, ".raw", ".manifest.json")))
unlink(v2, recursive = TRUE)

# --- 3. ingest() populates the manifest after a successful write ---
v3 <- file.path(tempdir(), paste0("man-ingest-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v3, rproj = FALSE, agent_instructions = FALSE)
fp <- ingest("Hello world.", type = "articles", source = "demo",
             vault = v3)
m <- read_manifest(v3)
rel <- substring(fp, nchar(normalizePath(v3)) + 2L)
expect_true(rel %in% names(m$sources))
expect_equal(m$sources[[rel]]$source, "demo")
expect_true(grepl("^sha1:[0-9a-f]+$", m$sources[[rel]]$hash))
unlink(v3, recursive = TRUE)

# --- 4. update_index() does not mutate manifest mtime ---
v4 <- file.path(tempdir(), paste0("man-readonly-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v4, rproj = FALSE, agent_instructions = FALSE)
ingest("Hello.", type = "articles", source = "demo", vault = v4)
mfile <- file.path(v4, ".pensar", "manifest.yml")
expect_true(file.exists(mfile))
mtime_before <- file.info(mfile)$mtime
Sys.sleep(1.1)
update_index(v4)
mtime_after <- file.info(mfile)$mtime
expect_equal(mtime_before, mtime_after)
unlink(v4, recursive = TRUE)

# --- 5. status() does not mutate manifest mtime ---
v5 <- file.path(tempdir(), paste0("man-readonly-status-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v5, rproj = FALSE, agent_instructions = FALSE)
ingest("Hello.", type = "articles", source = "demo", vault = v5)
mfile <- file.path(v5, ".pensar", "manifest.yml")
mtime_before <- file.info(mfile)$mtime
Sys.sleep(1.1)
status(v5)
mtime_after <- file.info(mfile)$mtime
expect_equal(mtime_before, mtime_after)
unlink(v5, recursive = TRUE)

# --- 6. vault_registry(cache = "session") does not mutate manifest mtime ---
v6 <- file.path(tempdir(), paste0("man-readonly-reg-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v6, rproj = FALSE, agent_instructions = FALSE)
ingest("Hello.", type = "articles", source = "demo", vault = v6)
mfile <- file.path(v6, ".pensar", "manifest.yml")
mtime_before <- file.info(mfile)$mtime
Sys.sleep(1.1)
vault_registry(v6, cache = "session")
mtime_after <- file.info(mfile)$mtime
expect_equal(mtime_before, mtime_after)
unlink(v6, recursive = TRUE)

# --- 7. update_manifest(address) writes only to address_map ---
v7 <- file.path(tempdir(), paste0("man-addr-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v7, rproj = FALSE, agent_instructions = FALSE)
update_manifest(v7, path = "wiki/Foo.md", address = "c-000001")
m <- read_manifest(v7)
expect_equal(m$address_map[["wiki/Foo.md"]], "c-000001")
# No source record was created since only address was provided
expect_false("wiki/Foo.md" %in% names(m$sources))
unlink(v7, recursive = TRUE)

# --- 8. Re-ingesting the same source updates ingested_at + hash ---
v8 <- file.path(tempdir(), paste0("man-reingest-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v8, rproj = FALSE, agent_instructions = FALSE)
update_manifest(v8, source = "demo",
                path = "raw/articles/demo.md",
                hash = "sha1:first",
                ingested_at = "2026-05-15T00:00:00")
m1 <- read_manifest(v8)
expect_equal(m1$sources[["raw/articles/demo.md"]]$ingested_at,
             "2026-05-15T00:00:00")
update_manifest(v8, source = "demo",
                path = "raw/articles/demo.md",
                hash = "sha1:second")
m2 <- read_manifest(v8)
expect_equal(m2$sources[["raw/articles/demo.md"]]$hash, "sha1:second")
expect_true(m2$sources[["raw/articles/demo.md"]]$ingested_at !=
            "2026-05-15T00:00:00")
unlink(v8, recursive = TRUE)

# --- 9. manifest_path() returns the canonical write path ---
v9 <- file.path(tempdir(), paste0("man-path-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v9, rproj = FALSE, agent_instructions = FALSE)
mp <- manifest_path(v9)
expect_true(endsWith(mp, ".pensar/manifest.yml"))
unlink(v9, recursive = TRUE)

# --- 11. Structurally invalid manifest fields coerce to empty + warn ---
v11 <- file.path(tempdir(), paste0("man-shape-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v11, rproj = FALSE, agent_instructions = FALSE)
dir.create(file.path(v11, ".pensar"), showWarnings = FALSE)
# Valid YAML, but sources is a scalar and address_map is an unnamed list
writeLines(c("version: 1",
             "created: 2026-05-17",
             "sources: bad",
             "address_map:",
             "  - a",
             "  - b"),
           file.path(v11, ".pensar", "manifest.yml"))
warns <- character(0L)
m <- withCallingHandlers(read_manifest(v11),
                         warning = function(w) {
                             warns <<- c(warns, conditionMessage(w))
                             invokeRestart("muffleWarning")
                         })
expect_true(any(grepl("sources", warns)))
expect_true(any(grepl("address_map", warns)))
expect_true(is.list(m$sources) && length(m$sources) == 0L)
expect_true(is.list(m$address_map) && length(m$address_map) == 0L)
# An ingest on top of the recovered manifest still works
ingest("After bad manifest.", type = "articles", source = "demo",
       vault = v11)
m2 <- read_manifest(v11)
expect_true(length(m2$sources) > 0L)
unlink(v11, recursive = TRUE)

# --- 12. update_manifest() requires path when other fields are set ---
v12 <- file.path(tempdir(), paste0("man-nopath-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v12, rproj = FALSE, agent_instructions = FALSE)
err <- tryCatch(update_manifest(v12, source = "demo",
                                hash = "sha1:abc"),
                error = function(e) conditionMessage(e))
expect_true(grepl("`path` is required", err))
# But calling with no fields at all is still fine (returns path)
expect_silent(update_manifest(v12))
unlink(v12, recursive = TRUE)

# --- 10. Malformed manifest yields empty struct with warning ---
v10 <- file.path(tempdir(), paste0("man-bad-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v10, rproj = FALSE, agent_instructions = FALSE)
dir.create(file.path(v10, ".pensar"), showWarnings = FALSE)
writeLines("this is: not: valid: yaml: : :",
           file.path(v10, ".pensar", "manifest.yml"))
warns <- character(0L)
m <- withCallingHandlers(read_manifest(v10),
                         warning = function(w) {
                             warns <<- c(warns, conditionMessage(w))
                             invokeRestart("muffleWarning")
                         })
# Malformed but not fatal: returns the empty initialized struct
expect_true(is.list(m))
expect_equal(length(m$sources), 0L)
unlink(v10, recursive = TRUE)
