# Tests for lint.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Setup: some raw pages with tags, some wiki pages
writeLines(c("---", "title: A", "tags:", "  - foo", "---", "Some content."),
           file.path(tmp, "raw", "articles", "page-a.md"))
writeLines(c("---", "title: B", "tags:", "  - foo", "---",
             "Links to [[page-a]] and [[missing-page]]."),
           file.path(tmp, "raw", "articles", "page-b.md"))
writeLines(c("---", "title: C", "tags:", "  - foo", "---", "Orphan."),
           file.path(tmp, "raw", "articles", "page-c.md"))
writeLines(c("---", "title: Wiki", "tags:", "  - bar", "---",
             "Links to [[page-a]]."),
           file.path(tmp, "wiki", "wiki-page.md"))

lr <- lint(tmp, min_cluster_size = 2L)
expect_true(inherits(lr, "pensar_lint"))

# Orphans: page-c and wiki-page have no incoming wikilinks
expect_true("page-c" %in% lr$orphans)
expect_true("wiki-page" %in% lr$orphans)
# page-a and page-b have incoming links
expect_false("page-a" %in% lr$orphans)

# Broken: [[missing-page]] from page-b
expect_true(any(lr$broken_links$link == "missing-page"))
expect_true(any(lr$broken_links$source == "page-b"))

# Cluster: tag "foo" has 3 raw pages and no wiki synthesis
expect_true("foo" %in% lr$suggested_clusters$tag)
# tag "bar" is only on the wiki page, should not appear
expect_false("bar" %in% lr$suggested_clusters$tag)

# Print method
out <- capture.output(print(lr))
expect_true(any(grepl("Orphan pages", out)))
expect_true(any(grepl("Broken wikilinks", out)))
expect_true(any(grepl("Tag clusters", out)))

unlink(tmp, recursive = TRUE)
