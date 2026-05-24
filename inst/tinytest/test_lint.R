# Tests for lint.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Setup: some raw pages with tags, some wiki pages
writeLines(c("---", "title: A", "tags:", "  - foo", "---", "Some content."),
           file.path(tmp, "raw", "articles", "page-a.md"))
writeLines(c("---", "title: B", "tags:", "  - foo", "---", "Some content."),
           file.path(tmp, "raw", "articles", "page-b.md"))
writeLines(c("---", "title: C", "tags:", "  - foo", "---", "Some content."),
           file.path(tmp, "raw", "articles", "page-c.md"))
writeLines(c("---", "title: Wiki", "tags:", "  - bar", "---",
             "Links to [[page-a]]."),
           file.path(tmp, "wiki", "wiki-page.md"))
writeLines(c("---", "title: Bad Link", "---",
             "Links to [[page-a]] and [[missing-page]]."),
           file.path(tmp, "wiki", "bad-link.md"))

lr <- lint(tmp, min_cluster_size = 2L)
expect_true(inherits(lr, "pensar_lint"))

# Wiki orphans: should be zero in a healthy vault
expect_true("wiki-page" %in% lr$orphans)
expect_true("bad-link" %in% lr$orphans)
# Raw pages are not in $orphans (wiki-only, per 29ba3b9)
expect_false("page-a" %in% lr$orphans)

# Raw orphans: synthesis backlog — content ingested but never written up
expect_false("page-a" %in% lr$raw_orphans)  # linked from wiki-page
expect_true("page-b" %in% lr$raw_orphans)
expect_true("page-c" %in% lr$raw_orphans)

# Broken: only wiki pages are checked for broken links
expect_true(any(lr$broken_links$link == "missing-page"))
expect_true(any(lr$broken_links$source == "bad-link"))

# Cluster: tag "foo" has 3 raw pages and no wiki synthesis
expect_true("foo" %in% lr$suggested_clusters$tag)
# tag "bar" is only on the wiki page, should not appear
expect_false("bar" %in% lr$suggested_clusters$tag)

# .pensarignore: filters synthesis backlog only
ignore_vault <- file.path(tempdir(), paste0("vault-ignore-",
                                            format(Sys.time(), "%H%M%S")))
init_vault(ignore_vault)
writeLines(c("---", "title: Scratch", "tags:", "  - scratch", "---", "Note."),
           file.path(ignore_vault, "raw", "articles", "scratch.md"))
writeLines(c("---", "title: Real", "tags:", "  - real", "---", "Article."),
           file.path(ignore_vault, "raw", "articles", "real.md"))
writeLines(c("---", "title: Wiki", "---", "Links to [[missing]]."),
           file.path(ignore_vault, "wiki", "wiki-page.md"))
writeLines("raw/articles/scratch.md",
           file.path(ignore_vault, ".pensarignore"))

ir <- lint(ignore_vault, min_cluster_size = 1L)
# scratch.md is ignored from backlog
expect_false("scratch" %in% ir$raw_orphans)
expect_false("scratch" %in% ir$suggested_clusters$tag)
# real.md is not ignored
expect_true("real" %in% ir$raw_orphans)
expect_true("real" %in% ir$suggested_clusters$tag)
# broken links in wiki are NOT affected by .pensarignore
expect_true(any(ir$broken_links$link == "missing"))
# scratch still in registry
reg <- vault_registry(ignore_vault)
expect_true(any(reg$node_id == "scratch"))

unlink(c(tmp, ignore_vault), recursive = TRUE)
