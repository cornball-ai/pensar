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
             "See also [[Source 2]]."),
           file.path(tmp, "wiki", "A.md"))
writeLines(c("---", "title: Source 1", "---",
             "# Source 1", "Ground truth."),
           file.path(tmp, "raw", "articles", "Source 1.md"))
writeLines(c("---", "title: Source 2", "---",
             "Another source."),
           file.path(tmp, "raw", "articles", "Source 2.md"))
update_index(tmp)

out <- vault_export(tmp)
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
# Broken wikilink renders as span, not anchor
expect_true(grepl("broken-link", a_html))
expect_false(grepl("missing-page.html", a_html))

# Check index lists all categories
idx_html <- paste(readLines(file.path(out, "index.html")),
                  collapse = "\n")
expect_true(grepl("Wiki", idx_html))
expect_true(grepl("Raw: Articles", idx_html))
expect_true(grepl("Concept A", idx_html))

# Export is idempotent (overwrite)
out2 <- vault_export(tmp)
expect_equal(out, out2)

# Missing pandoc check
# (Can't actually test this without hiding pandoc; test the check function
# runs silently when pandoc is present)
expect_silent(pensar:::check_pandoc())

unlink(tmp, recursive = TRUE)
