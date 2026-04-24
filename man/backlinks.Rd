% tinyrox says don't edit this manually, but it can't stop you!
\name{backlinks}
\alias{backlinks}
\title{Backlink discovery}
\usage{
backlinks(page, vault = default_vault())
}
\arguments{
\item{page}{Page name (without \code{.md} extension).}

\item{vault}{Path to the vault directory.}
}
\value{
A data.frame with columns \code{source} (page name) and
  \code{file} (path relative to the vault).
}
\description{
Find pages that link to a given page via wikilinks.
Find backlinks to a page

Scans all markdown files in the vault for \code{[[wikilinks]]} that
reference the target page.
}
