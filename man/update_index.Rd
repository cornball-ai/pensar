% tinyrox says don't edit this manually, but it can't stop you!
\name{update_index}
\alias{update_index}
\title{Vault index}
\usage{
update_index(vault = default_vault())
}
\arguments{
\item{vault}{Path to the vault directory.}
}
\value{
The path to \code{index.md}, invisibly.
}
\description{
Regenerate the vault index as a markdown catalog.
Update the vault index

Scans all markdown files in the vault and regenerates \code{index.md}
as a categorized catalog with wikilinks and titles.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("Body.", type = "articles", source = "demo", vault = v)
update_index(v)
unlink(v, recursive = TRUE)
}
