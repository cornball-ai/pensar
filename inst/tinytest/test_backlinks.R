# Tests for backlinks.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Create wiki pages with wikilinks
writeLines(c("---", "title: Page A", "---",
             "Links to [[Page B]] and [[Page C]]."),
           file.path(tmp, "wiki", "Page A.md"))
writeLines(c("---", "title: Page B", "---",
             "Links to [[Page C]]."),
           file.path(tmp, "wiki", "Page B.md"))
writeLines(c("---", "title: Page C", "---",
             "No outgoing links."),
           file.path(tmp, "wiki", "Page C.md"))

# --- Backlinks to Page C ---
bl <- backlinks("Page C", vault = tmp)
expect_true(is.data.frame(bl))
expect_true("Page A" %in% bl$source)
expect_true("Page B" %in% bl$source)

# --- Backlinks to Page B ---
bl2 <- backlinks("Page B", vault = tmp)
expect_equal(nrow(bl2), 1L)
expect_equal(bl2$source[1L], "Page A")

# --- No backlinks ---
bl3 <- backlinks("Page A", vault = tmp)
expect_equal(nrow(bl3), 0L)

unlink(tmp, recursive = TRUE)
