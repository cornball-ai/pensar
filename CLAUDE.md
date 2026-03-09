# CLAUDE.md

## What this is

pensar ("to think") is the concept graph / ontology package in the llamaR agent toolchain. It maintains a lightweight knowledge graph derived from markdown files with YAML frontmatter and typed links.

You (Claude Code) are the primary consumer. Troy is the editor-of-last-resort.

Project files (CLAUDE.md, DESCRIPTION, etc.) are the source of truth. Read in place, never copied. The TSV index at `~/.cache/R/pensar/index` is derived. Never edit the index directly; edit the source files, then run `startup()`.

## Sister packages

- **saber** (cornball-ai/saber): AST symbol index, code analysis (zero deps)
- **informR** (cornball-ai/informR): project briefings, heartbeat, feature hubs (depends on pensar)

## Design philosophy

- Base R. No tidyverse. No pipes.
- One real dependency: yaml. Everything else is base R.
- Index stored as TSV files (human-readable, diffable).
- OBO emit is just writeLines(). No serialization library.
- CRAN-viable.
- Apache-2.0 license.

## Cache layout

```
~/.cache/R/pensar/
  index/.pensar/   — terms.tsv, relations.tsv, files.tsv
  annotations/     — persistent annotation files from add()
```

pensar never writes outside this directory.

## Core functions

| Function | Purpose |
|---|---|
| `index_vault(vault_path)` | Parse markdown files, build/update TSV index |
| `query(term, relation, direction)` | Traverse the typed graph (ancestors, descendants, siblings) |
| `suggest(vault_path)` | Propose typed edges from untyped links. Returns candidates, NOT facts. |
| `promote(term, vault_path)` | Write a stable `id:` into a file's frontmatter |
| `emit_obo(vault_path, outfile)` | Snapshot the current ontology to OBO format |
| `status(vault_path)` | Summary stats: term count, relation count, unconfirmed suggestions |
| `add(terms, relations)` | Bulk-insert terms and relations programmatically |
| `startup()` | Scan projects, build unified ontology, generate instructions file |
| `adjacency(vault_path)` | Build weighted adjacency matrix from relations |
| `clusters(vault_path, k)` | Hierarchical clustering of terms (hclust/cutree) |

## How you use this package

```r
r -e 'pensar::query("neural_networks", "is_a", "ancestors")'
```

All functions default to the standard cache path.

## Vault conventions

### Frontmatter

```yaml
---
id: ONTO:0000042
type: term
aliases:
  - NN
  - ANN
---
```

### Typed relations (inline fields)

```markdown
is_a:: [[dev_tooling]]
part_of:: [[cornyverse]]
uses:: [[yaml]]
```

Dataview-style inline fields. These are the canonical typed edges.

### What counts as a term

A note is a term if ANY of:
- It has `id:` in frontmatter
- It has `type: term` in frontmatter
- It appears as the target of a typed relation

## Index format

Three TSV files in the index directory:
- `terms.tsv` — id, name, filepath, aliases, promoted, updated_at
- `relations.tsv` — subject_id, relation_type, object_id, confirmed, source
- `files.tsv` — filepath, hash, parsed_at

## The suggest/confirm loop

`suggest()` proposes typed relations based on folder structure, heading context, and link frequency. Suggestions are written with `confirmed = 0`. Troy reviews them. Do NOT treat unconfirmed suggestions as facts.

## File structure

```
R/
  db.R        — load_index(), save_index(), TSV I/O
  parse.R     — frontmatter/link parsing
  index.R     — index_vault()
  query.R     — query(), graph traversal
  suggest.R   — suggest(), heuristic relation proposals
  promote.R   — promote(), ID generation
  emit.R      — emit_obo()
  status.R    — status()
  add.R       — add(), bulk insert
  graph.R     — adjacency(), clusters()
  startup.R   — startup(), unified bootstrapper
inst/
  tinytest/   — 103 tests
```

## Testing

- tinytest, 103 tests
- Tests use temp directories, not a real vault

## Things you should NOT do

- Do not add dependencies beyond yaml without asking Troy
- Do not silently promote notes to terms
- Do not treat suggested relations as confirmed
- Do not use tidyverse functions or pipes

## Things you SHOULD do

- When Troy asks you to query the ontology, actually call the functions
- When you notice an untyped link that should probably be typed, mention it
- Keep functions short. If a function is over 80 lines, split it.
