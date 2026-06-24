## Submission summary

pensar 0.6.4 is a feature and bug-fix update to 0.6.3 (on CRAN since
2026-05-19). It exports one new function, adds incremental static-site
exports, and improves vault linting and backlog reporting. No exported
object was removed and no exported signature changed, so the update is
backward compatible.

## Changes since 0.6.3

### New features

- `default_vault()` is now exported: a public getter for the active
  vault path, paired with the existing `use_vault()` setter, so callers
  can confirm which vault `ingest()` / `status()` will act on without
  reaching into the package namespace.

### Changes

- `vault_export()` is incremental: subsequent exports re-render only
  pages whose source (or whose wikilink targets) changed, with state in
  `.pensar-export-cache.yml` in the output directory.
- `lint()` scopes broken-link checks to `wiki/` pages and surfaces a
  separate `$raw_orphans` synthesis backlog; a `.pensarignore` file
  filters that backlog.

### Bug fixes

- `autoresearch()` no longer errors when a search query returns zero
  results.
- Wikilink parsing now ignores Markdown code, so `[[ ]]` list indexing
  in a code sample no longer registers as a broken wikilink.

## Test environments

- Local: Ubuntu 24.04 LTS, R 4.6.0
- win-builder: R-devel and R-release
- GitHub Actions via r-ci: ubuntu-latest, macos-latest

## R CMD check results

0 errors | 0 warnings | 0 notes.

## Reverse dependencies

None on CRAN. Verified via
`tools::package_dependencies("pensar", reverse = TRUE)`.

## Notes for reviewers

- `Imports`: curl, digest, stringdist, yaml (all CRAN).
- `Suggests`: jsonlite, llm.api, saber, simplermarkdown, tinytest (all
  CRAN). Each is used behind `requireNamespace()` /
  `getExportedValue()`, so optional features degrade gracefully when a
  suggested package is absent.
- `default_vault()` and `default_site_dir()` remain strict opt-in
  resolvers (the `PENSAR_VAULT` environment variable, a walk-up for
  `schema.md`, or `options("pensar.vault")` set by `use_vault()`); both
  error if no opt-in path is configured. No package code writes to the
  home filespace by default, and examples and tests write only to
  `tempfile()` / `tempdir()` with cleanup.
- No `.onLoad` / `.onAttach` hooks; no file-system writes and no network
  activity at load time.
- `SystemRequirements`: pandoc (for `vault_export()`), git (for
  `vault_commit()`); both are checked at runtime via `Sys.which()`.
  `vault_commit()` is a no-op when git is unavailable; `vault_export()`
  errors with a clear message when pandoc is unavailable.
