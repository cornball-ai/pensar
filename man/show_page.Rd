% tinyrox says don't edit this manually, but it can't stop you!
\name{show_page}
\alias{show_page}
\title{Show a page with its connections}
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
Returns the page content alongside its outgoing and incoming wikilinks.
Use this when you need to review or edit a page: the outlinks show what
raw sources the page cites; the backlinks show what depends on it.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
fp <- ingest("Body text.", type = "articles", source = "demo",
             vault = v)
show_page(tools::file_path_sans_ext(basename(fp)), vault = v)
unlink(v, recursive = TRUE)
}
