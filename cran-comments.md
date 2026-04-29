## Submission summary

This is a resubmission of pensar (now 0.4.2) addressing the three
points from Konstanze Lauseker's review of 0.4.0 / 0.4.1.

## Changes addressing reviewer feedback

### 1. Title

> please omit the single quotes around LLM and frontmatter and the
> "for R" from the title.

`Title:` is now `LLM Wiki Engine`. The Description text also drops
the single quotes around `frontmatter` and `wikilinks`. `'YAML'` is
kept single-quoted as a serialization-format name.

### 2. Examples in Rd files

> Please add small executable examples in your Rd-files to
> illustrate the use of the exported function but also enable
> automatic testing.

Every exported function now has a runnable `\examples{}` block.
Examples write only to `tempfile()` / `tempdir()` and clean up with
`unlink(..., recursive = TRUE)`. The three exceptions wrapped in
`\dontrun{}` and the reason for each:

- `ingest_briefing()` -- needs the `saber` package and a git project
  context so a briefing can be generated.
- `vault_export()` -- shells out to `pandoc`, which is declared in
  `SystemRequirements:` but not guaranteed to be present in the
  CRAN check environment.
- `vault_graph()` -- needs a version of `saber` that exports
  `graph_svg()`. The function probes for it via `getExportedValue()`
  and errors gracefully when the symbol is absent.

### 3. No writes to the home filespace by default

> Please ensure that your functions do not write by default or in
> your examples/vignettes/tests in the user's home filespace
> (including the package directory and getwd())... Please omit any
> default path in writing functions.

`default_vault()` and `default_site_dir()` no longer fall back to
`tools::R_user_dir()`. Both are now strict opt-in resolvers:

- `default_vault()` resolves via `PENSAR_VAULT` (env), walk-up from
  `getwd()` for a `schema.md` marker, then `options("pensar.vault")`
  set by `use_vault()`. If none of those is configured, it errors
  with a setup hint listing the four ways to point pensar at a
  vault. There is no implicit home-filespace fallback.
- `default_site_dir()` resolves via `PENSAR_SITE_DIR` only and
  errors otherwise. Callers must pass `out_dir =` explicitly.

`init_vault()` and `vault_export()` accept an explicit path and
otherwise propagate the `default_vault()` / `default_site_dir()`
error -- so calling them with no arguments and no opt-in
configuration produces an error before any write happens.

`inst/scripts/session-start.R` (a saber session-start hook) was
updated to drop its hardcoded `tools::R_user_dir(...)` write; it now
delegates entirely to `ingest_briefing()` and exits cleanly when no
vault is configured.

Tests already wrote only to `tempfile()` / `tempdir()` and clean up
with `unlink(..., recursive = TRUE)`; this hasn't changed.

## R CMD check results

- 0 errors
- 0 warnings
- 1 NOTE expected ("Days since last update", as a resubmission)

## Notes for reviewers

### System requirements

`SystemRequirements: pandoc (for vault_export()), git (for
vault_commit())`. Both are checked at runtime via `Sys.which()`;
`vault_commit()` is a no-op when git is not available, and
`vault_export()` errors with a clear message asking the user to
install pandoc.

### Imports

Only `yaml`, which is on CRAN.

### Suggests

- `saber` -- on CRAN. Used by `ingest_briefing()` and `vault_graph()`,
  guarded by `requireNamespace("saber", quietly = TRUE)` and
  `getExportedValue("saber", ...)` so optional features degrade
  gracefully.
- `tinytest` -- on CRAN. Test framework.

### Non-interactive guard

No package code runs during `library(pensar)` that could surprise a
user. There are no `.onLoad` or `.onAttach` hooks; no file-system
writes at load time; no network activity at load time.
