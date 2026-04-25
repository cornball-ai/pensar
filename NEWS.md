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
