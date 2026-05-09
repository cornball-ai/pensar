% tinyrox says don't edit this manually, but it can't stop you!
\name{ingest_repo}
\alias{ingest_repo}
\title{Repo ingestion}
\usage{
ingest_repo(path, name = NULL, ref = "HEAD",
            enrich = c("auto", "package", "none"),
            artifacts = c("briefing", "ast", "snapshot"), files = NULL,
            tags = NULL, vault = default_vault())
}
\arguments{
\item{path}{Path to a local git repo. Tilde-expanded.}

\item{name}{Repo identifier used as the directory name under
\code{raw/repos/}. Defaults to \code{basename(path)}.}

\item{ref}{Git ref to snapshot. Default \code{"HEAD"}.}

\item{enrich}{One of \code{"auto"} (detect R package and enrich),
\code{"package"} (force package digest; errors if no DESCRIPTION),
or \code{"none"} (snapshot only). Default \code{"auto"}.}

\item{artifacts}{Subset of \code{c("briefing", "ast", "snapshot")} to
write. Default writes all that apply for the chosen enrich mode.}

\item{files}{Optional file globs (relative to the repo root) whose
tracked paths are listed in \code{snapshot.md}. Contents are not
stored. Default \code{"R/*.R"} for R packages, \code{NULL} otherwise.}

\item{tags}{Optional character vector of tags applied to every written
artifact.}

\item{vault}{Path to the vault directory.}
}
\value{
Character vector of paths written, invisibly.
}
\description{
Ingest a git repo's metadata, briefing, and AST into the vault.
Ingest a repository snapshot into the vault

Captures repo state pinned to a commit SHA so wiki claims can cite a
specific point in time. Writes one or more artifacts under
\code{raw/repos/<name>/<artifact>.md}:
\describe{
  \item{briefing.md}{\code{type: repo-briefing} -- saber digest of HEAD
    (regenerable). Requires the \code{saber} package.}
  \item{ast.md}{\code{type: repo-ast} -- exported and internal symbols
    from \code{saber::symbols()} (regenerable). Requires \code{saber}.}
  \item{snapshot.md}{\code{type: repo-snapshot} -- commit-pinned
    metadata: SHA, origin URL, branch, tracked file listing, recent
    commits.}
}

Re-running overwrites the artifact files in place; git tracks history.
This supersedes \code{ingest_briefing()}, which is now deprecated.
}
\examples{
\dontrun{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest_repo("~/corteza", vault = v)
}
}
