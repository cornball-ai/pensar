# pensar

LLM wiki engine for R. Your knowledge base grows while you work.

An open source R implementation of the [Obsidian](https://obsidian.md/) markdown vault concept combined with [Karpathy's LLM wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). The LLM maintains the wiki. You edit, curate sources, and ask questions.

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
  schema.md         conventions for content in the vault
  CLAUDE.md         instructions for Claude Code when started here
  AGENTS.md         same content for Codex and other agents
  {name}.Rproj      RStudio project file
```

`raw/` is for content you want to preserve in the vault. `ingest()` stores it there. Sources that already live somewhere and don't need preservation can be referenced directly by wiki pages in their frontmatter, no ingest needed. `index.md` and `log.md` are maintained by pensar functions.

## Working with an AI agent

`init_vault()` seeds `CLAUDE.md` and `AGENTS.md` by default so any agent you start in the vault (Claude Code, Codex, etc.) knows how to operate on it — what files are immutable, how to drill down with `pensar show`, when to rebuild the site, and so on.

For conversational use, start your agent session *in the vault directory itself*. The working directory becomes the knowledge base, auto-memory stays scoped to vault work, and file edits land in the right place by default.

Pass `agent_instructions = FALSE` to `init_vault()` if you don't want these files.

## Versioning: git or syncthing?

Use both, for different things:

- **Git** for the vault source (`raw/`, `wiki/`, `index.md`, `log.md`, `schema.md`, etc.). The vault is plain markdown — it diffs beautifully, history matters when a wiki page gets revised, and you can push to a private GitHub repo for backup. After `init_vault()`, just run `git init && git add . && git commit -m "initial vault"`.
- **Syncthing (or Dropbox, etc.)** for the rendered site (`vault_export()` output), so you can browse on your phone without running anything. Set `PENSAR_SITE_DIR` to a synced folder and `pensar export` writes there by default.

Don't sync the vault source via Syncthing. Concurrent edits from multiple devices on the same `.md` file get messy, and you lose history. Use git for that.

Note: "raw" in pensar terminology means source documents in `raw/` (vs. synthesized `wiki/` pages), not "raw text". Everything in the vault is markdown — there's no separate raw-vs-rendered distinction inside the vault itself. Rendering happens via `vault_export()` into a separate directory.

## Functions

| Function | What it does |
|---|---|
| `init_vault(path)` | Create the vault directory structure and seed control files |
| `ingest(content, type, source)` | Write a source to `raw/`, update the index and log |
| `update_index(vault)` | Regenerate `index.md` from all vault pages |
| `log_entry(message, operation)` | Append a structured entry to `log.md` |
| `status(vault)` | Page counts by category |
| `backlinks(page, vault)` | Find all pages linking to a given page |
| `outlinks(page, vault)` | Find pages this page cites |
| `show_page(page, vault)` | Content + outlinks + backlinks for drill-down |
| `lint(vault)` | Orphans, broken wikilinks, tag clusters needing synthesis |
| `vault_export(vault, out_dir)` | Render vault to static HTML (requires pandoc) |

A `pensar` CLI is also installed at `{pkg}/bin/pensar`:

```
pensar status              page counts by category
pensar lint                health check
pensar show "<page>"       drill-down inspection
pensar back "<page>"       backlinks only
pensar tag <tag>           pages with this tag
pensar log [n]             last n log entries
pensar export [out-dir]    render to static HTML
```

Symlink `{pkg}/bin/pensar` to somewhere on your PATH (e.g., `~/.local/bin/pensar`) to use it as a command.

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
