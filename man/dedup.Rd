% tinyrox says don't edit this manually, but it can't stop you!
\name{dedup}
\alias{dedup}
\title{Vault audits}
\usage{
dedup(vault = default_vault(), threshold = 0.7)
}
\arguments{
\item{vault}{Vault path.}

\item{threshold}{Minimum combined score, in [0, 1]. Default 0.7.}
}
\value{
A data.frame of proposed pairs (invisibly):
  \code{page_a}, \code{page_b}, \code{title_similarity},
  \code{tag_overlap}, \code{combined_score}. Sorted by combined
  score descending.
}
\description{
Read-only audits that surface duplicate-looking pages
and tag-vocabulary drift. Both write proposals to
\code{<vault>/_proposals/} for human review. Pensar never
auto-merges or auto-renames.
Find candidate duplicate pages

Compares every non-system page pair by Jaro-Winkler title similarity
and tag-set Jaccard overlap. Pairs whose combined score exceeds
\code{threshold} are written to \code{_proposals/dedup.md} for human
review.

The combined score weights title similarity at 0.6 and tag overlap
at 0.4 (\code{0.6 * jw_sim + 0.4 * tag_jaccard}). Title similarity
is computed on lowercased trimmed titles; pages with no title fall
back to \code{node_id}.

Pensar never auto-merges. The proposals file is for human review.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("A.", type = "articles", source = "alpha-foo", vault = v)
ingest("B.", type = "articles", source = "alpha-foos", vault = v)
dedup(v)
unlink(v, recursive = TRUE)
}
