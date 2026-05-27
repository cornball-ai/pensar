% tinyrox says don't edit this manually, but it can't stop you!
\name{update_manifest}
\alias{update_manifest}
\title{Update the pensar manifest for a vault}
\usage{
update_manifest(vault, source = NULL, path = NULL, page_uid = NULL,
                address = NULL, hash = NULL, ingested_at = NULL)
}
\arguments{
\item{vault}{Vault path.}

\item{source}{Source identifier (URL, session id, etc.). Optional.}

\item{path}{Relative path inside the vault that this update is
about. Required if any of the other fields are set.}

\item{page_uid}{Stable page identity from frontmatter
\code{id} / \code{address}. Goes into both the \code{sources}
record (when other source fields are set) and the
\code{address_map}.}

\item{address}{Alias for \code{page_uid} that only writes to
\code{address_map}. Useful when the caller wants to record an
address without touching the source record.}

\item{hash}{Content hash (typically \code{paste0("sha1:", ...)} from
\code{digest::digest()}).}

\item{ingested_at}{Timestamp string. Defaults to current time when
any source-shaped field is set.}
}
\value{
The manifest path, invisibly.
}
\description{
Patches a manifest record for one page. Writes \emph{only}
\code{.pensar/manifest.yml}; never edits other tools' manifest
formats (\code{.manifest.json}, \code{.raw/.manifest.json}).
}
\details{
\code{source}, \code{hash}, or \code{ingested_at} together write or
refresh a \code{sources[path]} record. \code{page_uid} (or
\code{address}, which is treated as an alias) writes an
\code{address_map[path]} record. A call with only \code{path} and
\code{page_uid} updates the address map without touching the
\code{sources} record.

}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
update_manifest(v, source = "demo",
                path = "raw/articles/demo.md",
                hash = "sha1:abc")
read_manifest(v)$sources[["raw/articles/demo.md"]]
unlink(v, recursive = TRUE)
}
