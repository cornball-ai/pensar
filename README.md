# pensar

Personal wiki engine for R with a large language model (LLM) as research assistant.

> **Alpha.** Expect bugs and missing functionality. Feel free to open an issue if you're noticing or missing something specific that's not already tracked.

An open-source R implementation of the [Obsidian](https://obsidian.md/) markdown vault concept combined with [Karpathy's LLM wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). Three modes share the same vault:

- **Autonomous.** `pensar::autoresearch("topic")` decomposes the topic, runs web searches, files sources, and writes a source-cited synthesis page. R drives the loop; the LLM makes structured decisions (query planning, source selection, evidence extraction, gap analysis, page drafting, edit-aware revisions) inside the bounds R sets.
- **Guided.** Start an agent session (Claude Code, Codex, etc.) in the vault directory. `init_vault()` writes `CLAUDE.md` / `AGENTS.md` so the agent knows what files are immutable and how to use pensar's R primitives. A bundled `autoresearch` skill is available to Claude Code.
- **Manual.** Edit `wiki/<page>.md` directly in your favourite IDE (RStudio, VS Code, Obsidian). pensar walks the markdown on next call; nothing is locked.

Vaults are plain markdown with YAML frontmatter and `[[wikilinks]]` — diffable, version-controllable, Obsidian-compatible.

pensar ("to think") has four base dependencies: `curl`, `digest`, `stringdist`, `yaml`. The LLM workflows are gated by `Suggests:` (`llm.api`, `jsonlite`).

## Install

```r
install.packages("pensar")   # or
remotes::install_github("cornball-ai/pensar")
```

## Quick start

### Autonomous research

```r
library(pensar)

init_vault("~/wiki")
use_vault("~/wiki")

Sys.setenv(TAVILY_API_KEY = "tvly-...")        # free tier at tavily.com
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")   # or OPENAI_API_KEY / MOONSHOT_API_KEY

res <- autoresearch("transformer scaling laws")
print(res)
show_page(res$synthesis$slug)
```

Without API keys, `autoresearch()` falls back to deterministic heuristics so the pipeline still runs (search-and-file with no LLM judgment, much lower output quality).

### Adopt an existing Obsidian vault

```r
init_vault("~/Documents/my-obsidian-vault", adopt = TRUE)
status("~/Documents/my-obsidian-vault")
```

Adopt mode adds only three small files (`schema.md`, `index.md`, `log.md`) and flags the vault as read-first. `ingest()` and the wiki writer refuse to write unless you pass `force = TRUE`. See `vignette("adopt-obsidian", package = "pensar")` for a walkthrough across six real Obsidian vaults.

### Manual ingest

```r
ingest("Article content here...",
       type = "articles",
       source = "https://example.com/interesting-post",
       title = "Interesting Post")

status()
backlinks("Interesting Post")
```

## Configuring the vault path

Per CRAN policy, pensar **never writes to a default home-filespace location**. You have to point it somewhere. Resolution order (first hit wins):

1. The `vault =` argument when passed explicitly.
2. The `PENSAR_VAULT` environment variable.
3. Walk-up from `getwd()` for a directory containing `schema.md`.
4. `options("pensar.vault")`, set by `use_vault()` — typically in `~/.Rprofile`.

If none resolves, pensar errors with a setup hint.

## Vault structure

```
{vault}/
  raw/
    articles/       clipped articles, autoresearch sources, pasted text
    chats/          conversation logs worth keeping
    briefings/      project briefings
    matrix/         messages from Matrix rooms
  wiki/             synthesized pages (autoresearch + your edits)
  index.md          auto-generated catalog of everything
  log.md            append-only record of operations
  schema.md         conventions for content in the vault
  CLAUDE.md         instructions for Claude Code when started here
  AGENTS.md         same content for Codex and other agents
  {name}.Rproj      RStudio project file
```

## Working with an AI agent (guided mode)

`init_vault()` seeds `CLAUDE.md` and `AGENTS.md` so any agent you start in the vault (Claude Code, Codex, etc.) knows how to operate on it — what files are immutable, how to drill down with `pensar show`, when to rebuild the site.

A Claude Code `autoresearch` skill ships at `system.file("skills/pensar/autoresearch", package = "pensar")`. Symlink it into your skills directory:

```bash
ln -s "$(Rscript -e 'cat(pensar::pensar_skill_path())')" ~/.claude/skills/pensar
```

The skill routes research requests through `pensar::autoresearch()`, not through a manual WebSearch/WebFetch/file-edit loop. Pass `agent_instructions = FALSE` to `init_vault()` if you don't want CLAUDE.md / AGENTS.md.

## Versioning: git or syncthing?

Use both, for different things:

- **Git** for the vault source (`raw/`, `wiki/`, `index.md`, `log.md`, `schema.md`). The vault is plain markdown — diffs cleanly, history matters when a wiki page gets revised, and you can push to a private GitHub repo for backup. `autoresearch()` and `ingest()` both call `vault_commit()` after their writes, so git-backed vaults stay clean. After `init_vault()`, run `git init && git add . && git commit -m "initial vault"`.
- **Syncthing (or Dropbox, etc.)** for the rendered site (`vault_export()` output), so you can browse on your phone. Set `PENSAR_SITE_DIR` to a synced folder.

Don't sync the vault source via Syncthing. Concurrent edits from multiple devices on the same `.md` file get messy.

## Functions

| Function | What it does |
|---|---|
| `autoresearch(topic, vault)` | Decompose, search, ingest, synthesize into the vault |
| `init_vault(path, adopt)` | Create or adopt a vault |
| `use_vault(path)` | Remember a vault path for this session |
| `ingest(content, type, source)` | Write a source to `raw/`, update index + log |
| `ingest_url(url)` | Fetch + file a URL into `raw/articles/` |
| `update_index(vault)` | Regenerate `index.md` from all vault pages |
| `vault_commit(message)` | Auto-commit vault changes (no-op for non-git) |
| `status(vault)` | Page counts by category |
| `backlinks(page)` | Find all pages linking to a given page |
| `outlinks(page)` | Find pages this page cites |
| `related_pages(name, k)` | Surface related pages by overlap |
| `show_page(page)` | Content + outlinks + backlinks |
| `lint(vault)` | Orphans, broken wikilinks, tag clusters |
| `vault_export(vault, out_dir)` | Render vault to static HTML (requires pandoc) |

A `pensar` CLI is installed at `{pkg}/bin/pensar`:

```
pensar status              page counts by category
pensar lint                health check
pensar show "<page>"       drill-down inspection
pensar back "<page>"       backlinks only
pensar tag <tag>           pages with this tag
pensar log [n]             last n log entries
pensar export [out-dir]    render to static HTML
```

Symlink `{pkg}/bin/pensar` to somewhere on your `PATH` (e.g., `~/.local/bin/pensar`) to use it as a command.

## Conventions

Every page uses YAML frontmatter and plain `[[wikilinks]]`. Obsidian-style aliases (`[[page-slug|display text]]`) are supported: pensar resolves `page-slug` as the target and renders `display text` for readers.

```markdown
---
title: Page Title
type: concept
source: "[[Raw Source]]"
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
| [saber](https://github.com/cornball-ai/saber) | Context engineering for LLM agents (CRAN) |
| pensar | Personal LLM wiki engine (this package) |
| [corteza](https://github.com/cornball-ai/corteza) | Agent runtime and chat loop |
| [llm.api](https://github.com/cornball-ai/llm.api) | LLM provider connectivity (CRAN) |
| [mx.api](https://github.com/cornball-ai/mx.api) | Matrix Client-Server API |

## License

Apache 2.0
