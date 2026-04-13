# Tests for ingest.R

library(pensar)

# --- Setup ---
tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# --- Ingest an article ---
fp <- ingest("Some article content about R packages.",
             type = "articles", source = "https://example.com/article",
             title = "Example Article", tags = c("R", "packages"),
             vault = tmp)
expect_true(file.exists(fp))
expect_true(grepl("raw/articles", fp))

# Check frontmatter
fm <- pensar:::parse_frontmatter(fp)
expect_equal(fm$title, "Example Article")
expect_equal(fm$type, "articles")
expect_equal(fm$source, "https://example.com/article")
expect_true("R" %in% fm$tags)

# --- Ingest a chat ---
fp2 <- ingest("User: Hello\nAssistant: Hi there",
              type = "chats", source = "llamar-session-123",
              vault = tmp)
expect_true(file.exists(fp2))
expect_true(grepl("raw/chats", fp2))

# --- Index was updated ---
idx <- readLines(file.path(tmp, "index.md"))
expect_true(any(grepl("Articles", idx)))

# --- Log was updated ---
log <- readLines(file.path(tmp, "log.md"))
expect_true(sum(grepl("ingest", log)) >= 2L)

# --- Error on non-vault ---
expect_error(ingest("x", type = "articles", source = "test",
                    vault = tempdir()))

unlink(tmp, recursive = TRUE)
