#!/usr/bin/env r
# Export the vault to static HTML
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) > 0L) {
    args[[1L]]
} else {
    file.path(pensar:::default_vault(), "_site")
}
pensar::vault_export(out_dir = out_dir)
