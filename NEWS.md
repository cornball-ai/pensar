# pensar 0.6.4.3 (development)

* Multi-author third slice (#52): new `vault_merge()` (CLI:
  `pensar merge`) resolves a stopped git merge or rebase mechanically
  and files genuine divergence into a committed digest at
  `.pensar/merge-conflicts.md` for LLM synthesis. Raw add/add
  collisions keep both files (incoming renamed, manifest re-keyed);
  a strict-superset or lint-dominant wiki side wins automatically;
  prose divergence keeps the current branch's side with both full
  versions preserved in the digest. The auto-push flow uses the same
  engine, so the vault is never left mid-rebase. The convention is
  declared loudly to agents: `status()` banners pending digest
  entries, the agent-instructions template opens with a FIRST-check
  section, and `schema.md` documents the digest contract.
* Multi-author second slice (#52): a rebase stopped only by derived
  files resolves itself. `index.md` is regenerated from the merged
  tree; `.pensar/manifest.yml` is unioned by path and pruned to pages
  that survived the merge. Conflicts outside the derived set still
  abort, leaving the vault clean and the commit local.
* Multi-author first slice (#52): `init_vault()` scaffolds a
  `.gitattributes` marking `log.md` as `merge=union`, and a rejected
  auto-push now retries once after `git pull --rebase` (aborting the
  rebase on a real conflict). Concurrent log appends from two vault
  clones no longer git-conflict.

# pensar 0.6.4

## New features

* `default_vault()` is now exported: a public getter for the active
  vault path, paired with the existing `use_vault()` setter. Call it to
  confirm which vault a bare `ingest()` or `status()` will act on
  without reaching into `pensar:::` (#55).

## Changes

* `vault_export()` is now **incremental**. The first export to an
  output directory is a full build; subsequent exports re-render only
  pages whose source changed, plus any page whose wikilinks point at a
  name that was added, removed, or moved (so broken/resolved links stay
  correct). State lives in `.pensar-export-cache.yml` in the output
  directory; delete it to force a full rebuild. Editing a few pages now
  renders a handful instead of the whole vault. The stylesheet and site
  index are always regenerated (no pandoc). `vault_export()` returns the
  output path with `rendered`/`skipped` attributes.
* `lint()` now scopes broken-link checks to `wiki/` pages only. Raw
  pages are auto-ingested and immutable; scraper-artifact `[[...]]`
  was meaningless noise. Orphan detection is split: `$orphans`
  contains wiki-only orphans (the "fix me" signal), and a new
  `$raw_orphans` field surfaces raw pages with no incoming wikilinks
  as the **synthesis backlog**.
* `.pensarignore` at vault root filters paths from the synthesis
  backlog only (raw orphans + tag clusters). One glob per line,
  `#` comments, blank lines ignored. Does not affect ingest,
  indexing, broken-link checks, or the registry.
* `print.pensar_lint()` now groups output into two sections:
  "Broken wiki graph (target: zero)" and "Synthesis backlog".
* New CLI subcommand: `pensar backlog` — full unsynthesized raw
  page list, no truncation.

## Bug fixes

* Wikilink parsing now ignores Markdown code. Fenced blocks (` ``` ` or
  `~~~`) and inline spans (`` `...` ``) are stripped before extracting
  `[[...]]`, so R's `[[ ]]` list indexing in a code sample no longer
  registers as a broken wikilink. Affects `lint()`, `outlinks()`,
  `backlinks()`, and `vault_graph()`.
* `autoresearch()` no longer crashes when a search query returns zero
  results. Tagging the results with `date`, `source`, `query`, and
  `angle` assigned a length-1 value onto a 0-row data.frame and errored
  with "replacement has 1 row, data has 0". The validator now builds all
  columns at full length before filtering empty URLs, keeping `date` and
  `source` aligned when rows are dropped.

# pensar 0.6.3

## Bug fixes

* `vault_graph()`'s control-file filter now works on Windows. The
  previous implementation compared `dirname(file)` against
  `normalizePath(vault)`, but `dirname()` on Windows uses forward
  slashes in its output while `normalizePath()` defaults to
  backslashes, so the comparison was always false on Windows. Control
  files (`schema.md`, `index.md`, `log.md`) leaked into the graph,
  and the "No pages in vault" guard never fired on an empty vault.
  Now normalises `vault` with `winslash = "/"` so the comparison
  matches `dirname()`'s output on both platforms.
* `inst/tinytest/test_vault_graph.R`'s empty-vault regression test
  is now between the saber-installed and saber-`graph_svg` guards so
  it runs on machines whose saber is still at the current CRAN
  release (0.3.0). Without this, the win-builder farm was the only
  place exercising the bug.

# pensar 0.6.2

## Bug fixes

* `vault_graph()` no longer crashes on Windows.
  `category_from_path()` built a regex from the vault path; on Windows
  the backslashes were interpreted as regex backreferences, halting
  `R CMD check` on the CRAN win-builder farm with "Invalid back
  reference". The helper now strips the vault prefix by substring and
  handles both `/` and `\` separators.
* `inst/tinytest/test_vault_graph.R` had a top-of-file
  `exit_file("installed saber lacks graph_svg(); skipping")` that
  skipped the entire file when `saber` was at the current CRAN release
  (0.3.0). The `category_from_path()` regression tests are now above
  that guard so they run regardless of which saber is installed.

# pensar 0.6.1

## New features

* `autoresearch(topic, vault, ...)` runs a bounded, package-owned
  research workflow into a pensar vault. R controls the loop, source
  ingestion, wiki writes, indexing, and logging; model calls are
  limited to structured decisions returned as JSON (`plan_queries`,
  `select_sources`, `extract_claims`, `analyze_gaps`, `plan_pages`,
  `revise_page`). Multi-round gap analysis driven by
  `program$max_rounds`. Prompt-injection guards flag fetched source
  bodies. `update = TRUE` (default) preserves user prose on re-runs
  via a `revise_page` model task; the heuristic fallback appends new
  findings under a dated section so prose is never lost. Default
  search backend uses Tavily via `TAVILY_API_KEY`; default model
  backend uses `llm.api` when any of `ANTHROPIC_API_KEY`,
  `OPENAI_API_KEY`, or `MOONSHOT_API_KEY` is set, with a
  deterministic heuristic backend so the full pipeline runs without
  LLM access.
* `init_vault(path, adopt = TRUE)` adoption is now verified against
  six real Obsidian vaults via `inst/tinytest/test_adopt_real.R`
  (gated by `tinytest::at_home()` and the `PENSAR_TEST_VAULTS` env
  var). The mechanism was already covered by `test_adopt.R` against
  synthetic directories; the new test adds real-world coverage for
  `bramses-highly-opinionated-vault-2023`, `claude-obsidian`,
  `dusk-obsidian-vault`, `kepano-obsidian`,
  `Obsidian-Vault-Structure`, and `obsidian-wiki`.
* New vignette `adopt-obsidian.md` documents adopt-mode semantics
  and walks through the six-vault sweep.

## Internals

* `ingest_url()` is now layered on `fetch_url_content()` and
  `ingest_url_content()` (both internal), so the autoresearch loop
  can fetch once and keep the body in memory for evidence extraction.
* `write_wiki_page()` (internal) merges frontmatter on update instead
  of clobbering: existing `id`, `aliases`, `status`, `related`, and
  any custom keys survive an update; `tags` are set-unioned;
  caller-supplied fields replace existing values; body is always
  replaced. Refuses writes into adopted vaults unless `force = TRUE`.
  Refuses to overwrite an existing wiki file when
  `overwrite = FALSE`.
* `autoresearch()` calls `vault_commit()` after writes, matching
  `ingest()`'s pattern, so git-backed vaults stay clean.
* `extract_html_title()` handles multi-line HTML titles via PCRE.

## Skill bundle

* `inst/skills/pensar/autoresearch/SKILL.md` rewritten to route
  research requests through `autoresearch()` rather than reproducing
  a manual WebSearch/WebFetch/file-edit loop. The runtime program
  ships as machine-readable YAML at
  `inst/autoresearch/program.yml`, overridable by
  `<vault>/_research/program.yml`. Architecture note at
  `inst/autoresearch/architecture.md`.

## DESCRIPTION

* Recentered prose around personal wiki + LLM research assistant +
  manual editing. Mentions `autoresearch()`, the `'Claude Code'`
  skill bundle, the seeded `'CLAUDE.md'` / `'AGENTS.md'` files for
  `'Codex'` compatibility, and adopt mode for existing `'Obsidian'`
  vaults.
* New Suggests: `jsonlite`, `llm.api`, `simplermarkdown`. Vignette
  builder: `simplermarkdown`.

# pensar 0.6.0.1

* `ingest_agent_context()` now resolves `saber::agent_context()`
  dynamically via `getExportedValue()` instead of a static reference.
  Older saber versions (pre-0.4, including CRAN's current 0.3.0) that
  don't export `agent_context()` get a clean error message instead of
  tripping R CMD check's "Missing or unexported object" static
  analysis and failing the test suite. Test gates symmetrically so it
  exercises either the success path or the missing-export path
  depending on which saber is installed.
* `test_vault_graph` test similarly gates on
  `"graph_svg" %in% getNamespaceExports("saber")` so the suite passes
  cleanly against CRAN saber 0.3.0 (which lacks `graph_svg`).
  `vault_graph()` itself already gated its `saber::graph_svg()` call;
  only the test needed the matching guard.

# pensar 0.6.0

A foundation release that fixes a destructive bug in `init_vault()`,
introduces an adopt mode for existing Obsidian vaults, adds a
registry-based identity layer, ships per-source manifest bookkeeping,
exposes retrieval primitives, brings in URL ingest, dedup / tag
audits, an agent-context snapshot wrapper, and a markdown skill
bundle for autonomous web research.

## Safety

* `init_vault()` refuses to scaffold into directories that already
  contain non-pensar files or a foreign git history. Pass
  `adopt = TRUE` for read-only adoption (below) or `force = TRUE` to
  scaffold anyway. The auto-commit step is gated separately via a
  new `commit` parameter (default `NULL`): commits only when the
  directory was pensar-owned before scaffolding, never as a side
  effect of `force = TRUE`. Fixes a destructive default where
  pointing `init_vault()` at someone else's git repo would write
  scaffolding and an auto-commit into their history.
* The ownership heuristic requires `schema.md` as the load-bearing
  marker. Top-level `raw/` or `wiki/` directories without
  `schema.md` are treated as foreign.

## Foundation

* New `vault_registry(vault, cache, refresh)` builds a data.frame
  with one row per page: `path`, `node_id` (current link-resolution
  identity), `page_uid` (stable identity from frontmatter `id:` /
  `address:`; `NA` otherwise), `title`, `aliases`, `type`,
  `category`, `tags`, `sources`, `links_out`, `system_file`. Caches
  in a session env by default; `cache = "user"` persists to
  `tools::R_user_dir("pensar", "cache")`. Never writes inside the
  vault. Cache invalidates on rename via per-file path+mtime+size
  signature.
* `find_page()` and all its consumers (`outlinks()`, `backlinks()`,
  `lint()`) resolve through the registry: exact path → `page_uid` →
  unique `node_id` → ambiguous-basename warning → frontmatter
  alias. Path-style wikilinks (`[[Notes/Foo]]`), `.md`-suffix links,
  and `#section` / `#^block-id` anchors all resolve correctly.
  System files (`schema.md`, `index.md`, `log.md`, `_proposals/*`)
  are skipped in fuzzy resolution so user pages always win shadow
  conflicts.
* New `init_vault(adopt = TRUE)` for opt-in read-only adoption of
  existing Obsidian vaults. Writes only a minimal adopted
  `schema.md` (`adopted: true` frontmatter), `log.md`, and
  `index.md` if missing. No `raw/`/`wiki/` scaffolding, no
  auto-commit, leaves user content untouched. Pre-existing `log.md`
  is preserved. `update_index()` and `status()` switch to
  registry-driven enumeration for adopted vaults, grouping by
  frontmatter `type` (falling back to `category`). `ingest()`
  refuses to write into adopted vaults unless `force = TRUE`.
  Path-disambiguated index links (`[[A/Foo]]` / `[[B/Foo]]`) when
  basenames collide.
* New `manifest_path()`, `read_manifest()`, `update_manifest()`.
  Per-source ingest provenance plus an opt-in `address_map`. Lives
  at `.pensar/manifest.yml`. `ingest()` and `ingest_repo()` hook
  into the manifest after successful writes with a `sha1:` content
  hash. Read-only ops never touch it. Malformed sub-fields and
  per-entry records degrade safely instead of crashing.
* Read-side compatibility with `.manifest.json` and
  `.raw/.manifest.json` is deferred; would require `jsonlite` in
  Imports.

## New features

* Retrieval primitives (registry-backed, write-free):
  - `search_pages(query, vault, type, in_body)` substring-matches
    over title / tags / aliases by default; `in_body = TRUE` also
    scans page bodies. Returns a `matched_in` column. Excludes
    system control files.
  - `page_context(name, vault, body_chars)` returns a structured
    view of one page: frontmatter, body_head, outlinks, backlinks.
  - `related_pages(name, vault, k)` ranks top-k by shared tags +
    shared outlinks (canonical-path co-citation).
  - `recent_activity(vault, days)` parses `log.md`, newest first.
* New `ingest_url(url, vault, type, title, tags)` fetches via
  `curl::curl_fetch_memory()` (10s timeout, follow-redirects, TLS
  verify on). Refuses non-2xx and content types outside
  `text/html`, `text/plain`, `text/markdown`, `application/json`,
  `application/xml`, `text/xml`. HTML responses use `<title>` as
  the page title when none is supplied. Dedup against the manifest:
  same URL twice doesn't re-fetch. Skips and re-fetches when the
  recorded file has been deleted or the entry is malformed.
* New `dedup(vault, threshold)` proposes candidate duplicate pages
  by combining Jaro-Winkler title similarity (60%) and tag-set
  Jaccard overlap (40%). Writes to `_proposals/dedup.md`. Never
  auto-merges.
* New `tags(vault, taxonomy)` audits used tags against an optional
  controlled vocabulary at `_meta/taxonomy.md` (markdown bullet
  list). Unknown tags get near-miss suggestions via Jaro-Winkler.
  Writes to `_proposals/tags.md`. Never auto-renames. Explicit
  missing taxonomy path errors instead of silently degrading.
* New `ingest_agent_context(agent, vault, ...)` wraps
  `saber::agent_context()` to snapshot the live agent context
  (memory, project / global instructions, identity files) into the
  vault as a `raw/chats/` page. Saber stays in Suggests; missing
  saber errors with an install hint.

## Skills

* Pensar ships an agent skill bundle at
  `inst/skills/pensar/autoresearch/`: `SKILL.md` driving a bounded
  3-round web-research loop (decompose → search/fetch → gap fill →
  synthesize) and a configurable `references/program.md`. The loop
  files results through `ingest_url()`, dedups concepts with
  `search_pages()`, suggests cross-links via `related_pages()`, and
  refreshes the index plus log on completion.
* New `pensar_skill_path(skill = NULL)` returns the absolute path
  to the bundle root or a specific skill. Symlink it into an
  agent's skill directory:
  `ln -s $(Rscript -e 'cat(pensar::pensar_skill_path())') \`
  `~/.claude/skills/pensar`.

## Internals

* Read-only operations (`vault_registry()`, `update_index()`,
  `status()`, `backlinks()`, `outlinks()`, `lint()`,
  `search_pages()`, `page_context()`, `related_pages()`,
  `recent_activity()`) never write vault state. `.pensar/` is
  reserved for vault-owned bookkeeping; derived caches live in
  `tools::R_user_dir("pensar", "cache")`.
* `lint()` now reads tag and link data from the registry instead
  of re-parsing files, and keys tag-cluster raw pages by relative
  path so duplicate basenames in different folders no longer
  collide and undercount clusters.
* `outlinks()` surfaces ambiguous-target warnings to interactive
  callers; `backlinks()` and `lint()` continue to use a muffling
  resolver helper since they iterate.
* Walk-up vault discovery also checks `<dir>/vault/schema.md` at
  each rung, so running pensar from a project root whose vault
  lives one level down (e.g., `cornelius/vault/`) resolves
  correctly.
* `status()` records the resolver source on the returned
  `pensar_status` object (`$source` is one of `"env"`,
  `"walkup"`, `"walkup-subdir"`, `"option"`, `"explicit"`) and
  surfaces it in the print method.

## Dependencies

* New Imports: `curl` (URL ingest), `digest` (registry cache key
  + content hashes), `stringdist` (Jaro-Winkler for dedup and
  near-miss tags). `saber` remains in Suggests.

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
