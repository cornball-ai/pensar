#!/usr/bin/env r
# Show a page with its outlinks and backlinks
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
    message("Usage: pensar show \"<page>\"")
    quit(status = 1L)
}
print(pensar::show_page(args[[1L]]))
