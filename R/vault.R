#' @title Vault initialization
#' @description Create and seed a pensar vault.

#' Initialize a pensar vault
#'
#' Creates the vault directory structure and seeds the control files:
#' \code{schema.md}, \code{index.md}, \code{log.md}, and (by default)
#' agent instruction files for Claude Code and Codex.
#'
#' @param path Path to the vault directory. Defaults to the standard
#'   R user data directory for pensar.
#' @param rproj If \code{TRUE} (default), also write an RStudio project
#'   file (\code{{basename(path)}.Rproj}). RStudio's GUI refuses to
#'   create projects inside hidden folders like \code{~/.local/share/},
#'   which is where the default vault lives. Seeding the project file
#'   during init_vault() sidesteps that limitation so the vault opens
#'   cleanly as a project. Code indexing is disabled in the project
#'   file since the vault contents are markdown, not R source. The file
#'   is a harmless ~14-line INI stub; delete it anytime if you prefer
#'   not to use RStudio. Pass \code{rproj = FALSE} to skip it entirely.
#' @param agent_instructions If \code{TRUE} (default), write
#'   \code{CLAUDE.md} and \code{AGENTS.md} with identical content
#'   orienting an AI agent to work in this vault (CLI reminders,
#'   editing rules, ingest workflow). If you don't plan to start an
#'   AI agent session in the vault, pass \code{FALSE}.
#' @return The vault path, invisibly.
#' @export
init_vault <- function(path = default_vault(), rproj = TRUE,
                       agent_instructions = TRUE) {
    path <- normalizePath(path, mustWork = FALSE)
    if (file.exists(file.path(path, "schema.md"))) {
        message("Vault already exists at: ", path)
        return(invisible(path))
    }

    dirs <- c(
              file.path(path, "raw", "articles"),
              file.path(path, "raw", "chats"),
              file.path(path, "raw", "briefings"),
              file.path(path, "raw", "matrix"),
              file.path(path, "wiki")
    )
    for (d in dirs) {
        dir.create(d, recursive = TRUE, showWarnings = FALSE)
    }

    writeLines(schema_template(), file.path(path, "schema.md"))
    writeLines(index_seed(), file.path(path, "index.md"))
    writeLines(log_seed(), file.path(path, "log.md"))

    if (isTRUE(rproj)) {
        rproj_path <- file.path(path, paste0(basename(path), ".Rproj"))
        writeLines(rproj_template(), rproj_path)
    }

    if (isTRUE(agent_instructions)) {
        tmpl <- agent_instructions_template()
        writeLines(tmpl, file.path(path, "CLAUDE.md"))
        writeLines(tmpl, file.path(path, "AGENTS.md"))
    }

    log_entry("Vault initialized", operation = "init", vault = path)

    message("Vault created at: ", path)
    invisible(path)
}

#' Agent instructions template (CLAUDE.md / AGENTS.md)
#' @noRd
agent_instructions_template <- function() {
    c(
        "# Agent Instructions",
        "",
        "You're in a pensar vault. This is a knowledge base, not a code",
        "project. The content is plain markdown; the tooling is the",
        "`pensar` R package.",
        "",
        "## What lives here",
        "",
        "```",
        "raw/              immutable source documents",
        "wiki/             LLM-maintained synthesis pages",
        "index.md          auto-generated catalog",
        "log.md            append-only operation log",
        "schema.md         vault conventions (read first if in doubt)",
        "```",
        "",
        "## How to converse with the vault",
        "",
        "Use the `pensar` CLI instead of reading files blindly. It's",
        "faster, surfaces connections, and makes behavior consistent",
        "across sessions.",
        "",
        "```",
        "pensar status              page counts by category",
        "pensar lint                orphans, broken wikilinks, gaps",
        "pensar show \"<page>\"       content + outlinks + backlinks",
        "pensar back \"<page>\"       what links to this page",
        "pensar tag <tag>           pages with this tag",
        "pensar log [n]             last n log entries",
        "pensar export [out-dir]    render to static HTML",
        "```",
        "",
        "Before making any claim about a wiki page, run",
        "`pensar show \"<page>\"` first so you can see what it cites and",
        "what cites it.",
        "",
        "## Editing rules",
        "",
        "- **Raw sources are immutable.** Never edit files in `raw/`.",
        "  If a raw source is wrong, treat it as a data point and",
        "  correct the interpretation in wiki pages.",
        "- **Wiki pages are editable.** Synthesize, don't duplicate.",
        "  Every claim should cite a raw source via `[[wikilinks]]`.",
        "- **Fix the wiki, never the raw.** Raw is ground truth for",
        "  what was said; wiki is interpretation. If they disagree,",
        "  wiki is wrong.",
        "",
        "## Ingesting new content",
        "",
        "Two paths:",
        "",
        "1. Slash command `/pensar <pasted content>` (if the skill is",
        "   installed) infers type/source/title/tags and files it.",
        "2. Direct R call: `pensar::ingest(content, type, source, ...)`",
        "",
        "Don't edit `raw/` files by hand. Always go through `ingest()`.",
        "",
        "## After edits, rebuild the site",
        "",
        "```",
        "pensar export",
        "```",
        "",
        "If `PENSAR_SITE_DIR` is set (e.g. to a Syncthing folder), that",
        "becomes the default destination. Otherwise the site lands in",
        "`tools::R_user_dir(\"pensar\", \"cache\")/site`. Run after any",
        "wiki edit or ingest so downstream viewers show current state.",
        "",
        "## When something seems off",
        "",
        "Run `pensar lint`. It surfaces orphans (no backlinks), broken",
        "wikilinks, and tag clusters with no wiki synthesis."
    )
}

#' RStudio project file template
#' @noRd
rproj_template <- function() {
    c(
        "Version: 1.0",
        "",
        "RestoreWorkspace: No",
        "SaveWorkspace: No",
        "AlwaysSaveHistory: Default",
        "",
        "EnableCodeIndexing: No",
        "UseSpacesForTab: Yes",
        "NumSpacesForTab: 2",
        "Encoding: UTF-8",
        "",
        "RnwWeave: Sweave",
        "LaTeX: pdfLaTeX"
    )
}

#' Schema template
#' @noRd
schema_template <- function() {
    c(
        "---",
        "title: Vault Schema",
        "type: schema",
        "---",
        "",
        "# Vault Schema",
        "",
        "This vault is maintained by LLMs following these conventions.",
        "",
        "## Directory Structure",
        "",
        "- `raw/` -- Content preserved in the vault. Immutable after ingest.",
        "  - `articles/` -- Clipped articles, pasted text, links worth preserving",
        "  - `chats/` -- Conversation logs worth keeping",
        "  - `briefings/` -- Project briefings (one per project, historical record)",
        "  - `matrix/` -- Messages from Matrix rooms",
        "- `wiki/` -- LLM-maintained pages (summaries, concepts, entities, analyses)",
        "- `index.md` -- Auto-generated catalog. Do not edit manually; use update_index().",
        "- `log.md` -- Append-only chronological record. Do not edit; use log_entry().",
        "- `schema.md` -- This file. Human-maintained.",
        "",
        "## Page Format",
        "",
        "Every page uses YAML frontmatter:",
        "",
        "    ---",
        "    title: Page Title",
        "    type: article|chat|briefing|matrix|concept|entity|analysis|summary",
        "    source: origin identifier or path to external source",
        "    date: YYYY-MM-DD",
        "    tags:",
        "      - tag1",
        "      - tag2",
        "    ---",
        "",
        "## Links",
        "",
        "- Use [[wikilinks]] to connect pages.",
        "- Use [text](relative/path.md) when the full path matters.",
        "- Wiki pages can reference external sources (llamaR sessions, saber briefs)",
        "  via the `source` frontmatter field without copying them into the vault.",
        "",
        "## Wiki Maintenance Rules",
        "",
        "1. Wiki pages synthesize, never duplicate. Link back to sources.",
        "2. One concept per page. Split broad topics into focused pages.",
        "3. Cross-reference aggressively. If two pages relate, link them.",
        "4. Update index.md after adding or removing pages (via update_index()).",
        "5. Log all operations to log.md (via log_entry()).",
        "",
        "## Drill-Down Workflow",
        "",
        "When a wiki claim seems wrong or weak:",
        "",
        "1. Use `pensar show \"<page>\"` or `show_page()` to see the page",
        "   plus its cited sources (Outlinks).",
        "2. Read the cited raw sources.",
        "3. Compare: does the raw support the wiki's claim?",
        "4. Fix the wiki, never the raw. Raw is ground truth.",
        "",
        "Rules:",
        "",
        "- Raw contradicts the wiki: rewrite the wiki claim.",
        "- Raw is ambiguous: soften (\"may\", \"probably\") or mark open question.",
        "- Claim has no cited source: find one or demote to speculation.",
        "- Two raws contradict: flag the contradiction in the wiki."
    )
}

#' Index seed content
#' @noRd
index_seed <- function() {
    c(
        "---",
        paste0("title: Vault Index"),
        paste0("updated: ", now_ts()),
        "---",
        "",
        "# Vault Index",
        "",
        "## Raw: Articles (0)",
        "",
        "## Raw: Chats (0)",
        "",
        "## Raw: Briefings (0)",
        "",
        "## Raw: Matrix (0)",
        "",
        "## Wiki (0)",
        ""
    )
}

#' Log seed content
#' @noRd
log_seed <- function() {
    c("---", "title: Vault Log", "type: log", "---", "", "# Vault Log", "")
}

