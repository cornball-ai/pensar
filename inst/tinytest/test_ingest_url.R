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
