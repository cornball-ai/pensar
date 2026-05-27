% tinyrox says don't edit this manually, but it can't stop you!
\name{tags}
\alias{tags}
\title{Audit tag usage against a controlled vocabulary}
\usage{
tags(vault = default_vault(), taxonomy = NULL, near_miss_threshold = 0.15)
}
\arguments{
\item{vault}{Vault path.}

\item{taxonomy}{Optional path to a taxonomy file. Defaults to
\code{<vault>/_meta/taxonomy.md} when present, otherwise no
taxonomy is loaded and the report lists all used tags by
frequency.}

\item{near_miss_threshold}{Maximum Jaro-Winkler distance for an
unknown tag to be suggested as a typo of a taxonomy entry.
Default 0.15.}
}
\value{
A list with components \code{used} (data.frame of tag /
  count), \code{unknown} (data.frame of unknown tags with optional
  suggestions), and \code{unused_taxonomy} (character vector of
  taxonomy entries with zero usage). Invisible.
}
\description{
Reads every tag from the registry, optionally compares against a
taxonomy file (\code{_meta/taxonomy.md}, a markdown bullet list of
allowed tags), and writes a proposals report to
\code{_proposals/tags.md}. Unknown tags get near-miss suggestions
via Jaro-Winkler distance against the taxonomy.
}
\details{
Pensar never auto-renames. The proposals file is for human review.

}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("hi", type = "articles", source = "demo",
       tags = c("foo", "bar"), vault = v)
tags(v)
unlink(v, recursive = TRUE)
}
