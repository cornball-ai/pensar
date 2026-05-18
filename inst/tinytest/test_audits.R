# Tests for dedup() and tags() audits (PR 8).

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

# --- 1. dedup() flags near-duplicate titles + shared tags ---
v1 <- file.path(tempdir(), paste0("aud-dup-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v1, rproj = FALSE, agent_instructions = FALSE)
make_page(v1, "wiki/Foo.md",
          frontmatter = list(title = "Alpha foo",
                             tags = c("topic-a", "demo")))
make_page(v1, "wiki/Foo2.md",
          frontmatter = list(title = "Alpha foos",
                             tags = c("topic-a", "demo")))
make_page(v1, "wiki/Unrelated.md",
          frontmatter = list(title = "Completely Different",
                             tags = c("topic-z")))
res <- dedup(v1, threshold = 0.7)
expect_true(nrow(res) >= 1L)
expect_true(any(res$page_a == "wiki/Foo.md" &
                res$page_b == "wiki/Foo2.md"))
# Unrelated pages aren't flagged
expect_false(any(res$page_a == "wiki/Unrelated.md" |
                 res$page_b == "wiki/Unrelated.md"))
expect_true(file.exists(file.path(v1, "_proposals", "dedup.md")))
lines <- readLines(file.path(v1, "_proposals", "dedup.md"))
expect_true(any(grepl("Pair 1", lines)))
unlink(v1, recursive = TRUE)

# --- 2. dedup() with no matches writes an empty-result report ---
v2 <- file.path(tempdir(), paste0("aud-dup-none-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v2, rproj = FALSE, agent_instructions = FALSE)
make_page(v2, "wiki/Alpha.md", frontmatter = list(title = "Alpha"))
make_page(v2, "wiki/Beta.md", frontmatter = list(title = "Beta"))
res <- dedup(v2, threshold = 0.95)
expect_equal(nrow(res), 0L)
lines <- readLines(file.path(v2, "_proposals", "dedup.md"))
expect_true(any(grepl("No candidate duplicates", lines)))
unlink(v2, recursive = TRUE)

# --- 3. dedup() on near-empty vault returns empty without error ---
v3 <- file.path(tempdir(), paste0("aud-dup-empty-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v3, rproj = FALSE, agent_instructions = FALSE)
res <- dedup(v3)
expect_equal(nrow(res), 0L)
unlink(v3, recursive = TRUE)

# --- 4. tags() without taxonomy lists tags by frequency ---
v4 <- file.path(tempdir(), paste0("aud-tags-freq-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v4, rproj = FALSE, agent_instructions = FALSE)
make_page(v4, "wiki/A.md",
          frontmatter = list(title = "A", tags = c("x", "y")))
make_page(v4, "wiki/B.md",
          frontmatter = list(title = "B", tags = c("x")))
res <- tags(v4)
expect_equal(res$used$count[res$used$tag == "x"], 2L)
expect_equal(res$used$count[res$used$tag == "y"], 1L)
expect_equal(nrow(res$unknown), 0L)
expect_equal(length(res$unused_taxonomy), 0L)
lines <- readLines(file.path(v4, "_proposals", "tags.md"))
expect_true(any(grepl("All used tags", lines)))
expect_true(any(grepl("No taxonomy", lines)))
unlink(v4, recursive = TRUE)

# --- 5. tags() with taxonomy flags unknown tags + near-miss ---
v5 <- file.path(tempdir(), paste0("aud-tags-tax-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v5, rproj = FALSE, agent_instructions = FALSE)
dir.create(file.path(v5, "_meta"), showWarnings = FALSE)
writeLines(c("# Tag taxonomy", "",
             "- programming",
             "- design",
             "- research"),
           file.path(v5, "_meta", "taxonomy.md"))
make_page(v5, "wiki/A.md",
          frontmatter = list(title = "A",
                             tags = c("programming", "progamming")))
make_page(v5, "wiki/B.md",
          frontmatter = list(title = "B", tags = c("ad-hoc")))
res <- tags(v5)
expect_true("progamming" %in% res$unknown$tag)
expect_equal(res$unknown$suggestion[res$unknown$tag == "progamming"],
             "programming")
expect_true("ad-hoc" %in% res$unknown$tag)
expect_true("design" %in% res$unused_taxonomy)
expect_true("research" %in% res$unused_taxonomy)
lines <- readLines(file.path(v5, "_proposals", "tags.md"))
expect_true(any(grepl("Unknown tags", lines)))
expect_true(any(grepl("did you mean `programming`", lines)))
expect_true(any(grepl("Unused taxonomy", lines)))
unlink(v5, recursive = TRUE)

# --- 6. tags() respects an explicit taxonomy arg ---
v6 <- file.path(tempdir(), paste0("aud-tags-arg-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v6, rproj = FALSE, agent_instructions = FALSE)
make_page(v6, "wiki/A.md",
          frontmatter = list(title = "A", tags = c("foo")))
tax_path <- file.path(tempdir(), paste0("taxonomy-",
                                        format(Sys.time(),
                                               "%H%M%OS3"), ".md"))
writeLines(c("- foo", "- bar"), tax_path)
res <- tags(v6, taxonomy = tax_path)
expect_equal(nrow(res$unknown), 0L)
expect_true("bar" %in% res$unused_taxonomy)
unlink(v6, recursive = TRUE)
unlink(tax_path)

# --- 7. tags() on empty vault works ---
v7 <- file.path(tempdir(), paste0("aud-tags-empty-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v7, rproj = FALSE, agent_instructions = FALSE)
res <- tags(v7)
expect_equal(nrow(res$used), 0L)
expect_true(file.exists(file.path(v7, "_proposals", "tags.md")))
unlink(v7, recursive = TRUE)

# --- 8. Neither audit auto-merges or auto-renames anything ---
v8 <- file.path(tempdir(), paste0("aud-readonly-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v8, rproj = FALSE, agent_instructions = FALSE)
fp_a <- make_page(v8, "wiki/Foo.md",
                  frontmatter = list(title = "Alpha foo",
                                     tags = c("x")))
fp_b <- make_page(v8, "wiki/Foo2.md",
                  frontmatter = list(title = "Alpha foos",
                                     tags = c("x")))
before <- list(a = readLines(fp_a), b = readLines(fp_b))
dedup(v8)
tags(v8)
after <- list(a = readLines(fp_a), b = readLines(fp_b))
expect_identical(before, after)
unlink(v8, recursive = TRUE)

# --- 9. _proposals/*.md is marked system_file in the registry, so
#    lint() doesn't flag them as orphans ---
v9 <- file.path(tempdir(), paste0("aud-lint-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v9, rproj = FALSE, agent_instructions = FALSE)
make_page(v9, "wiki/Foo.md", frontmatter = list(title = "Foo"))
make_page(v9, "wiki/Foos.md", frontmatter = list(title = "Foos"))
dedup(v9, threshold = 0.5)
tags(v9)
expect_true(file.exists(file.path(v9, "_proposals", "dedup.md")))
expect_true(file.exists(file.path(v9, "_proposals", "tags.md")))
li <- lint(v9)
expect_false("dedup" %in% li$orphans)
expect_false("tags" %in% li$orphans)
reg <- vault_registry(v9, cache = "none")
expect_true(all(reg$system_file[reg$path %in%
                                c("_proposals/dedup.md",
                                  "_proposals/tags.md")]))
unlink(v9, recursive = TRUE)

# --- 10. tags(taxonomy = "missing/path") errors instead of silently
#    skipping validation ---
v10 <- file.path(tempdir(), paste0("aud-bad-tax-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v10, rproj = FALSE, agent_instructions = FALSE)
make_page(v10, "wiki/A.md",
          frontmatter = list(title = "A", tags = c("foo")))
err <- tryCatch(tags(v10, taxonomy = "/no/such/file.md"),
                error = function(e) conditionMessage(e))
expect_true(grepl("Taxonomy file not found", err))
# Implicit NULL on a vault without a default taxonomy still works
expect_silent(tags(v10))
unlink(v10, recursive = TRUE)
