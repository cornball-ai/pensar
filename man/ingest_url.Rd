% tinyrox says don't edit this manually, but it can't stop you!
\name{ingest_url}
\alias{ingest_url}
\title{Ingest content from a URL}
\usage{
ingest_url(url, vault = default_vault(), type = "articles", title = NULL,
           tags = NULL)
}
\arguments{
\item{url}{URL to fetch.}

\item{vault}{Vault path.}

\item{type}{Ingest type. Default \code{"articles"}.}

\item{title}{Optional page title. If \code{NULL}, derived from
HTML \code{<title>}, or falls back to the URL.}

\item{tags}{Optional character vector of tags.}
}
\value{
The relative path of the written (or existing) page,
  invisibly.
}
\description{
Fetches \code{url} (10s timeout), refuses non-2xx responses or
content types outside text/JSON/XML, and writes the body into the
vault through \code{ingest()}. If the manifest already records this
URL as a source, returns the existing page path without re-fetching.
}
\details{
For HTML responses the page's \code{<title>} is extracted and used
as the page title when \code{title} is not supplied.

}
\examples{
\dontrun{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest_url("https://example.com", vault = v)
unlink(v, recursive = TRUE)
}
}
