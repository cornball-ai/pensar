#!/usr/bin/env r
# List pages with a given tag
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
    message("Usage: pensar tag <tag>")
    quit(status = 1L)
}
target_tag <- args[[1L]]
vault <- pensar:::default_vault()
all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                     full.names = TRUE)
control <- c("index.md", "log.md", "schema.md")
all_md <- all_md[!basename(all_md) %in% control |
    dirname(all_md) != vault]

matches <- character(0L)
for (fp in all_md) {
    fm <- pensar:::parse_frontmatter(fp)
    if (!is.null(fm$tags) && target_tag %in% fm$tags) {
        rel <- sub(paste0(vault, "/"), "", fp, fixed = TRUE)
        matches <- c(matches, rel)
    }
}
if (length(matches) == 0L) {
    cat("No pages with tag:", target_tag, "\n")
} else {
    cat(sprintf("Pages tagged '%s' (%d):\n", target_tag, length(matches)))
    for (m in sort(matches)) cat("  -", m, "\n")
}
