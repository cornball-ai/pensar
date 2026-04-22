## Submission summary

This is the first CRAN submission of 'pensar' (v0.4.0), a markdown-first
knowledge-base engine designed for large language model (LLM) agents
to curate over time. Humans point pensar at source documents (articles,
chat logs, briefings); the vault is a folder of `.md` files with YAML
frontmatter and 'Obsidian'-inspired `[[wikilinks]]`, maintained in
place by the agent.

## R CMD check results

- 0 errors
- 0 warnings
- 1 NOTE ("New submission") — expected on a first submission

## Notes for reviewers

### Filesystem policy

The package never writes to `~/.pensar/` or any hardcoded user-home
path. `default_vault()` resolves its path in this order:

1. `options("pensar.vault")` if set.
2. `Sys.getenv("PENSAR_VAULT")` if set.
3. `tools::R_user_dir("pensar", "data")` as a final fallback.

Directories are created only when the user explicitly invokes a
function that persists state (`init_vault()`, `ingest()`, `vault_export()`).
Nothing writes at load time. Tests and examples write only to
`tempfile()` / `tempdir()` locations.

### vault_export default paths

`vault_export(out_dir = default_site_dir())` defaults to
`tools::R_user_dir("pensar", "cache")` so that exported HTML sites
land in the per-user cache directory rather than the working directory.
Callers may override by passing `out_dir` explicitly.

### Non-interactive guard

No package code runs during `library(pensar)` that could surprise a
user. There are no `.onLoad` or `.onAttach` hooks; no file-system
writes at load time; no network activity at load time.

### Imports

Only `yaml`, which is on CRAN.

### Suggests

- `jsonlite` — on CRAN. Used by `ingest()` when parsing JSON exports.
- `saber` — on CRAN. Used by `ingest_briefing()` and `vault_graph()`.
  All saber references are guarded by `requireNamespace("saber",
  quietly = TRUE)`.
- `tinytest` — on CRAN. Test framework.

### Examples

All exported functions have `@examples` blocks. Examples that mutate
user state (vault creation, ingestion) use `tempdir()` and clean up.
No example writes outside `tempfile()` / `tempdir()`. No example
requires network access or external credentials.

### Pandoc dependency

`vault_export()` shells out to Pandoc to render markdown to HTML.
`check_pandoc()` inspects `Sys.which("pandoc")` up front and errors
with a helpful message if Pandoc isn't installed. Pandoc is listed in
`SystemRequirements` in DESCRIPTION.
