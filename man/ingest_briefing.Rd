% tinyrox says don't edit this manually, but it can't stop you!
\name{ingest_briefing}
\alias{ingest_briefing}
\title{Briefing ingestion}
\usage{
ingest_briefing(project = NULL, vault = default_vault())
}
\arguments{
\item{project}{Project name. If \code{NULL}, inferred from the git
root of the current working directory.}

\item{vault}{Path to the vault directory.}
}
\value{
The path to the ingested briefing file, invisibly. Returns
  \code{NULL} invisibly if \code{saber} is not installed or the
  project cannot be inferred.
}
\description{
Generate a saber briefing and ingest it into the vault.
Generate and ingest a saber briefing

Calls \code{saber::briefing(project)} to produce a project briefing
and ingests it into the vault as a \code{briefings} raw source.
Requires the \code{saber} package.
}
