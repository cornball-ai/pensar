% tinyrox says don't edit this manually, but it can't stop you!
\name{show_page}
\alias{show_page}
\title{Page inspection}
\usage{
show_page(page, vault = default_vault())
}
\arguments{
\item{page}{Page name (without \code{.md} extension).}

\item{vault}{Path to the vault directory.}
}
\value{
A list with class \code{pensar_page}.
}
\description{
Drill down into a page: content, outlinks, and backlinks.
Show a page with its connections

Returns the page content alongside its outgoing and incoming wikilinks.
Use this when you need to review or edit a page: the outlinks show what
raw sources the page cites; the backlinks show what depends on it.
}
