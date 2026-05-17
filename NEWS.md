# pensar 0.5.0.3

* New `vault_registry(vault, cache, refresh)` exported. Builds a
  data.frame with one row per page in the vault: `path`, `node_id` (the
  current link-resolution identity), `page_uid` (stable identity from
  frontmatter `id:`/`address:`, `NA` otherwise), `title`, `aliases`,
  `type`, `tags`, `sources`, `links_out`, `system_file`. Caches in a
  session env by default; `cache = "user"` persists to
  `tools::R_user_dir("pensar", "cache")`. Never writes inside the vault
  itself - `.pensar/` is reserved for vault-owned state.
* `find_page()` (used by `outlinks()` and other link callers) now
  resolves through the registry. New order: exact path → `page_uid` →
  unique `node_id` → ambiguous-basename warning + first-sorted →
  frontmatter alias. Preserves today's behavior for unique basenames;
  warns where today it would silently pick one of several pages with
  the same basename.
* New Import: `digest` (used internally to hash vault paths for cache
  keys).

# pensar 0.5.0.2

* `init_vault()` now refuses to scaffold into directories that already
  contain non-pensar files or a foreign git history. Pass `adopt = TRUE`
  to use the directory in (forthcoming) read-only adopt mode, or
  `force = TRUE` to scaffold anyway. The auto-commit step is gated
  separately by a new `commit` parameter (default `NULL`): commits only
  when the directory was pensar-owned before the scaffold, never as a
  side effect of `force = TRUE`. Fixes a destructive default where
  pointing `init_vault()` at someone else's git repo would write
  scaffolding and an auto-commit into their history. The `adopt`
  parameter is plumbed for the upcoming read-only adopt mode.

# pensar 0.5.0.1

* Walk-up vault discovery now also checks `<dir>/vault/schema.md` at
  each rung, so running pensar from a project root whose vault lives
  one level down (e.g., `cornelius/vault/`) resolves correctly. The
  current directory's own `schema.md` still wins at each rung.
* `status()` now records the resolver source on the returned
  `pensar_status` object (`$source` is one of `"env"`, `"walkup"`,
  `"walkup-subdir"`, `"option"`, `"explicit"`) and surfaces it in the
  print method, e.g. `Vault status: /path (via ./vault walk-up)`.
  Makes "which vault did I just get?" answerable from the output
  alone on multi-vault setups.

# pensar 0.5.0

* New `ingest_repo(path)` writes per-repo provenance under
  `raw/repos/<repo>/`: `briefing.md` (saber digest), `ast.md`
  (`saber::symbols()` output), and `snapshot.md` (commit-pinned
  metadata: SHA, origin URL, branch, tracked file listing). Wiki
  pages cite them with path-style wikilinks like
  `[[corteza/briefing]]`.
* `name_from_path()` is now path-aware: files under
  `raw/repos/<repo>/` resolve to `<repo>/<basename>`, so artifacts
  named `briefing.md` across different repos do not collide. Files
  outside `raw/repos/` are unchanged.
* `update_index()` reports a new `Raw: Repos` category.
* `ingest_briefing()` is deprecated; calls now warn and delegate to
  `ingest_repo(path, artifacts = "briefing")`.
* New `migrate_briefings_to_repos(vault, dry_run = TRUE)` moves
  legacy `raw/briefings/*.md` content into `raw/repos/<repo>/`. Keeps
  the newest file per `(repo, artifact)` pair, drops superseded
  duplicates by default, rewrites wikilinks across `wiki/*.md`. The
  built-in rename map handles `llamaR -> corteza`; pass an extended
  map for other renames. Defaults to dry-run; review the plan first.
* Schema doc updated to describe the `raw/repos/<repo>/<artifact>`
  layout and mark `briefings/` deprecated.

# pensar 0.4.3

* `vault_export()` returns a canonicalized `out_dir` so the path is
  stable across calls. On macOS `tempdir()` lives under `/var/...`
  which is a symlink to `/private/var/...`; `normalizePath()` only
  resolves symlinks for paths that exist, so the first call returned
  the unresolved form and the second returned the resolved form,
  breaking idempotency. Re-normalizing after `dir.create()` fixes
  the M1mac CRAN check failure.

# pensar 0.4.2

* CRAN review compliance.
* `default_vault()` and `default_site_dir()` no longer fall back to
  `tools::R_user_dir()`. Per CRAN policy pensar will not silently
  write to the user's home filespace; if no vault is configured via
  `PENSAR_VAULT`, walk-up `schema.md`, or `options("pensar.vault")`,
  the call errors with a setup hint. Pass `vault =` (or `path =` for
  `init_vault()`) explicitly to write to a one-off path. **Breaking
  for users who relied on the implicit `~/.local/share/R/pensar/`
  fallback** -- run `use_vault('/path/to/vault')` once or set
  `PENSAR_VAULT` to restore the previous behavior.
* `vault_export()` now requires either `PENSAR_SITE_DIR` or an
  explicit `out_dir =`; the cache fallback is gone for the same
  reason.
* Title shortened to `LLM Wiki Engine`. Description tidied. Added
  `SystemRequirements: pandoc, git`. Dropped unused `jsonlite` from
  Suggests.
* Every exported function now has a runnable `@examples` block,
  using `tempdir()` / `tempfile()` so nothing leaks into the user's
  home filespace at example time.
* `vault_graph()` and `ingest_briefing()` error messages reworded
  to drop the GitHub install URL.

# pensar 0.4.1

* `default_vault()` resolution order changed so project-local vaults
  beat a global `.Rprofile` default. New order: `PENSAR_VAULT` env
  var > walk-up from `getwd()` for a `schema.md` marker > the
  `options("pensar.vault")` value set by `use_vault()` > the
  `R_user_dir()` fallback. Previously the option won over the env
  var, which made `PENSAR_VAULT=...` ineffective once `use_vault()`
  ran in `.Rprofile`. Walk-up is new: `cd` into a project vault and
  the CLI Just Works without unsetting your global default.

# pensar 0.4.0

* New `vault_graph()` renders the vault's wikilink graph as static
  SVG via `saber::graph_svg()`. Tooltips carry title, type, date,
  tags, and a lede from the first meaningful body line. Broken
  wikilinks appear as separate nodes. Default viewport 1600x1200 for
  denser vaults.

# pensar 0.3.1

* `default_vault()` now honors `options("pensar.vault")` and the
  `PENSAR_VAULT` environment variable before falling back to
  `tools::R_user_dir("pensar", "data")`. Previously, the vault path
  was hardcoded to the `R_user_dir()` path with no escape hatch, so
  a nicer path like `~/wiki` required passing `vault =` to every
  call.
* New `use_vault()` sets `options("pensar.vault")` for the session,
  mirroring `hacer::use_repo()`.

# pensar 0.3.0

* New `ingest_briefing()` generates a saber briefing via
  `saber::briefing()` and ingests it into the vault. Replaces the
  direct cache-file read in `inst/scripts/session-start.R` with a real
  function call, so briefings refresh on ingest instead of depending
  on saber's hook having run first.
* `saber` added to Suggests (previously coupled only via filesystem).

# pensar 0.2.0

* Initial release: LLM wiki engine with `init_vault()`, `ingest()`,
  `update_index()`, `log_entry()`, `status()`, `backlinks()`,
  `outlinks()`, `show_page()`, `lint()`, and `vault_export()`.
