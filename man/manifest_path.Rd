% tinyrox says don't edit this manually, but it can't stop you!
\name{manifest_path}
\alias{manifest_path}
\title{Canonical manifest path inside a vault}
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
