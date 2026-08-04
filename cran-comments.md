## Submission summary

pensar 0.7.0 is a feature update to 0.6.4 (on CRAN since 2026-06-24).
It exports one new function, `vault_merge()`, and adds multi-author and
nested-vault support to the optional git machinery. No exported object
was removed and no exported signature changed, so the update is
backward compatible.

## Changes since 0.6.4

### New features

- Multi-author vaults: `init_vault()` scaffolds a `.gitattributes`
  marking the operation log as `merge=union`; a rejected auto-push
  retries once after `git pull --rebase`; a rebase stopped only by
  derived files (the auto-generated index and manifest) resolves
  itself by regenerating them from the merged tree.
- New `vault_merge()`: resolves a stopped git merge or rebase
  mechanically and files genuine divergence into a committed digest
  for later synthesis. The vault is never left mid-rebase.
- Nested vaults (a vault directory inside a larger git repository)
  now work with the git machinery. Staging and commits are scoped to
  the vault subtree, so a pensar commit can never sweep the enclosing
  repository; nested vaults never auto-push.
- New per-vault auto-push setting (`auto_push` in `schema.md`
  frontmatter), with precedence: explicit `push` argument, schema
  setting, `PENSAR_AUTO_PUSH` environment variable, default.

### Changes

- Documentation distinguishes private single-author vaults from
  shared multi-author vaults.

## Test environments

- Local: Ubuntu 24.04 LTS, R 4.6.1
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
  `vault_commit()` and `vault_merge()`); both are checked at runtime
  via `Sys.which()`. `vault_commit()` and `vault_merge()` are no-ops
  with a message when git is unavailable; `vault_export()` errors with
  a clear message when pandoc is unavailable. All git operations run
  through `system2()` against repositories the user opted into.
