% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_commit}
\alias{vault_commit}
\title{Vault git operations}
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
Auto-commit and push for pensar vaults that are git repos.
Commit vault changes to git

No-op if the vault is not a git repo or if there are no changes.
Stages all changes (respecting \code{.gitignore}), commits with the
given message, and optionally pushes to remotes.

Honors the \code{PENSAR_AUTO_PUSH} environment variable: if set to
\code{"0"} or \code{"false"} (case-insensitive), skips the push
step. Otherwise, pushes to every configured remote.
}
