# Tests for export.R (vault_export)

library(pensar)

# Skip when pandoc isn't available (shouldn't happen in normal CI but be safe)
if (nchar(Sys.which("pandoc")) == 0L) {
    exit_file("pandoc not available")
}

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Add a wiki page with wikilinks (some good, one broken)
writeLines(c("---", "title: Concept A", "---",
             "Links to [[Source 1]] and [[missing-page]].",
             "",
             "See also [[Source 2|second source]]."),
           file.path(tmp, "wiki", "A.md"))
writeLines(c("---", "title: Source 1", "---",
             "# Source 1", "Ground truth."),
           file.path(tmp, "raw", "articles", "Source 1.md"))
writeLines(c("---", "title: Source 2", "---",
             "Another source."),
           file.path(tmp, "raw", "articles", "Source 2.md"))
update_index(tmp)

site_dir <- file.path(tmp, "_site")
out <- vault_export(tmp, site_dir)
expect_true(dir.exists(out))
expect_true(file.exists(file.path(out, "index.html")))
expect_true(file.exists(file.path(out, "style.css")))
expect_true(file.exists(file.path(out, "wiki", "A.html")))
expect_true(file.exists(file.path(out, "raw", "articles", "Source 1.html")))

# Check wikilinks were resolved
a_html <- paste(readLines(file.path(out, "wiki", "A.html")),
                collapse = "\n")
# Good wikilink becomes an anchor pointing at the target HTML
expect_true(grepl("Source%201.html", a_html))
expect_true(grepl("Source%202.html", a_html))
expect_true(grepl(">second\\s+source</a>", a_html, perl = TRUE))
# Broken wikilink renders as span, not anchor
expect_true(grepl("broken-link", a_html))
expect_false(grepl("missing-page.html", a_html))

# Check index lists all categories
idx_html <- paste(readLines(file.path(out, "index.html")),
                  collapse = "\n")
expect_true(grepl("Wiki", idx_html))
expect_true(grepl("Raw: Articles", idx_html))
expect_true(grepl("Concept A", idx_html))

# Export is idempotent (same path) and incremental.
# First export is a full build (nothing skipped); a re-export with no source
# changes renders zero pages.
expect_equal(attr(out, "skipped"), 0L)
expect_true(file.exists(file.path(out, ".pensar-export-cache.yml")))
# NB: each export appends to the vault's log.md (it logs itself), so log.md
# is genuinely changed and re-renders on the next export. That's a constant
# +1 below the user-facing change count.
out2 <- vault_export(tmp, site_dir)
expect_identical(as.character(out), as.character(out2))
expect_equal(attr(out2, "rendered"), 1L)            # just log.md

# Editing one page re-renders only that page (+ log.md).
writeLines(c("---", "title: Source 1", "---", "# Source 1", "Edited body."),
           file.path(tmp, "raw", "articles", "Source 1.md"))
out3 <- vault_export(tmp, site_dir)
expect_equal(attr(out3, "rendered"), 2L)            # Source 1 + log.md

# Adding the previously-missing page renders it AND re-renders A.md, whose
# [[missing-page]] link flips from broken to resolved (+ log.md).
writeLines(c("---", "title: missing-page", "---", "Now it exists."),
           file.path(tmp, "wiki", "missing-page.md"))
out4 <- vault_export(tmp, site_dir)
expect_equal(attr(out4, "rendered"), 3L)            # missing-page + A + log.md
a_html2 <- paste(readLines(file.path(out, "wiki", "A.html")), collapse = "\n")
expect_true(grepl("missing-page.html", a_html2))   # link now resolves
expect_false(grepl("broken-link", a_html2))         # A's only broken link is gone

# Deleting a page removes its output and re-renders the page that linked to it.
file.remove(file.path(tmp, "wiki", "missing-page.md"))
out5 <- vault_export(tmp, site_dir)
expect_false(file.exists(file.path(out, "wiki", "missing-page.html")))
a_html3 <- paste(readLines(file.path(out, "wiki", "A.html")), collapse = "\n")
expect_true(grepl("broken-link", a_html3))          # link broken again

# Deleting the cache forces a full rebuild.
file.remove(file.path(out, ".pensar-export-cache.yml"))
out6 <- vault_export(tmp, site_dir)
expect_equal(attr(out6, "skipped"), 0L)

# Missing pandoc check
# (Can't actually test this without hiding pandoc; test the check function
# runs silently when pandoc is present)
expect_silent(pensar:::check_pandoc())

# --- PENSAR_SITE_DIR env var ---
old <- Sys.getenv("PENSAR_SITE_DIR", unset = NA)
env_target <- file.path(tmp, "env-site")
Sys.setenv(PENSAR_SITE_DIR = env_target)
expect_equal(pensar:::default_site_dir(), env_target)
if (is.na(old)) {
    Sys.unsetenv("PENSAR_SITE_DIR")
} else {
    Sys.setenv(PENSAR_SITE_DIR = old)
}

unlink(tmp, recursive = TRUE)
