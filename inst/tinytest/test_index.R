# Tests for index.R (update_index)

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Add a wiki page manually
writeLines(c("---", "title: Test Page", "---", "Some content."),
           file.path(tmp, "wiki", "test-page.md"))

# --- update_index regenerates index.md ---
update_index(tmp)
idx <- readLines(file.path(tmp, "index.md"))
expect_true(any(grepl("test-page", idx)))
expect_true(any(grepl("Wiki", idx)))

# --- Count is correct ---
expect_true(any(grepl("Wiki (1)", idx, fixed = TRUE)))

# --- Control files excluded from index ---
expect_false(any(grepl("\\[\\[index\\]\\]", idx)))
expect_false(any(grepl("\\[\\[log\\]\\]", idx)))
expect_false(any(grepl("\\[\\[schema\\]\\]", idx)))

unlink(tmp, recursive = TRUE)
