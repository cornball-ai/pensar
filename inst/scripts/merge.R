#!/usr/bin/env r
# Resolve a stopped git merge/rebase in the vault mechanically.
# Genuine divergence lands in .pensar/merge-conflicts.md for synthesis.
res <- pensar::vault_merge()
if (!is.null(res) && nrow(res) > 0L) {
    cat(sprintf("%-18s %-16s %s\n", "class", "kept", "path"))
    for (i in seq_len(nrow(res))) {
        cat(sprintf("%-18s %-16s %s\n", res$class[i], res$kept[i],
                    res$path[i]))
    }
}
