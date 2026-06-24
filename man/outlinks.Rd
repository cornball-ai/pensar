% tinyrox says don't edit this manually, but it can't stop you!
\name{outlinks}
\alias{outlinks}
\title{Find outlinks from a page}
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
Scans a single page for \code{[[wikilinks]]} and returns the targets.
Mirror of \code{backlinks()} in the forward direction.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
fp <- ingest("Cites [[seed]] and [[missing]].", type = "articles",
             source = "demo", vault = v)
outlinks(tools::file_path_sans_ext(basename(fp)), vault = v)
unlink(v, recursive = TRUE)
}
