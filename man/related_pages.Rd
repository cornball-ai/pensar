% tinyrox says don't edit this manually, but it can't stop you!
\name{related_pages}
\alias{related_pages}
\title{Pages related to a target by shared tags + co-citation}
\usage{
related_pages(name, vault = default_vault(), k = 10L)
}
\arguments{
\item{name}{Page to find related pages for. Same resolution as
\code{find_page()}.}

\item{vault}{Vault path.}

\item{k}{Number of related pages to return. Default 10.}
}
\value{
A data.frame with columns \code{path}, \code{node_id},
  \code{title}, \code{score}, sorted by score descending then path.
}
\description{
Heuristic scoring: \code{score = #shared tags + #shared outlinks}.
Both are unweighted set intersections. The target page itself is
excluded from the result. Ties are broken by alphabetical
\code{path}.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
fp <- ingest("[[other]]", type = "articles", source = "a",
             tags = c("x", "y"), vault = v)
ingest("[[other]]", type = "articles", source = "b",
       tags = c("x"), vault = v)
related_pages(tools::file_path_sans_ext(basename(fp)),
              vault = v, k = 5)
unlink(v, recursive = TRUE)
}
