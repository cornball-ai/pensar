#' @title Vault initialization
#' @description Create and seed a pensar vault.

#' Initialize a pensar vault
#'
#' Creates the vault directory structure and seeds the control files:
#' \code{schema.md}, \code{index.md}, \code{log.md}, and (by default)
#' agent instruction files for Claude Code and Codex.
#'
#' @param path Path to the vault directory. No implicit default: pass
#'   an explicit path, or configure one via \code{PENSAR_VAULT},
#'   \code{use_vault()}, or a walk-up \code{schema.md} marker (either
#'   in the current directory or in a \code{vault/} subdir). Per CRAN
#'   policy pensar will not silently write to the user's home
#'   filespace.
#' @param rproj If \code{TRUE} (default), also write an RStudio project
#'   file (\code{{basename(path)}.Rproj}). The project file makes a
#'   vault stored under a hidden directory (e.g., one configured via
#'   \code{PENSAR_VAULT} pointing at \code{~/.local/share/...}) easy to
#'   open as an RStudio project, since RStudio's GUI normally refuses
#'   to create projects inside hidden folders. Code indexing is
#'   disabled in the project file since the vault contents are
#'   markdown, not R source. The file is a harmless ~14-line INI stub;
#'   delete it anytime if you prefer not to use RStudio. Pass
#'   \code{rproj = FALSE} to skip it entirely.
#' @param agent_instructions If \code{TRUE} (default), write
#'   \code{CLAUDE.md} and \code{AGENTS.md} with identical content
#'   orienting an AI agent to work in this vault (CLI reminders,
#'   editing rules, ingest workflow). If you don't plan to start an
#'   AI agent session in the vault, pass \code{FALSE}.
#' @param adopt Opt-in read-only adopt mode. When \code{TRUE} the
#'   function writes only a minimal adopted \code{schema.md} (carrying
#'   \code{adopted: true} frontmatter), plus \code{log.md} and
#'   \code{index.md} if absent. No \code{raw/} or \code{wiki/}
#'   scaffolding is created and no auto-commit runs. Use this when
#'   pointing pensar at an existing Obsidian vault whose layout you
#'   don't want to change. After adoption, \code{update_index()} and
#'   \code{status()} switch to registry-driven enumeration; reads
#'   work normally and \code{ingest()} refuses writes unless
#'   \code{force = TRUE}.
#' @param commit Auto-commit gate. \code{NULL} (default) commits the
#'   initial scaffold only when the target directory is pensar-owned
#'   (empty, or already shaped like a pensar vault). \code{TRUE} commits
#'   unconditionally (after \code{force = TRUE} writes); \code{FALSE}
#'   skips the commit even for pensar-owned directories. Forcing pensar
#'   into foreign content does not by itself grant permission to commit
#'   to that content's history.
#' @param force Write gate. \code{FALSE} (default) refuses to scaffold
#'   when the target directory already contains files or a git history
#'   that aren't pensar's. \code{TRUE} scaffolds anyway. Use sparingly.
#' @return The vault path, invisibly. Returns \code{NULL} invisibly when
#'   the safety gate refused to scaffold.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' list.files(v, recursive = TRUE)
#' unlink(v, recursive = TRUE)
#' @export
init_vault <- function(path = default_vault(), rproj = TRUE,
                       agent_instructions = TRUE, adopt = FALSE,
                       commit = NULL, force = FALSE) {
    path <- normalizePath(path, mustWork = FALSE)

    # Adopt mode is checked first so a foreign vault that happens to
    # already carry a schema.md doesn't slip past with the "Vault
    # already exists" early return.
    if (isTRUE(adopt)) {
        if (!dir.exists(path)) {
            dir.create(path, recursive = TRUE, showWarnings = FALSE)
        }
        path <- normalizePath(path)

        if (file.exists(file.path(path, "schema.md"))) {
            if (vault_is_adopted(path)) {
                message("Vault already adopted at: ", path)
                return(invisible(path))
            }
            message("Refusing to convert existing pensar vault to ",
                    "adopt mode: ", path,
                    "\n  Existing schema.md is native (no adopted: ",
                    "true). Move or edit it explicitly first.")
            return(invisible(NULL))
        }

        # Track which files pensar creates here so we don't append a
        # log entry into a pre-existing user log.md.
        log_existed_before <- file.exists(file.path(path, "log.md"))

        writeLines(adopted_schema_template(), file.path(path, "schema.md"))
        if (!log_existed_before) {
            writeLines(log_seed(), file.path(path, "log.md"))
        }
        if (!file.exists(file.path(path, "index.md"))) {
            writeLines(index_seed(), file.path(path, "index.md"))
        }
        if (!log_existed_before) {
            log_entry("Vault adopted (read-only)", operation = "adopt",
                      vault = path)
        }
        message("Adopt mode: read-first. ingest() refuses writes ",
                "unless force = TRUE.")
        message("Vault adopted at: ", path)
        return(invisible(path))
    }

    if (file.exists(file.path(path, "schema.md"))) {
        message("Vault already exists at: ", path)
        return(invisible(path))
    }

    # Capture ownership *before* writing so the commit gate uses the
    # original state, not the post-scaffold state.
    pensar_owned <- vault_is_pensar_owned(path)
    if (!isTRUE(force) && !pensar_owned) {
        message(sprintf(paste0(
                               "Refusing to scaffold pensar into existing content at: %s\n",
                               "  Pass adopt = TRUE to use this directory in read-only ",
                               "adopt mode, or pass force = TRUE to scaffold pensar into ",
                               "the existing tree."), path))
        return(invisible(NULL))
    }

    dirs <- c(file.path(path, "raw", "articles"),
              file.path(path, "raw", "chats"),
              file.path(path, "raw", "briefings"),
              file.path(path, "raw", "matrix"), file.path(path, "wiki"))
    for (d in dirs) {
        dir.create(d, recursive = TRUE, showWarnings = FALSE)
    }

    # Re-normalize now that the directory exists. On macOS, normalizePath()
    # on a non-existent path does not resolve /var -> /private/var, so the
    # path returned from init_vault() could differ from normalizePath() on
    # the same path once it exists.
    path <- normalizePath(path)

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

    # Commit gate is separate from the write gate.
    # commit = NULL (default): auto-commit iff the dir was pensar-owned
    #   before scaffolding. Forcing into foreign content does NOT imply
    #   permission to commit to its history.
    # commit = TRUE / FALSE: explicit override.
    if (is.null(commit)) {
        should_commit <- pensar_owned
    } else {
        should_commit <- isTRUE(commit)
    }
    if (should_commit) {
        vault_commit("Vault initialized", vault = path)
    }

    message("Vault created at: ", path)
    invisible(path)
}

#' Agent instructions template (CLAUDE.md / AGENTS.md)
#' @noRd
agent_instructions_template <- function() {
    c("# Agent Instructions", "",
        "You're in a pensar vault. This is a knowledge base, not a code",
        "project. The content is plain markdown; the tooling is the",
        "`pensar` R package.", "", "## What lives here", "", "```",
        "raw/              immutable source documents",
        "wiki/             LLM-maintained synthesis pages",
        "index.md          auto-generated catalog",
        "log.md            append-only operation log",
        "schema.md         vault conventions (read first if in doubt)", "```",
        "", "## How to converse with the vault", "",
        "Use the `pensar` CLI instead of reading files blindly. It's",
        "faster, surfaces connections, and makes behavior consistent",
        "across sessions.", "", "```",
        "pensar status              page counts by category",
        "pensar lint                orphans, broken wikilinks, gaps",
        "pensar show \"<page>\"       content + outlinks + backlinks",
        "pensar back \"<page>\"       what links to this page",
        "pensar tag <tag>           pages with this tag",
        "pensar log [n]             last n log entries",
        "pensar export [out-dir]    render to static HTML", "```", "",
        "Before making any claim about a wiki page, run",
        "`pensar show \"<page>\"` first so you can see what it cites and",
        "what cites it.", "", "## Editing rules", "",
        "- **Raw sources are immutable.** Never edit files in `raw/`.",
        "  If a raw source is wrong, treat it as a data point and",
        "  correct the interpretation in wiki pages.",
        "- **Wiki pages are editable.** Synthesize, don't duplicate.",
        "  Every claim should cite a raw source via `[[wikilinks]]`.",
        "- **Fix the wiki, never the raw.** Raw is ground truth for",
        "  what was said; wiki is interpretation. If they disagree,",
        "  wiki is wrong.", "", "## Ingesting new content", "", "Two paths:",
        "", "1. Slash command `/pensar <pasted content>` (if the skill is",
        "   installed) infers type/source/title/tags and files it.",
        "2. Direct R call: `pensar::ingest(content, type, source, ...)`", "",
        "Don't edit `raw/` files by hand. Always go through `ingest()`.", "",
        "## After edits, rebuild the site", "", "```", "pensar export",
        "```", "", "Set `PENSAR_SITE_DIR` to where you want the rendered site",
        "(e.g. a Syncthing folder), or pass `out_dir =` explicitly to",
        "`vault_export()`. Per CRAN policy pensar will not silently",
        "render to a home-filespace cache. Run after any wiki edit or",
        "ingest so downstream viewers show current state.", "",
        "## When something seems off", "",
        "Run `pensar lint`. It surfaces orphans (no backlinks), broken",
        "wikilinks, and tag clusters with no wiki synthesis.", "",
        "## Versioning", "",
        "If the vault is a git repo (there's a `.git/` directory),",
        "pensar auto-commits after `ingest()` and `init_vault()`.",
        "Pushes to configured remotes happen automatically when",
        "`PENSAR_AUTO_PUSH` is truthy (default: push if any remote is",
        "set). Manual commit after wiki edits:", "", "```",
        "pensar commit \"Revised torch ecosystem synthesis\"", "```", "",
        "Non-standard git usage: the vault is typically a local-only",
        "repo on one authoritative machine (e.g., troy-ai). Other",
        "machines clone read-only over Tailscale/SSH. No GitHub",
        "required for privacy.")
}

#' RStudio project file template
#' @noRd
rproj_template <- function() {
    c("Version: 1.0", "", "RestoreWorkspace: No", "SaveWorkspace: No",
        "AlwaysSaveHistory: Default", "", "EnableCodeIndexing: No",
        "UseSpacesForTab: Yes", "NumSpacesForTab: 2", "Encoding: UTF-8", "",
        "RnwWeave: Sweave", "LaTeX: pdfLaTeX")
}

#' Adopted-vault schema template
#'
#' Smaller and explicit about the read-only contract. Written by
#' \code{init_vault(adopt = TRUE)}. The \code{adopted: true} frontmatter
#' field is what \code{vault_is_adopted()} reads to detect adopt mode.
#' @noRd
adopted_schema_template <- function() {
    c("---", "title: Vault Schema (adopted)", "type: schema",
        "adopted: true", "---", "", "# Vault Schema (adopted)", "",
        "This directory was adopted by pensar in read-only mode.",
        "Pensar indexes pages by frontmatter type but does not write",
        "scaffolding (`raw/`, `wiki/`) or auto-commit here.", "",
        "## What works", "", "- `vault_registry()` indexes every `.md` file.",
        "- `update_index()` writes `index.md` grouped by frontmatter",
        "  `type` (or `category`).",
        "- `status()` reports page counts by frontmatter type.",
        "- Read-only operations: `backlinks()`, `outlinks()`,",
        "  `show_page()`, plus any retrieval primitives that ship later.", "",
        "## What doesn't", "",
        "- `ingest()` refuses to write unless `force = TRUE`.",
        "- `init_vault()` does not auto-commit in adopt mode.", "",
        "Remove or set `adopted: false` in this file's frontmatter to",
        "switch to native pensar mode.")
}

#' Detect whether a vault was adopted (read-only mode)
#'
#' Reads \code{schema.md} frontmatter. Returns \code{TRUE} iff the
#' \code{adopted} field is truthy.
#' @noRd
vault_is_adopted <- function(vault) {
    schema_path <- file.path(vault, "schema.md")
    if (!file.exists(schema_path)) {
        return(FALSE)
    }
    fm <- parse_frontmatter(schema_path)
    isTRUE(fm$adopted)
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
        "  - `matrix/` -- Messages from Matrix rooms",
        "  - `repos/<repo>/` -- One directory per source repo, written by",
        "    `ingest_repo()`. Artifacts: `briefing.md`, `ast.md`,",
        "    `snapshot.md`. Regeneration overwrites in place; git tracks history.",
        "  - `briefings/` -- _Deprecated._ Legacy saber briefings; superseded",
        "    by `repos/<repo>/briefing.md`. Use `migrate_briefings_to_repos()`",
        "    to move existing content into the new layout.",
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
        "    type: articles|chats|matrix|repo-briefing|repo-ast|repo-snapshot|concept|entity|analysis|summary",
        "    source: origin identifier or path to external source",
        "    date: YYYY-MM-DD",
        "    tags:",
        "      - tag1",
        "      - tag2",
        "    ---",
        "",
        "Repo artifacts also carry a `repo:` block with `name`, `path`,",
        "`origin`, `branch`, `commit`, `commit_short`, `commit_date`, and",
        "`commit_subject` so claims can be traced to a specific commit.",
        "",
        "## Links",
        "",
        "- Use [[wikilinks]] to connect pages.",
        "- Repo artifacts use path-style slugs: `[[corteza/briefing]]`,",
        "  `[[saber/ast]]`. The `<repo>/` prefix routes the link into",
        "  `raw/repos/<repo>/<artifact>.md`.",
        "- Use [text](relative/path.md) when the full path matters.",
        "- Wiki pages can reference external sources (chat sessions, saber briefs)",
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
    c("---", paste0("title: Vault Index"), paste0("updated: ", now_ts()),
        "---", "", "# Vault Index", "", "## Raw: Articles (0)", "",
        "## Raw: Chats (0)", "", "## Raw: Briefings (0)", "",
        "## Raw: Matrix (0)", "", "## Raw: Repos (0)", "", "## Wiki (0)", "")
}

#' Log seed content
#' @noRd
log_seed <- function() {
    c("---", "title: Vault Log", "type: log", "---", "", "# Vault Log", "")
}

