% tinyrox says don't edit this manually, but it can't stop you!
\name{read_manifest}
\alias{read_manifest}
\title{Read the pensar manifest for a vault}
\usage{
read_manifest(vault)
}
\arguments{
\item{vault}{Vault path.}
}
\value{
A list with components \code{version} (integer),
  \code{created} (\code{YYYY-MM-DD} string), \code{sources}
  (named list of per-source records), and \code{address_map}
  (named list mapping relative path to page_uid).
}
\description{
Returns a normalized list with \code{version}, \code{created},
\code{sources}, and \code{address_map} fields. When the manifest
file is missing, returns a fresh empty struct with the current date
as \code{created}; the manifest file is not written.
}
\details{
Malformed YAML logs a warning and returns the empty struct so callers
can keep going.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
read_manifest(v)$sources
unlink(v, recursive = TRUE)
}
