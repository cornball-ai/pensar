#!/usr/bin/env r
# Export the vault to static HTML
args <- if (exists("argv")) argv else commandArgs(trailingOnly = TRUE)
if (length(args) > 0L) {
    pensar::vault_export(out_dir = args[[1L]])
} else {
    pensar::vault_export()
}
