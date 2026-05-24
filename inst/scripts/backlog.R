#!/usr/bin/env r
# Full synthesis backlog (raw orphans), no truncation
lr <- pensar::lint()
if (length(lr$raw_orphans) == 0L) {
    cat("Synthesis backlog: empty\n")
} else {
    cat(sprintf("Synthesis backlog (%d raw pages):\n", length(lr$raw_orphans)))
    for (o in lr$raw_orphans) {
        cat("  -", o, "\n")
    }
}
