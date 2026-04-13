# pensar

LLM wiki engine for R. Your knowledge base grows while you work.

An open source R implementation of the [Obsidian](https://obsidian.md/) markdown vault concept combined with [Karpathy's LLM wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). The LLM maintains the wiki. You curate sources and ask questions.

pensar ("to think") has one dependency: `yaml`.

## Install

```r
remotes::install_github("cornball-ai/pensar")
```

## The idea

Most people's experience with LLMs and documents is stateless. You ask a question, the LLM retrieves some chunks, generates an answer, and forgets everything. Nothing compounds.

pensar takes a different approach. An LLM reads your sources (articles, chat logs, project briefings, whatever you point it at), writes wiki pages that synthesize the key ideas, links everything together with `[[wikilinks]]`, and maintains an index. The knowledge base gets richer with every source you add and every question you ask.

The vault is the synthesis layer, not a data lake. Sources that already live somewhere (llamaR sessions, saber briefs) get referenced, not copied. Content without a home (a link someone sent you, a pasted article, a quick note) can be ingested directly.

## Quick start

```r
library(pensar)

# Create a vault
init_vault()

# Ingest a source
ingest("Article content here...",
       type = "articles",
       source = "https://example.com/interesting-post",
       title = "Interesting Post")

# Check what's in the vault
status()

# Find what links to a page
backlinks("Interesting Post")
```

## Vault structure

```
{vault}/
  raw/
    articles/       clipped articles, pasted text, links worth preserving
    chats/          conversation logs worth keeping
    briefings/      project briefings (one per project, historical record)
    matrix/         messages from Matrix rooms
  wiki/             LLM-maintained pages (summaries, concepts, analyses)
  index.md          auto-generated catalog of everything
  log.md            append-only record of operations
  schema.md         instructions for LLMs operating on the vault
```

`raw/` is for content you want to preserve in the vault. `ingest()` stores it there. Sources that already live somewhere and don't need preservation can be referenced directly by wiki pages in their frontmatter, no ingest needed. `index.md` and `log.md` are maintained by pensar functions.

## Functions

| Function | What it does |
|---|---|
| `init_vault(path)` | Create the vault directory structure and seed control files |
| `ingest(content, type, source)` | Write a source to `raw/`, update the index and log |
| `update_index(vault)` | Regenerate `index.md` from all vault pages |
| `log_entry(message, operation)` | Append a structured entry to `log.md` |
| `status(vault)` | Page counts by category |
| `backlinks(page, vault)` | Find all pages linking to a given page |

## Conventions

Every page uses YAML frontmatter and plain `[[wikilinks]]`. Compatible with Obsidian but no Obsidian-specific extensions. View the vault in RStudio, Obsidian, any markdown editor.

```markdown
---
title: Page Title
type: concept
source: https://example.com
date: 2026-04-13
tags:
  - R
  - testing
---

This connects to [[Other Page]] and builds on [[Raw Source]].
```

## Sister packages

| Package | Purpose |
|---|---|
| [saber](https://github.com/cornball-ai/saber) | AST symbol index, blast radius, package introspection |
| pensar | LLM wiki engine (this package) |
| [buscar](https://github.com/cornball-ai/buscar) | BM25 keyword and vector similarity search |
| [llamaR](https://github.com/cornball-ai/llamaR) | Agent runtime and chat loop |
| [llm.api](https://github.com/cornball-ai/llm.api) | LLM provider connectivity |

## License

Apache 2.0
