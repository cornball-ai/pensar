% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_commit}
\alias{vault_commit}
\title{Commit vault changes to git}
\usage{
vault_commit(message, vault = default_vault(), push = NULL)
}
\arguments{
\item{message}{Commit message.}

\item{vault}{Path to the vault directory.}

\item{push}{If \code{NULL} (default), honors \code{PENSAR_AUTO_PUSH}.
Pass \code{TRUE} or \code{FALSE} to override.}
}
\value{
\code{TRUE} if a commit was made, \code{FALSE} otherwise
  (invisibly).
}
\description{
No-op if the vault is not a git repo or if there are no changes.
Stages all changes (respecting \code{.gitignore}), commits with the
given message, and optionally pushes to remotes.
}
\details{
Honors the \code{PENSAR_AUTO_PUSH} environment variable: if set to
\code{"0"} or \code{"false"} (case-insensitive), skips the push
step. Otherwise, pushes to every configured remote. A rejected
push (another author pushed first) is retried once after
\code{git pull --rebase}; concurrent appends to \code{log.md}
rebase cleanly because \code{init_vault()} marks it
\code{merge=union}. A rebase that hits a real conflict is aborted,
leaving the local commit unpushed for manual reconciliation.

}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
# Returns FALSE invisibly: no .git in this temp vault.
vault_commit("noop", vault = v, push = FALSE)
unlink(v, recursive = TRUE)
}
