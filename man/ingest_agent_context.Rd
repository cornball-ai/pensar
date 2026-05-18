% tinyrox says don't edit this manually, but it can't stop you!
\name{ingest_agent_context}
\alias{ingest_agent_context}
\title{Agent context ingest}
\usage{
ingest_agent_context(agent = c("claude", "codex", "corteza"),
                     vault = default_vault(), project_dir = getwd(),
                     workspace_dir = NULL, ...)
}
\arguments{
\item{agent}{One of \code{"claude"}, \code{"codex"},
\code{"corteza"}. Passed to \code{saber::agent_context()}.}

\item{vault}{Vault path.}

\item{project_dir}{Project directory passed to
\code{saber::agent_context()}. Defaults to \code{getwd()}.}

\item{workspace_dir}{Optional workspace dir
(e.g., \code{~/.corteza/workspace}) passed through to saber for
\code{SOUL.md} / \code{USER.md} resolution.}

\item{...}{Forwarded to \code{saber::agent_context()}; use this for
the \code{include_*} overrides documented there.}
}
\value{
The relative path of the written page, invisibly. Returns
  \code{NULL} invisibly when saber returns an empty context.
}
\description{
Thin wrapper that snapshots
\code{saber::agent_context()} into the vault as a \code{raw/chats/}
page so the live agent context (memory, instructions, identity)
becomes searchable across sessions.
Snapshot saber's assembled agent context into the vault

Calls \code{saber::agent_context()} to assemble the current
memory / project-instructions / global-instructions / identity
string for an agent, then writes it into the vault through the
existing \code{ingest()} pipeline (so the manifest, index, log,
and auto-commit all kick in).

Saber stays in pensar's \code{Suggests}: the wrapper guards with
\code{requireNamespace("saber")} and errors with an install hint if
the package isn't available. Users who don't want this wrapper pay
no mandatory dependency cost.

Returns silently with a message (and no write) when saber returns
an empty context, so the vault doesn't accumulate empty snapshots.
}
\examples{
\dontrun{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest_agent_context("claude", vault = v)
unlink(v, recursive = TRUE)
}
}
