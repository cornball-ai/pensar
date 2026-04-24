# Tests for ingest_briefing.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-brief-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Project inference fails in a non-git directory -> clear error.
# tinytest resets cwd between top-level expressions, so the setwd() and
# the call under test have to live inside a single expression.
nongit <- file.path(tempdir(), paste0("nongit-", format(Sys.time(), "%H%M%S")))
dir.create(nongit)

call_from_nongit <- function() {
    old <- setwd(nongit)
    on.exit(setwd(old))
    ingest_briefing(vault = tmp)
}

if (requireNamespace("saber", quietly = TRUE)) {
    expect_error(call_from_nongit(), "Could not infer project")
} else {
    expect_error(call_from_nongit(), "saber")
}

# With an explicit project name, saber must be available to succeed.
# Only run the full happy path when saber is installed and we're at_home.
if (tinytest::at_home() && requireNamespace("saber", quietly = TRUE)) {
    fp <- ingest_briefing(project = "pensar", vault = tmp)
    expect_true(file.exists(fp))
    expect_true(grepl("raw/briefings", fp))
    fm <- pensar:::parse_frontmatter(fp)
    expect_equal(fm$type, "briefings")
    expect_equal(fm$source, "pensar")
}
