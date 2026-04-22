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
