# Tests for git.R (vault_commit)

library(pensar)

if (nchar(Sys.which("git")) == 0L) {
    exit_file("git not available")
}

# --- No-op when vault is not a git repo ---
tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)
# init_vault() should not have committed anything (no .git)
result <- vault_commit("test", vault = tmp)
expect_false(result)

# --- Works when vault is a git repo ---
tmp2 <- file.path(tempdir(),
                  paste0("vault-git-", format(Sys.time(), "%H%M%S")))
init_vault(tmp2)
# init a git repo AFTER the vault
system2("git", c("-C", tmp2, "init", "-q"))
system2("git", c("-C", tmp2, "config", "user.email", "test@example.com"))
system2("git", c("-C", tmp2, "config", "user.name", "Test"))

# First commit: vault files
r <- vault_commit("Initial", vault = tmp2, push = FALSE)
expect_true(r)

# Second call: no changes
r2 <- vault_commit("Nothing to commit", vault = tmp2, push = FALSE)
expect_false(r2)

# Add a wiki page, commit it
writeLines(c("---", "title: Test", "---", "Content."),
           file.path(tmp2, "wiki", "test.md"))
r3 <- vault_commit("Added test page", vault = tmp2, push = FALSE)
expect_true(r3)

# Log has entries
log_out <- system2("git", c("-C", tmp2, "log", "--oneline"),
                   stdout = TRUE)
expect_true(length(log_out) >= 2L)
expect_true(any(grepl("Added test page", log_out)))

# --- should_push honors the env var ---
old <- Sys.getenv("PENSAR_AUTO_PUSH", unset = NA)
Sys.setenv(PENSAR_AUTO_PUSH = "false")
expect_false(pensar:::should_push(NULL))
Sys.setenv(PENSAR_AUTO_PUSH = "true")
expect_true(pensar:::should_push(NULL))
Sys.setenv(PENSAR_AUTO_PUSH = "0")
expect_false(pensar:::should_push(NULL))
# Explicit overrides env
expect_true(pensar:::should_push(TRUE))
expect_false(pensar:::should_push(FALSE))
if (is.na(old)) {
    Sys.unsetenv("PENSAR_AUTO_PUSH")
} else {
    Sys.setenv(PENSAR_AUTO_PUSH = old)
}

# --- init_vault scaffolds .gitattributes with union merge for log.md ---
ga <- readLines(file.path(tmp, ".gitattributes"))
expect_true("log.md merge=union" %in% ga)

# --- Diverged log appends: rejected push rebases (union) and retries ---
git_q <- function(...) {
    system2("git", c(...), stdout = FALSE, stderr = FALSE)
}
stamp <- format(Sys.time(), "%H%M%S")
bare <- file.path(tempdir(), paste0("vault-bare-", stamp, ".git"))
git_q("init", "-q", "--bare", "-b", "main", bare)

# Author A: vault + git repo pushing to the bare remote
tmpA <- file.path(tempdir(), paste0("vault-a-", stamp))
init_vault(tmpA)
git_q("-C", tmpA, "init", "-q", "-b", "main")
git_q("-C", tmpA, "config", "user.email", "a@example.com")
git_q("-C", tmpA, "config", "user.name", "Author A")
vault_commit("Initial", vault = tmpA, push = FALSE)
git_q("-C", tmpA, "remote", "add", "origin", bare)
git_q("-C", tmpA, "push", "-q", "-u", "origin", "main")

# Author B: clone of the same vault
tmpB <- file.path(tempdir(), paste0("vault-b-", stamp))
git_q("clone", "-q", bare, tmpB)
git_q("-C", tmpB, "config", "user.email", "b@example.com")
git_q("-C", tmpB, "config", "user.name", "Author B")

# Both append to log.md; A pushes first, so B's push is rejected
log_entry("Entry from A", operation = "test", vault = tmpA)
vault_commit("A appends", vault = tmpA, push = TRUE)
log_entry("Entry from B", operation = "test", vault = tmpB)
r_b <- vault_commit("B appends", vault = tmpB, push = TRUE)
expect_true(r_b)

# B's push went through after the auto-rebase: remote log.md has both
remote_log <- system2("git", c("-C", bare, "show", "main:log.md"),
                      stdout = TRUE, stderr = FALSE)
expect_true(any(grepl("Entry from A", remote_log)))
expect_true(any(grepl("Entry from B", remote_log)))

# B's clone is clean and not mid-rebase
expect_false(dir.exists(file.path(tmpB, ".git", "rebase-merge")))
expect_false(dir.exists(file.path(tmpB, ".git", "rebase-apply")))
status_b <- system2("git", c("-C", tmpB, "status", "--porcelain"),
                    stdout = TRUE, stderr = FALSE)
expect_equal(length(status_b), 0L)

unlink(c(tmp, tmp2, tmpA, tmpB, bare), recursive = TRUE)
