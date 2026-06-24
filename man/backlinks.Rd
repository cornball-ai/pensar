% tinyrox says don't edit this manually, but it can't stop you!
\name{backlinks}
\alias{backlinks}
\title{Find backlinks to a page}
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
Scans all markdown files in the vault for \code{[[wikilinks]]} that
reference the target page.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("See [[seed]] for context.", type = "articles",
       source = "demo", vault = v)
backlinks("seed", vault = v)
unlink(v, recursive = TRUE)
}
