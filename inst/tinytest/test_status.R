# Tests for status.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Add some content
ingest("Article content", type = "articles", source = "test-source",
       vault = tmp)
writeLines(c("---", "title: Wiki Page", "---", "Content with [[link]]."),
           file.path(tmp, "wiki", "concept.md"))

st <- status(vault = tmp)
expect_true(inherits(st, "pensar_status"))
expect_true(st$raw_articles >= 1L)
expect_true(st$wiki >= 1L)
expect_true(st$total >= 2L)

# --- Print method works ---
out <- capture.output(print(st))
expect_true(any(grepl("articles", out)))
expect_true(any(grepl("Wiki", out)))

unlink(tmp, recursive = TRUE)
