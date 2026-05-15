## Submission summary

pensar 0.5.0 follows 0.4.2 on CRAN. It folds in the 0.4.3 macOS
idempotency fix (never submitted) and the new repo-ingest workflow.

The package still ships with a single hard dependency (`yaml`); `saber`
remains in `Suggests` and every call site is guarded by
`requireNamespace("saber", quietly = TRUE)` or
`getExportedValue("saber", ...)`, so optional features degrade
gracefully when `saber` is absent.

## Changes since 0.4.2

### 0.5.0 -- repo-aware ingest and provenance

- New `ingest_repo(path)` writes per-repo provenance under
  `raw/repos/<repo>/`: `briefing.md` (via `saber::briefing()`),
  `ast.md` (via `saber::symbols()`), and `snapshot.md` (commit-pinned
  git metadata: SHA, origin URL, branch, tracked file listing). Wiki
  pages cite them with path-style wikilinks like
  `[[corteza/briefing]]`.
- `name_from_path()` is now path-aware: files under
  `raw/repos/<repo>/` resolve to `<repo>/<basename>`, so identically
  named artifacts (`briefing.md`) across different repos no longer
  collide. Files outside `raw/repos/` are unchanged.
- `update_index()` reports a new `Raw: Repos` category.
- `ingest_briefing()` is deprecated; calls warn and delegate to
  `ingest_repo(path, artifacts = "briefing")`.
- New `migrate_briefings_to_repos(vault, dry_run = TRUE)` moves legacy
  `raw/briefings/*.md` content into the new layout. Defaults to
  dry-run; review the plan before applying.
- Schema doc updated to describe the new layout and mark
  `briefings/` deprecated.

### 0.4.3 -- macOS idempotency fix (rolled into 0.5.0)

- `vault_export()` returns a canonicalized `out_dir` so the path is
  stable across repeated calls. On macOS `tempdir()` lives under
  `/var/...` which is a symlink to `/private/var/...`;
  `normalizePath()` only resolves symlinks for existing paths, so the
  first call returned the unresolved form and the second the resolved
  form, breaking idempotency. Re-normalizing after `dir.create()`
  fixes the M1mac CRAN check failure reported against 0.4.2.

## Test environments

- Local: Ubuntu 24.04 LTS, R 4.6.0
- Local: Windows 10, R 4.6.0 (release) and R-devel (r90050)
- GitHub Actions via r-ci: ubuntu-latest, macos-latest

## R CMD check results

- 0 errors
- 0 warnings
- 0 notes on all environments (against current CRAN `saber` 0.3.0;
  the one repo-ingest test that needs newer `saber` is guarded by
  `packageVersion("saber") < "0.6.0"` and skips cleanly)

## Downstream dependencies

None on CRAN. Verified via
`tools::package_dependencies("pensar", reverse = TRUE)`.

## Notes for reviewers

### System requirements

`SystemRequirements: pandoc (for vault_export()), git (for
vault_commit())`. Both are checked at runtime via `Sys.which()`;
`vault_commit()` is a no-op when git is not available, and
`vault_export()` errors with a clear message asking the user to
install pandoc.

### Imports / Suggests

- `Imports`: `yaml` (CRAN).
- `Suggests`: `saber` (CRAN) and `tinytest` (CRAN). `saber` is used
  by `ingest_briefing()`, `ingest_repo()`, and `vault_graph()`,
  always behind `requireNamespace()` or `getExportedValue()` so
  optional features degrade gracefully.

### Writes to the home filespace

Unchanged from 0.4.2: `default_vault()` and `default_site_dir()` are
strict opt-in resolvers (env var, walk-up `schema.md`, or
`options("pensar.vault")` set by `use_vault()`); both error if no
opt-in path is configured. No package code writes to the home
filespace by default, and examples/tests write only to `tempfile()` /
`tempdir()` with cleanup.

### Non-interactive guard

No `.onLoad` or `.onAttach` hooks; no file-system writes at load
time; no network activity at load time.
