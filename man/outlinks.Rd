% tinyrox says don't edit this manually, but it can't stop you!
\name{outlinks}
\alias{outlinks}
\title{Outlink discovery}
\usage{
outlinks(page, vault = default_vault())
}
\arguments{
\item{page}{Page name (without \code{.md} extension).}

\item{vault}{Path to the vault directory.}
}
\value{
A data.frame with columns \code{target} (page name) and
  \code{exists} (logical: whether the target page exists in the vault).
}
\description{
Find the pages a given page cites via wikilinks.
Find outlinks from a page

Scans a single page for \code{[[wikilinks]]} and returns the targets.
Mirror of \code{backlinks()} in the forward direction.
}
