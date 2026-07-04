# Tests for merge.R (vault_merge and the conflict-resolution engine)

library(pensar)

# --- Unit: is_strict_subsequence ---
expect_true(pensar:::is_strict_subsequence(c("a", "c"), c("a", "b", "c")))
expect_false(pensar:::is_strict_subsequence(c("c", "a"), c("a", "b", "c")))
expect_false(pensar:::is_strict_subsequence(c("a", "b"), c("a", "b")))
expect_false(pensar:::is_strict_subsequence(c("a", "x"), c("a", "b", "c")))
expect_false(pensar:::is_strict_subsequence(NULL, c("a")))

# --- Unit: union_lines ---
expect_equal(pensar:::union_lines(c("h", "a"), c("h", "b")),
             c("h", "a", "b"))
expect_equal(pensar:::union_lines(NULL, c("x")), c("x"))
expect_equal(pensar:::union_lines(c("x"), NULL), c("x"))

# --- Unit: digest_entry_id is content-derived ---
id <- pensar:::digest_entry_id("wiki/a.md",
                               "0123456789abcdef", "fedcba9876543210",
                               "prose-divergence")
expect_equal(id, "wiki/a.md 0123456..fedcba9 prose-divergence")
id2 <- pensar:::digest_entry_id("wiki/a.md", NA_character_,
                                "fedcba9876543210", "delete-modify")
expect_equal(id2, "wiki/a.md absent..fedcba9 delete-modify")

# --- Unit: lint_dominates ---
clean <- list(fm_ok = TRUE, broken = 0L)
dirty <- list(fm_ok = TRUE, broken = 2L)
nofm <- list(fm_ok = FALSE, broken = 0L)
expect_true(pensar:::lint_dominates(clean, dirty))
expect_false(pensar:::lint_dominates(dirty, clean))
expect_true(pensar:::lint_dominates(clean, nofm))
expect_false(pensar:::lint_dominates(clean, clean))
# Incomparable: one has frontmatter, the other fewer broken links
expect_false(pensar:::lint_dominates(nofm, dirty))
expect_false(pensar:::lint_dominates(dirty, nofm))

# --- Unit: append_digest dedupes by entry id ---
vd <- file.path(tempdir(), paste0("digest-", format(Sys.time(), "%H%M%OS3")))
init_vault(vd, rproj = FALSE, agent_instructions = FALSE)
entry <- c("## wiki/x.md aaaaaaa..bbbbbbb prose-divergence", "",
           "- path: `wiki/x.md`", "")
pensar:::append_digest(vd, list(entry))
pensar:::append_digest(vd, list(entry))
digest_lines <- readLines(file.path(vd, ".pensar", "merge-conflicts.md"))
expect_equal(sum(grepl("^## wiki/x.md", digest_lines)), 1L)
unlink(vd, recursive = TRUE)

if (nchar(Sys.which("git")) == 0L) {
    exit_file("git not available")
}

git_q <- function(...) {
    system2("git", c(...), stdout = FALSE, stderr = FALSE)
}
stamp <- format(Sys.time(), "%H%M%OS3")
old_push_env <- Sys.getenv("PENSAR_AUTO_PUSH", unset = NA)
Sys.setenv(PENSAR_AUTO_PUSH = "true")

# --- E2E: superset side wins outright, nothing digested ---
bare <- file.path(tempdir(), paste0("merge-bare-", stamp, ".git"))
git_q("init", "-q", "--bare", "-b", "main", bare)

tmpA <- file.path(tempdir(), paste0("merge-a-", stamp))
init_vault(tmpA)
writeLines(c("---", "title: Topic", "---", "", "Base paragraph."),
           file.path(tmpA, "wiki", "topic.md"))
git_q("-C", tmpA, "init", "-q", "-b", "main")
git_q("-C", tmpA, "config", "user.email", "a@example.com")
git_q("-C", tmpA, "config", "user.name", "Author A")
vault_commit("Initial", vault = tmpA, push = FALSE)
git_q("-C", tmpA, "remote", "add", "origin", bare)
git_q("-C", tmpA, "push", "-q", "-u", "origin", "main")

tmpB <- file.path(tempdir(), paste0("merge-b-", stamp))
git_q("clone", "-q", bare, tmpB)
git_q("-C", tmpB, "config", "user.email", "b@example.com")
git_q("-C", tmpB, "config", "user.name", "Author B")

# A appends X and Y; B appends only X: B's version is a strict
# subsequence of A's, so A's wins with nothing to synthesize.
cat("Line X.\nLine Y.\n", file = file.path(tmpA, "wiki", "topic.md"),
    append = TRUE)
vault_commit("A appends X and Y", vault = tmpA, push = TRUE)
cat("Line X.\n", file = file.path(tmpB, "wiki", "topic.md"),
    append = TRUE)
vault_commit("B appends X", vault = tmpB, push = TRUE)

remote_topic <- system2("git", c("-C", bare, "show", "main:wiki/topic.md"),
                        stdout = TRUE, stderr = FALSE)
expect_true(any(grepl("Line Y", remote_topic)))
remote_files <- system2("git",
                        c("-C", bare, "ls-tree", "-r", "main", "--name-only"),
                        stdout = TRUE, stderr = FALSE)
expect_false(".pensar/merge-conflicts.md" %in% remote_files)
expect_false(pensar:::rebase_in_progress(tmpB))
status_b <- system2("git", c("-C", tmpB, "status", "--porcelain"),
                    stdout = TRUE, stderr = FALSE)
expect_equal(length(status_b), 0L)

# --- E2E: raw add/add collision keeps both files, re-keys manifest ---
# Same source ingested on both clones the same day produces the same
# slug with different content.
ingest("Version A of gamma.", type = "articles", source = "gamma",
       vault = tmpA)
ingest("Version B of gamma.", type = "articles", source = "gamma",
       vault = tmpB)

remote_files <- system2("git",
                        c("-C", bare, "ls-tree", "-r", "main", "--name-only"),
                        stdout = TRUE, stderr = FALSE)
gamma_files <- grep("raw/articles/.*gamma.*\\.md$", remote_files,
                    value = TRUE)
expect_equal(length(gamma_files), 2L)
gamma_orig <- grep("-2\\.md$", gamma_files, invert = TRUE, value = TRUE)
gamma_renamed <- grep("-2\\.md$", gamma_files, value = TRUE)
expect_equal(length(gamma_renamed), 1L)
orig_content <- system2("git",
                        c("-C", bare, "show",
                          paste0("main:", gamma_orig)),
                        stdout = TRUE, stderr = FALSE)
renamed_content <- system2("git",
                           c("-C", bare, "show",
                             paste0("main:", gamma_renamed)),
                           stdout = TRUE, stderr = FALSE)
expect_true(any(grepl("Version A", orig_content)))
expect_true(any(grepl("Version B", renamed_content)))
# Manifest carries provenance for both paths
remote_man <- system2("git",
                      c("-C", bare, "show", "main:.pensar/manifest.yml"),
                      stdout = TRUE, stderr = FALSE)
expect_true(any(grepl(basename(gamma_orig), remote_man)))
expect_true(any(grepl(basename(gamma_renamed), remote_man)))
# Digest notes the collision
remote_digest <- system2("git",
                         c("-C", bare, "show",
                           "main:.pensar/merge-conflicts.md"),
                         stdout = TRUE, stderr = FALSE)
expect_true(any(grepl("raw-collision", remote_digest)))
expect_false(pensar:::rebase_in_progress(tmpB))

unlink(c(tmpA, tmpB, bare), recursive = TRUE)

# --- E2E: vault_merge() resolves a stopped `git merge` ---
tmpM <- file.path(tempdir(), paste0("merge-m-", stamp))
init_vault(tmpM)
writeLines(c("---", "title: Page", "---", "", "Base."),
           file.path(tmpM, "wiki", "page.md"))
git_q("-C", tmpM, "init", "-q", "-b", "main")
git_q("-C", tmpM, "config", "user.email", "m@example.com")
git_q("-C", tmpM, "config", "user.name", "Author M")
vault_commit("Initial", vault = tmpM, push = FALSE)

git_q("-C", tmpM, "checkout", "-q", "-b", "b1")
writeLines(c("---", "title: Page", "---", "", "Branch take."),
           file.path(tmpM, "wiki", "page.md"))
vault_commit("Branch edit", vault = tmpM, push = FALSE)
git_q("-C", tmpM, "checkout", "-q", "main")
writeLines(c("---", "title: Page", "---", "", "Main take."),
           file.path(tmpM, "wiki", "page.md"))
vault_commit("Main edit", vault = tmpM, push = FALSE)

merge_status <- git_q("-C", tmpM, "merge", "b1")
expect_true(merge_status != 0L)
expect_true(file.exists(file.path(tmpM, ".git", "MERGE_HEAD")))

res <- suppressMessages(vault_merge(tmpM))
expect_true(is.data.frame(res))
expect_true("wiki/page.md" %in% res$path)
expect_equal(res$class[res$path == "wiki/page.md"], "prose-divergence")
# Merge is committed, vault clean, ours (main) kept
expect_false(file.exists(file.path(tmpM, ".git", "MERGE_HEAD")))
page_now <- readLines(file.path(tmpM, "wiki", "page.md"))
expect_true(any(grepl("Main take", page_now)))
digest_now <- readLines(file.path(tmpM, ".pensar", "merge-conflicts.md"))
expect_true(any(grepl("Branch take", digest_now)))
status_m <- system2("git", c("-C", tmpM, "status", "--porcelain"),
                    stdout = TRUE, stderr = FALSE)
expect_equal(length(status_m), 0L)

# --- vault_merge() with nothing stopped returns NULL ---
expect_null(suppressMessages(vault_merge(tmpM)))

unlink(tmpM, recursive = TRUE)

if (is.na(old_push_env)) {
    Sys.unsetenv("PENSAR_AUTO_PUSH")
} else {
    Sys.setenv(PENSAR_AUTO_PUSH = old_push_env)
}
