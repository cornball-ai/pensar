#!/usr/bin/env r
# Show backlinks for a page
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
    message("Usage: pensar back \"<page>\"")
    quit(status = 1L)
}
bl <- pensar::backlinks(args[[1L]])
if (nrow(bl) == 0L) {
    cat("No backlinks for:", args[[1L]], "\n")
} else {
    cat(sprintf("Backlinks to %s (%d):\n", args[[1L]], nrow(bl)))
    for (i in seq_len(nrow(bl))) {
        cat(sprintf("  <- [[%s]] (%s)\n", bl$source[i], bl$file[i]))
    }
}
