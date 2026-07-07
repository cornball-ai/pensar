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

\item{push}{If \code{NULL} (default), honors \code{PENSAR_AUTO_PUSH}
(own-repo vaults) or skips the push (nested vaults). Pass
\code{TRUE} or \code{FALSE} to override.}
}
\value{
\code{TRUE} if a commit was made, \code{FALSE} otherwise
  (invisibly).
}
\description{
No-op if the vault is not inside a git repo or if there are no
changes. Stages all changes under the vault (respecting
\code{.gitignore}), commits with the given message, and optionally
pushes to remotes.
}
\details{
The vault may be its own repo, or \strong{nested} inside a larger
repo (e.g. a project repo with the vault at \code{vault/}). Nested
vaults are handled conservatively: staging and the commit are
scoped to the vault subtree, so unrelated changes elsewhere in the
enclosing repo -- dirty or even already staged -- are never swept
into a pensar commit. Nested vaults also \strong{never auto-push}:
\code{PENSAR_AUTO_PUSH} is ignored, since pushing the enclosing
repo could carry unrelated unpushed commits. An explicit
\code{push = TRUE} pushes the enclosing repo's branch with a single
plain push (no rebase-retry automation).

For a vault that is its own repo, the push default is
configurable at two levels. Per vault: set \code{auto_push: false}
in \code{schema.md} frontmatter to turn auto-push off for that
vault alone (\code{auto_push: true} likewise forces it on,
overriding the environment). Per machine: the
\code{PENSAR_AUTO_PUSH} environment variable, where \code{"0"} or
\code{"false"} (case-insensitive) skips the push step. The
explicit \code{push} argument beats both. When nothing is
configured, pushes go to every configured remote. A rejected push
(another author pushed first) is retried once after
\code{git pull --rebase}; concurrent appends to \code{log.md}
rebase cleanly because \code{init_vault()} marks it
\code{merge=union}, and a stopped rebase is resolved by the
\code{vault_merge()} engine. A rebase that still fails is aborted,
leaving the local commit unpushed for manual reconciliation.

}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
# Returns FALSE invisibly: no .git in this temp vault.
vault_commit("noop", vault = v, push = FALSE)
unlink(v, recursive = TRUE)
}
