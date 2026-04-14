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
| `outlinks(page, vault)` | Find pages this page cites |
| `show_page(page, vault)` | Bundle content + outlinks + backlinks |
| `lint(vault)` | Orphans, broken wikilinks, cluster gaps |

## CLI tool (use by default)

A `pensar` shell command is installed at `~/.local/bin/pensar`. Use it instead of writing `r -e '...'` for routine inspection:

```
pensar status              # vault page counts
pensar lint                # health check
pensar show "<page>"       # content + outlinks + backlinks (drill-down)
pensar back "<page>"       # backlinks only
pensar tag <tag>           # pages with a tag
pensar log [n]             # last n log entries
```

**Before claiming anything about a wiki page, run `pensar show "<page>"` first.** It surfaces what the page cites and what cites it, which is the context needed to judge accuracy.

## Drill-down workflow (when a wiki claim is wrong or weak)

1. `pensar show "<wiki-page>"` to see the page content plus its cited sources
2. Read the cited raw sources (listed under Outlinks)
3. Compare: does the raw support the wiki's claim?
4. Fix the wiki — never the raw. Raw is ground truth.

Rules:
- Raw contradicts wiki: rewrite the wiki claim
- Raw is ambiguous: soften ("may," "probably") or mark as open question
- Claim has no cited source: either find one or demote to speculation
- Two raws contradict: flag the contradiction in the wiki

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
