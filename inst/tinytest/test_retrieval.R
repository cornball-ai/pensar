# Tests for retrieval primitives (PR 5): search_pages, page_context,
# related_pages, recent_activity.

library(pensar)

make_page <- function(vault, relpath, frontmatter = list(), body = "") {
    fp <- file.path(vault, relpath)
    dir.create(dirname(fp), recursive = TRUE, showWarnings = FALSE)
    fm_lines <- character(0L)
    if (length(frontmatter) > 0L) {
        fm_lines <- c("---", yaml::as.yaml(frontmatter), "---")
    }
    writeLines(c(fm_lines, body), fp)
    fp
}

# --- 1. search_pages by title ---
v1 <- file.path(tempdir(), paste0("ret-search-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v1, rproj = FALSE, agent_instructions = FALSE)
make_page(v1, "wiki/Alpha.md", frontmatter = list(title = "Alpha"))
make_page(v1, "wiki/Beta.md", frontmatter = list(title = "Beta"))
res <- search_pages("alpha", vault = v1)
expect_equal(nrow(res), 1L)
expect_equal(res$node_id, "Alpha")
expect_equal(res$matched_in, "title")
unlink(v1, recursive = TRUE)

# --- 2. search_pages by tag ---
v2 <- file.path(tempdir(), paste0("ret-tag-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v2, rproj = FALSE, agent_instructions = FALSE)
make_page(v2, "wiki/Foo.md",
          frontmatter = list(title = "Foo",
                             tags = c("topic-x", "demo")))
res <- search_pages("topic-x", vault = v2)
expect_equal(nrow(res), 1L)
expect_true(grepl("^tag:", res$matched_in))
unlink(v2, recursive = TRUE)

# --- 3. search_pages by alias ---
v3 <- file.path(tempdir(), paste0("ret-alias-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v3, rproj = FALSE, agent_instructions = FALSE)
make_page(v3, "wiki/Foo.md",
          frontmatter = list(title = "Foo",
                             aliases = c("nickname", "nicky")))
res <- search_pages("nick", vault = v3)
expect_true(nrow(res) >= 1L)
expect_true(any(grepl("^alias:", res$matched_in)))
unlink(v3, recursive = TRUE)

# --- 4. search_pages type filter ---
v4 <- file.path(tempdir(), paste0("ret-typ-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v4, rproj = FALSE, agent_instructions = FALSE)
make_page(v4, "wiki/A.md",
          frontmatter = list(title = "Anchor", type = "concept"))
make_page(v4, "wiki/B.md",
          frontmatter = list(title = "Anchor", type = "entity"))
res <- search_pages("anchor", vault = v4, type = "entity")
expect_equal(nrow(res), 1L)
expect_equal(res$node_id, "B")
unlink(v4, recursive = TRUE)

# --- 5. search_pages in_body finds body-only matches ---
v5 <- file.path(tempdir(), paste0("ret-body-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v5, rproj = FALSE, agent_instructions = FALSE)
make_page(v5, "wiki/Foo.md", frontmatter = list(title = "Foo"),
          body = "The body mentions Halifax.")
expect_equal(nrow(search_pages("halifax", vault = v5)), 0L)
res <- search_pages("halifax", vault = v5, in_body = TRUE)
expect_equal(nrow(res), 1L)
expect_equal(res$matched_in, "body")
unlink(v5, recursive = TRUE)

# --- 6. search_pages returns empty df when no match ---
v6 <- file.path(tempdir(), paste0("ret-empty-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v6, rproj = FALSE, agent_instructions = FALSE)
res <- search_pages("nothing-here", vault = v6)
expect_equal(nrow(res), 0L)
expect_true(all(c("path", "node_id", "title", "type", "matched_in")
                %in% names(res)))
unlink(v6, recursive = TRUE)

# --- 7. page_context returns expected struct ---
v7 <- file.path(tempdir(), paste0("ret-ctx-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v7, rproj = FALSE, agent_instructions = FALSE)
make_page(v7, "wiki/Foo.md",
          frontmatter = list(title = "Foo", type = "concept"),
          body = "Body of Foo. Cites [[Bar]].")
make_page(v7, "wiki/Bar.md", frontmatter = list(title = "Bar"),
          body = "Cites [[Foo]].")
ctx <- page_context("Foo", vault = v7)
expect_true(inherits(ctx, "pensar_page_context"))
expect_equal(ctx$node_id, "Foo")
expect_equal(ctx$frontmatter$title, "Foo")
expect_true(grepl("Body of Foo", ctx$body_head))
expect_true("Bar" %in% ctx$outlinks$target)
expect_true("Bar" %in% ctx$backlinks$source)
unlink(v7, recursive = TRUE)

# --- 8. page_context resolves path-style queries ---
v8 <- file.path(tempdir(), paste0("ret-ctx-path-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v8, rproj = FALSE, agent_instructions = FALSE)
make_page(v8, "Notes/Foo.md", frontmatter = list(title = "Foo"),
          body = "Body.")
ctx <- page_context("Notes/Foo", vault = v8)
expect_equal(ctx$path, "Notes/Foo.md")
unlink(v8, recursive = TRUE)

# --- 9. page_context errors on missing page ---
v9 <- file.path(tempdir(), paste0("ret-ctx-miss-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v9, rproj = FALSE, agent_instructions = FALSE)
err <- tryCatch(page_context("ghost", vault = v9),
                error = function(e) conditionMessage(e))
expect_true(grepl("Page not found", err))
unlink(v9, recursive = TRUE)

# --- 10. related_pages ranks by shared tags + co-citation ---
v10 <- file.path(tempdir(), paste0("ret-rel-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v10, rproj = FALSE, agent_instructions = FALSE)
make_page(v10, "wiki/Target.md",
          frontmatter = list(title = "Target", tags = c("x", "y")),
          body = "Cites [[Shared]] and [[OtherShared]].")
make_page(v10, "wiki/HighScore.md",
          frontmatter = list(title = "HighScore", tags = c("x", "y")),
          body = "Cites [[Shared]] and [[OtherShared]].")
make_page(v10, "wiki/MidScore.md",
          frontmatter = list(title = "MidScore", tags = c("x")),
          body = "Cites [[Shared]].")
make_page(v10, "wiki/Unrelated.md",
          frontmatter = list(title = "Unrelated", tags = c("z")),
          body = "Cites [[Nobody]].")
make_page(v10, "wiki/Shared.md", frontmatter = list(title = "Shared"))
make_page(v10, "wiki/OtherShared.md",
          frontmatter = list(title = "OtherShared"))
res <- related_pages("Target", vault = v10, k = 10L)
expect_true(nrow(res) >= 2L)
hi_idx <- which(res$node_id == "HighScore")
mid_idx <- which(res$node_id == "MidScore")
expect_true(length(hi_idx) == 1L && length(mid_idx) == 1L)
expect_true(res$score[hi_idx] > res$score[mid_idx])
expect_false("Unrelated" %in% res$node_id)
expect_false("Target" %in% res$node_id)
unlink(v10, recursive = TRUE)

# --- 11. related_pages returns empty when no overlap ---
v11 <- file.path(tempdir(), paste0("ret-rel-empty-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v11, rproj = FALSE, agent_instructions = FALSE)
make_page(v11, "wiki/A.md", frontmatter = list(title = "A"))
make_page(v11, "wiki/B.md", frontmatter = list(title = "B"))
res <- related_pages("A", vault = v11, k = 5L)
expect_equal(nrow(res), 0L)
unlink(v11, recursive = TRUE)

# --- 12. recent_activity returns newest-first ingest entries ---
v12 <- file.path(tempdir(), paste0("ret-act-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v12, rproj = FALSE, agent_instructions = FALSE)
ingest("First.", type = "articles", source = "first", vault = v12)
Sys.sleep(1.1)
ingest("Second.", type = "articles", source = "second", vault = v12)
act <- recent_activity(v12, days = 1L)
expect_true(nrow(act) >= 2L)
expect_true(any(grepl("second", act$message[1L])))
expect_true(all(c("timestamp", "operation", "message") %in%
                names(act)))
expect_true(all(act$timestamp[seq_len(nrow(act) - 1L)] >=
                act$timestamp[2:nrow(act)]))
unlink(v12, recursive = TRUE)

# --- 13. recent_activity respects the days window ---
v13 <- file.path(tempdir(), paste0("ret-act-old-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v13, rproj = FALSE, agent_instructions = FALSE)
# Replace log.md with one entry from 30 days ago
old_ts <- format(Sys.time() - as.difftime(30, units = "days"),
                 "%Y-%m-%dT%H:%M:%S")
writeLines(c("---", "title: Vault Log", "type: log", "---", "",
             "# Vault Log", "",
             sprintf("- **%s** [ingest] Stale entry", old_ts)),
           file.path(v13, "log.md"))
act <- recent_activity(v13, days = 7L)
expect_equal(nrow(act), 0L)
act_all <- recent_activity(v13, days = 365L)
expect_true(nrow(act_all) >= 1L)
unlink(v13, recursive = TRUE)

# --- 14. recent_activity is read-only (no writes) ---
v14 <- file.path(tempdir(), paste0("ret-act-readonly-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v14, rproj = FALSE, agent_instructions = FALSE)
ingest("Hello.", type = "articles", source = "demo", vault = v14)
mtime_before <- file.info(file.path(v14, "log.md"))$mtime
Sys.sleep(1.1)
recent_activity(v14, days = 1L)
mtime_after <- file.info(file.path(v14, "log.md"))$mtime
expect_equal(mtime_before, mtime_after)
unlink(v14, recursive = TRUE)
