# Tests for ingest_url() (PR 6). Network-dependent tests are gated by
# tinytest::at_home() so R CMD check on CI doesn't reach out.

library(pensar)
using_tinytest <- requireNamespace("tinytest", quietly = TRUE)

# --- Unit tests that don't need the network ------------------------------

# extract_html_title handles missing tag
expect_null(pensar:::extract_html_title("<html><body>nope</body></html>"))

# extract_html_title strips entities
title <- pensar:::extract_html_title(
    "<html><head><title>Foo &amp; Bar</title></head></html>")
expect_equal(title, "Foo & Bar")

# content_type_allowed gates MIME types
expect_true(pensar:::content_type_allowed("text/html"))
expect_true(pensar:::content_type_allowed("application/json"))
expect_false(pensar:::content_type_allowed("image/png"))
expect_false(pensar:::content_type_allowed("application/octet-stream"))

# response_content_type strips charset suffix
fake_resp <- list(type = "text/html; charset=UTF-8")
expect_equal(pensar:::response_content_type(fake_resp), "text/html")

# ingest_url rejects empty / non-character url
v_unit <- file.path(tempdir(), paste0("iu-unit-",
                                      format(Sys.time(), "%H%M%OS3")))
init_vault(v_unit, rproj = FALSE, agent_instructions = FALSE)
err <- tryCatch(ingest_url("", vault = v_unit),
                error = function(e) conditionMessage(e))
expect_true(grepl("non-empty string", err))
err <- tryCatch(ingest_url(c("a", "b"), vault = v_unit),
                error = function(e) conditionMessage(e))
expect_true(grepl("non-empty string", err))
unlink(v_unit, recursive = TRUE)

# --- existing_source_path() robustness (no network) ---------------------

# Stale manifest entry (file deleted) → returns NULL so caller re-fetches.
v_stale <- file.path(tempdir(), paste0("iu-stale-",
                                       format(Sys.time(), "%H%M%OS3")))
init_vault(v_stale, rproj = FALSE, agent_instructions = FALSE)
update_manifest(v_stale, source = "https://example.com/foo",
                path = "raw/articles/missing.md",
                hash = "sha1:abc")
expect_null(pensar:::existing_source_path("https://example.com/foo",
                                          v_stale))
unlink(v_stale, recursive = TRUE)

# Malformed per-entry record (scalar instead of list) → skipped, not fatal.
v_bad <- file.path(tempdir(), paste0("iu-bad-entry-",
                                     format(Sys.time(), "%H%M%OS3")))
init_vault(v_bad, rproj = FALSE, agent_instructions = FALSE)
dir.create(file.path(v_bad, ".pensar"), showWarnings = FALSE)
writeLines(c("version: 1", "created: 2026-05-17",
             "sources:",
             "  raw/articles/a.md: bad",
             "address_map: {}"),
           file.path(v_bad, ".pensar", "manifest.yml"))
expect_null(pensar:::existing_source_path("https://example.com",
                                          v_bad))
unlink(v_bad, recursive = TRUE)

# --- Network tests, gated by at_home() ----------------------------------

if (tinytest::at_home()) {
    # 1. Fetch example.com -> writes raw/articles/<date>-...md
    v1 <- file.path(tempdir(), paste0("iu-",
                                      format(Sys.time(), "%H%M%OS3")))
    init_vault(v1, rproj = FALSE, agent_instructions = FALSE)
    rel <- ingest_url("https://example.com", vault = v1)
    expect_true(grepl("^raw/articles/", rel))
    expect_true(file.exists(file.path(v1, rel)))
    # Frontmatter records the URL as source
    fm <- pensar:::parse_frontmatter(file.path(v1, rel))
    expect_equal(fm$source, "https://example.com")
    # Manifest records the URL too (ingest's hook handles this)
    m <- read_manifest(v1)
    expect_true(rel %in% names(m$sources))
    expect_equal(m$sources[[rel]]$source, "https://example.com")
    expect_true(grepl("^sha1:", m$sources[[rel]]$hash))
    unlink(v1, recursive = TRUE)

    # 2. Re-ingesting the same URL returns the existing path without a
    #    second fetch.
    v2 <- file.path(tempdir(), paste0("iu-dedup-",
                                      format(Sys.time(), "%H%M%OS3")))
    init_vault(v2, rproj = FALSE, agent_instructions = FALSE)
    rel1 <- ingest_url("https://example.com", vault = v2)
    n_files_before <- length(list.files(file.path(v2, "raw"),
                                        recursive = TRUE))
    rel2 <- ingest_url("https://example.com", vault = v2)
    expect_equal(rel1, rel2)
    n_files_after <- length(list.files(file.path(v2, "raw"),
                                       recursive = TRUE))
    expect_equal(n_files_before, n_files_after)
    unlink(v2, recursive = TRUE)

    # 3. 404 errors cleanly; no file written.
    v3 <- file.path(tempdir(), paste0("iu-404-",
                                      format(Sys.time(), "%H%M%OS3")))
    init_vault(v3, rproj = FALSE, agent_instructions = FALSE)
    err <- tryCatch(
        ingest_url("https://example.com/does-not-exist-xyz123",
                   vault = v3),
        error = function(e) conditionMessage(e))
    expect_true(grepl("Refusing non-2xx|404|Failed", err))
    expect_equal(length(list.files(file.path(v3, "raw"),
                                   recursive = TRUE)), 0L)
    unlink(v3, recursive = TRUE)
}
