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

unlink(c(tmp, tmp2), recursive = TRUE)
