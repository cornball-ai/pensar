#!/usr/bin/env r
# Commit vault changes to git (and push if remotes exist)
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
msg <- if (length(args) > 0L) {
    paste(args, collapse = " ")
} else {
    "Manual commit"
}
result <- pensar::vault_commit(msg)
if (isTRUE(result)) {
    cat("Committed:", msg, "\n")
} else {
    cat("Nothing to commit (no changes, or vault is not a git repo).\n")
}
