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
