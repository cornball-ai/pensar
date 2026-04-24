% tinyrox says don't edit this manually, but it can't stop you!
\name{lint}
\alias{lint}
\title{Vault lint}
\usage{
lint(vault = default_vault(), min_cluster_size = 3L)
}
\arguments{
\item{vault}{Path to the vault directory.}

\item{min_cluster_size}{Minimum number of raw pages sharing a tag to
suggest a wiki page. Default 3.}
}
\value{
A list with class \code{pensar_lint}.
}
\description{
Health check for a pensar vault.
Vault health check

Scans the vault for orphan pages (no incoming wikilinks), broken
wikilinks (pointing to nonexistent pages), and tag clusters with no
wiki synthesis.
}
