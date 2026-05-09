% tinyrox says don't edit this manually, but it can't stop you!
\name{ingest_briefing}
\alias{ingest_briefing}
\title{Briefing ingestion (deprecated)}
\usage{
ingest_briefing(project = NULL, scan_dir = path.expand("~"),
                vault = default_vault())
}
\arguments{
\item{project}{Project name. If \code{NULL}, inferred from the git
root of the current working directory.}

\item{scan_dir}{Directory to search for the project. Defaults to
\code{path.expand("~")}.}

\item{vault}{Path to the vault directory.}
}
\value{
Invisibly, the path(s) written by \code{ingest_repo()}.
}
\description{
\strong{Deprecated.} Use \code{\link{ingest_repo}()} with the default
\code{enrich = "auto"} (which writes a \code{briefing.md} for R packages
under \code{raw/repos/<name>/}) instead. This function now delegates to
\code{ingest_repo()} after warning.
}
\examples{
\dontrun{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest_briefing(project = "pensar", vault = v)
}
}
