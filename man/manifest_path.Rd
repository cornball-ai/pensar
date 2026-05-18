% tinyrox says don't edit this manually, but it can't stop you!
\name{manifest_path}
\alias{manifest_path}
\title{Vault manifest}
\usage{
manifest_path(vault)
}
\arguments{
\item{vault}{Vault path.}
}
\value{
Absolute path to the manifest file.
}
\description{
Pensar-owned bookkeeping at \code{.pensar/manifest.yml}:
per-source ingest provenance and an opt-in \code{path -> page_uid}
address map. Read by retrieval primitives that need delta info;
written by \code{ingest()} and \code{ingest_repo()} after a
successful page write. Read-only operations
(\code{vault_registry()}, \code{update_index()}, \code{status()})
never touch the manifest.
Canonical manifest path inside a vault

Returns \code{<vault>/.pensar/manifest.yml}. The directory is created
lazily by \code{update_manifest()} so simply asking for the path
doesn't materialize \code{.pensar/}.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
manifest_path(v)
unlink(v, recursive = TRUE)
}
