# Tests for nested vaults: a pensar vault inside a larger git repo.

library(pensar)

if (nchar(Sys.which("git")) == 0L) {
    exit_file("git not available")
}

git_q <- function(...) {
    system2("git", c(...), stdout = FALSE, stderr = FALSE)
}
git_out <- function(...) {
    suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = FALSE))
}
stamp <- format(Sys.time(), "%H%M%OS3")
old_push_env <- Sys.getenv("PENSAR_AUTO_PUSH", unset = NA)
Sys.setenv(PENSAR_AUTO_PUSH = "true")

# --- Setup: project repo with a nested vault ---
proj <- file.path(tempdir(), paste0("proj-", stamp))
dir.create(proj)
git_q("-C", proj, "init", "-q", "-b", "main")
git_q("-C", proj, "config", "user.email", "n@example.com")
git_q("-C", proj, "config", "user.name", "Nested")
writeLines("project code", file.path(proj, "app.R"))
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("project initial"))
n_commits_before <- length(git_out("-C", proj, "log", "--oneline"))

nv <- file.path(proj, "vault")
init_vault(nv, rproj = FALSE, agent_instructions = FALSE)

# Detection helpers see the enclosing repo
expect_true(pensar:::vault_is_nested(nv))
expect_equal(pensar:::vault_git_prefix(nv), "vault/")
expect_equal(normalizePath(pensar:::vault_repo_root(nv)),
             normalizePath(proj))

# init_vault did NOT auto-commit into the project's history
n_commits_after <- length(git_out("-C", proj, "log", "--oneline"))
expect_equal(n_commits_after, n_commits_before)

# --- vault_commit is scoped to the vault subtree ---
# Unrelated changes elsewhere in the project: one dirty, one staged.
writeLines("edited project code", file.path(proj, "app.R"))
writeLines("staged file", file.path(proj, "staged.txt"))
git_q("-C", proj, "add", "--", "staged.txt")

r1 <- vault_commit("Vault scaffold", vault = nv, push = FALSE)
expect_true(r1)
committed <- git_out("-C", proj, "show", "--name-only", "--format=", "HEAD")
expect_true(all(startsWith(committed[nzchar(committed)], "vault/")))
# The unrelated changes are untouched: app.R still dirty, staged.txt
# still staged and uncommitted.
st <- git_out("-C", proj, "status", "--porcelain")
expect_true(any(grepl("^ M app.R", st)))
expect_true(any(grepl("^A  staged.txt", st)))

# No vault changes: FALSE even though the project tree is dirty
r2 <- vault_commit("Nothing in vault", vault = nv, push = FALSE)
expect_false(r2)

# --- Nested vaults never auto-push; explicit push = TRUE does ---
bare <- file.path(tempdir(), paste0("proj-bare-", stamp, ".git"))
git_q("init", "-q", "--bare", "-b", "main", bare)
git_q("-C", proj, "remote", "add", "origin", bare)
git_q("-C", proj, "push", "-q", "-u", "origin", "main")
remote_head <- git_out("-C", bare, "rev-parse", "main")

writeLines(c("---", "title: Note", "---", "", "Body."),
           file.path(nv, "wiki", "note.md"))
# PENSAR_AUTO_PUSH=true is ignored for nested vaults
r3 <- vault_commit("Add note", vault = nv)
expect_true(r3)
expect_equal(git_out("-C", bare, "rev-parse", "main"), remote_head)
# Explicit push = TRUE pushes the enclosing repo's branch
writeLines(c("---", "title: Note2", "---", "", "Body."),
           file.path(nv, "wiki", "note2.md"))
r4 <- vault_commit("Add note2", vault = nv, push = TRUE)
expect_true(r4)
new_remote_head <- git_out("-C", bare, "rev-parse", "main")
expect_false(identical(new_remote_head, remote_head))

# --- vault_merge resolves only vault conflicts, leaves the rest ---
# Clean up the unrelated mess first so branching is deterministic.
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("settle project state"))

writeLines(c("---", "title: Topic", "---", "", "Base."),
           file.path(nv, "wiki", "topic.md"))
writeLines("shared line", file.path(proj, "config.txt"))
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("base for branches"))

git_q("-C", proj, "checkout", "-q", "-b", "b1")
writeLines(c("---", "title: Topic", "---", "", "Branch take."),
           file.path(nv, "wiki", "topic.md"))
writeLines("branch line", file.path(proj, "config.txt"))
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("branch edits"))

git_q("-C", proj, "checkout", "-q", "main")
writeLines(c("---", "title: Topic", "---", "", "Main take."),
           file.path(nv, "wiki", "topic.md"))
writeLines("main line", file.path(proj, "config.txt"))
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("main edits"))

merge_status <- git_q("-C", proj, "merge", "b1")
expect_true(merge_status != 0L)

res <- suppressMessages(vault_merge(nv))
expect_true(is.data.frame(res))
expect_equal(res$class[res$path == "wiki/topic.md"], "prose-divergence")
# The vault conflict is resolved and staged; the merge is NOT
# completed because config.txt (outside the vault) still conflicts.
expect_true(pensar:::merge_in_progress(nv))
unmerged <- git_out("-C", proj, "diff", "--name-only", "--diff-filter=U")
expect_equal(unmerged, "config.txt")
# Vault page kept ours; digest holds the branch version
page_now <- readLines(file.path(nv, "wiki", "topic.md"))
expect_true(any(grepl("Main take", page_now)))
digest_now <- readLines(file.path(nv, ".pensar", "merge-conflicts.md"))
expect_true(any(grepl("Branch take", digest_now)))

# Human finishes the outside conflict; the merge completes normally
writeLines("merged line", file.path(proj, "config.txt"))
git_q("-C", proj, "add", "--", "config.txt")
git_q("-C", proj, "-c", "core.editor=true", "commit", "--no-edit", "-q")
expect_false(pensar:::merge_in_progress(nv))

# --- vault_merge completes a merge whose only conflicts are vault ---
git_q("-C", proj, "checkout", "-q", "-b", "b2")
writeLines(c("---", "title: Topic", "---", "", "B2 take."),
           file.path(nv, "wiki", "topic.md"))
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("b2 edit"))
git_q("-C", proj, "checkout", "-q", "main")
writeLines(c("---", "title: Topic", "---", "", "Main second take."),
           file.path(nv, "wiki", "topic.md"))
git_q("-C", proj, "add", "-A")
git_q("-C", proj, "commit", "-q", "-m", shQuote("main second edit"))
merge_status2 <- git_q("-C", proj, "merge", "b2")
expect_true(merge_status2 != 0L)

res2 <- suppressMessages(vault_merge(nv))
expect_true(is.data.frame(res2))
expect_false(pensar:::merge_in_progress(nv))
st_final <- git_out("-C", proj, "status", "--porcelain")
expect_equal(length(st_final), 0L)

if (is.na(old_push_env)) {
    Sys.unsetenv("PENSAR_AUTO_PUSH")
} else {
    Sys.setenv(PENSAR_AUTO_PUSH = old_push_env)
}
unlink(c(proj, bare), recursive = TRUE)
