#' @title Agent context ingest
#' @description Thin wrapper that snapshots
#' \code{saber::agent_context()} into the vault as a \code{raw/chats/}
#' page so the live agent context (memory, instructions, identity)
#' becomes searchable across sessions.

#' Snapshot saber's assembled agent context into the vault
#'
#' Calls \code{saber::agent_context()} to assemble the current
#' memory / project-instructions / global-instructions / identity
#' string for an agent, then writes it into the vault through the
#' existing \code{ingest()} pipeline (so the manifest, index, log,
#' and auto-commit all kick in).
#'
#' Saber stays in pensar's \code{Suggests}: the wrapper guards with
#' \code{requireNamespace("saber")} and errors with an install hint if
#' the package isn't available. Users who don't want this wrapper pay
#' no mandatory dependency cost.
#'
#' Returns silently with a message (and no write) when saber returns
#' an empty context, so the vault doesn't accumulate empty snapshots.
#'
#' @param agent One of \code{"claude"}, \code{"codex"},
#'   \code{"corteza"}. Passed to \code{saber::agent_context()}.
#' @param vault Vault path.
#' @param project_dir Project directory passed to
#'   \code{saber::agent_context()}. Defaults to \code{getwd()}.
#' @param workspace_dir Optional workspace dir
#'   (e.g., \code{~/.corteza/workspace}) passed through to saber for
#'   \code{SOUL.md} / \code{USER.md} resolution.
#' @param ... Forwarded to \code{saber::agent_context()}; use this for
#'   the \code{include_*} overrides documented there.
#' @return The relative path of the written page, invisibly. Returns
#'   \code{NULL} invisibly when saber returns an empty context.
#' @examples
#' \dontrun{
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest_agent_context("claude", vault = v)
#' unlink(v, recursive = TRUE)
#' }
#' @export
ingest_agent_context <- function(agent = c("claude", "codex",
                                           "corteza"),
                                 vault = default_vault(),
                                 project_dir = getwd(),
                                 workspace_dir = NULL, ...) {
    agent <- match.arg(agent)
    if (!requireNamespace("saber", quietly = TRUE)) {
        stop("ingest_agent_context() requires the 'saber' package.\n",
             "  Install with: install.packages('saber')",
             call. = FALSE)
    }
    vault <- normalizePath(vault, mustWork = TRUE)

    context <- saber::agent_context(agent = agent,
                                    project_dir = project_dir,
                                    workspace_dir = workspace_dir,
                                    ...)
    if (!is.character(context) || length(context) == 0L ||
        !nzchar(trimws(paste(context, collapse = "\n")))) {
        message("saber::agent_context(", agent, ") returned an empty ",
                "context; nothing to ingest.")
        return(invisible(NULL))
    }

    source_id <- sprintf("saber::agent_context(%s)", agent)
    title <- sprintf("%s context %s", agent,
                     format(Sys.Date(), "%Y-%m-%d"))
    fp <- ingest(content = context, type = "chats",
                 source = source_id, title = title,
                 tags = c("agent-context", agent), vault = vault)
    invisible(substring(fp, nchar(vault) + 2L))
}
