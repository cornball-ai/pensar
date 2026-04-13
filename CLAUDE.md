# CLAUDE.md

## What this is

pensar ("to think") is an LLM wiki engine. It manages a persistent vault of markdown files: LLMs maintain wiki pages that synthesize and cross-reference knowledge from various sources.

You (Claude Code) are both a consumer and a maintainer of the vault. Troy curates sources and asks questions. You do the summarizing, cross-referencing, and filing.

## Vault layout

Default location: `tools::R_user_dir("pensar", "data")`.

```
{vault}/
  raw/
    articles/       clipped articles, pasted text, links worth preserving
    chats/          conversation logs worth keeping
    briefings/      project briefings (one per project, historical record)
    matrix/         messages from Matrix rooms
  wiki/             your pages: summaries, concepts, analyses
  index.md          auto-generated catalog (use update_index())
  log.md            append-only operation log (use log_entry())
  schema.md         conventions for vault maintenance
```

`ingest()` stores content in `raw/`. Sources that already live somewhere and don't need preservation can be referenced by wiki pages in their frontmatter without calling ingest.

## Core functions

| Function | Purpose |
|---|---|
| `init_vault(path)` | Create vault structure, seed control files |
| `ingest(content, type, source)` | Write source to raw/, update index + log |
| `update_index(vault)` | Regenerate index.md from all pages |
| `log_entry(message, operation)` | Append to log.md |
| `status(vault)` | Page counts by category |
| `backlinks(page, vault)` | Find pages linking to a given page |

## Page conventions

- YAML frontmatter on every page (title, type, source, date, tags)
- `[[wikilinks]]` for connections between pages
- Standard `[text](path.md)` links where full paths matter
- One concept per wiki page
- Wiki pages synthesize, never duplicate raw sources

## File structure

```
R/
  backlinks.R   backlinks()
  db.R          default_vault(), now_ts(), slugify(), helpers
  index.R       update_index()
  ingest.R      ingest()
  log.R         log_entry()
  parse.R       frontmatter/wikilink parsing (internal)
  status.R      status(), print.pensar_status()
  vault.R       init_vault(), schema template
```

## Design philosophy

- Base R only, one dependency: yaml
- Flat markdown files, no database
- CRAN-viable, Apache 2.0

## Do not

- Add dependencies beyond yaml without asking Troy
- Edit raw sources after ingest (they're immutable)
- Edit index.md or log.md manually (use the functions)
- Use tidyverse functions or pipes
