% tinyrox says don't edit this manually, but it can't stop you!
\name{ingest}
\alias{ingest}
\title{Source ingestion}
\usage{
ingest(content, type = c("articles", "chats", "briefings", "matrix"), source,
       title = NULL, tags = NULL, vault = default_vault(), force = FALSE)
}
\arguments{
\item{content}{Character string or character vector (lines) of content.}

\item{type}{Content type: \code{"articles"}, \code{"chats"}, or
\code{"matrix"}. The legacy type \code{"briefings"} is still accepted
but deprecated; for repo artifacts use \code{\link{ingest_repo}()}.}

\item{source}{Short identifier for the content source (e.g., URL,
session ID, project name).}

\item{title}{Optional title. If \code{NULL}, derived from source.}

\item{tags}{Optional character vector of tags.}

\item{vault}{Path to the vault directory.}

\item{force}{In adopted vaults (\code{init_vault(adopt = TRUE)}),
\code{ingest()} refuses to write by default. Pass \code{TRUE} to
write into the adopted tree anyway. Native vaults ignore this
parameter.}
}
\value{
The path to the written file, invisibly.
}
\description{
Ingest content into a pensar vault.
Ingest content into the vault

Writes content to \code{raw/{type}/}, generates a filename from source
and date, adds YAML frontmatter, updates \code{index.md}, and appends
to \code{log.md}.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("Hello, world.", type = "articles", source = "demo",
       vault = v)
status(v)
unlink(v, recursive = TRUE)
}
