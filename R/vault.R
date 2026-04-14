#' @title Vault initialization
#' @description Create and seed a pensar vault.

#' Initialize a pensar vault
#'
#' Creates the vault directory structure and seeds the control files:
#' \code{schema.md}, \code{index.md}, and \code{log.md}.
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
#' @return The vault path, invisibly.
#' @export
init_vault <- function(path = default_vault(), rproj = TRUE) {
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

    log_entry("Vault initialized", operation = "init", vault = path)

    message("Vault created at: ", path)
    invisible(path)
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

