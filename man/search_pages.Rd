% tinyrox says don't edit this manually, but it can't stop you!
\name{search_pages}
\alias{search_pages}
\title{Search pages by title, tags, aliases, or (optionally) body}
\usage{
search_pages(query, vault = default_vault(), type = NULL, in_body = FALSE)
}
\arguments{
\item{query}{Substring to search for.}

\item{vault}{Vault path.}

\item{type}{Optional type filter. When supplied, only pages whose
registry \code{type} field equals \code{type} are considered.}

\item{in_body}{If \code{TRUE}, also search the body of each page.}
}
\value{
A data.frame with columns \code{path}, \code{node_id},
  \code{title}, \code{type}, and \code{matched_in} (character
  identifying where the substring was found: \code{"title"},
  \code{"tag:<tag>"}, \code{"alias:<alias>"}, or \code{"body"}).
}
\description{
Substring match (case-insensitive). Default scope is registry-only
fields: \code{title}, \code{tags}, and frontmatter \code{aliases}.
With \code{in_body = TRUE} the body of each page is scanned too;
that reads every file and is slower.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("Body cites [[other]].", type = "articles",
       source = "demo-article", vault = v)
search_pages("demo", vault = v)
unlink(v, recursive = TRUE)
}
