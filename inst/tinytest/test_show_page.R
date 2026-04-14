# Tests for show_page.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

writeLines(c("---", "title: Concept A", "type: concept",
             "tags:", "  - r", "  - packages",
             "---",
             "This builds on [[Source 1]] and [[Source 2]]."),
           file.path(tmp, "wiki", "A.md"))
writeLines(c("---", "title: Source 1", "---", "Ground truth."),
           file.path(tmp, "raw", "articles", "Source 1.md"))
writeLines(c("---", "title: Source 2", "---", "More ground truth."),
           file.path(tmp, "raw", "articles", "Source 2.md"))
writeLines(c("---", "title: Downstream", "---",
             "Depends on [[A]]."),
           file.path(tmp, "wiki", "Downstream.md"))

# --- show_page returns the expected structure ---
sp <- show_page("A", vault = tmp)
expect_true(inherits(sp, "pensar_page"))
expect_equal(sp$title, "Concept A")
expect_equal(sp$type, "concept")
expect_true("r" %in% sp$tags)
expect_equal(nrow(sp$outlinks), 2L)
expect_equal(nrow(sp$backlinks), 1L)
expect_equal(sp$backlinks$source[1L], "Downstream")

# --- Print method ---
out <- capture.output(print(sp))
expect_true(any(grepl("Outlinks", out)))
expect_true(any(grepl("Backlinks", out)))
expect_true(any(grepl("Source 1", out)))
expect_true(any(grepl("Downstream", out)))

# --- Missing page error ---
expect_error(show_page("nonexistent", vault = tmp))

unlink(tmp, recursive = TRUE)
