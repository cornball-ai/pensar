#!/usr/bin/env r
# Show last n log entries
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
n <- if (length(args) > 0L) as.integer(args[[1L]]) else 10L
vault <- pensar:::default_vault()
log_path <- file.path(vault, "log.md")
if (!file.exists(log_path)) {
    message("No log.md in vault: ", vault)
    quit(status = 1L)
}
lines <- readLines(log_path, warn = FALSE)
entries <- lines[grepl("^- \\*\\*", lines)]
if (length(entries) == 0L) {
    cat("No log entries.\n")
} else {
    tail_entries <- utils::tail(entries, n)
    cat(tail_entries, sep = "\n")
    cat("\n")
}
