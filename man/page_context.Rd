% tinyrox says don't edit this manually, but it can't stop you!
\name{page_context}
\alias{page_context}
\title{Structured context for a single page}
\usage{
page_context(name, vault = default_vault(), body_chars = 300L)
}
\arguments{
\item{name}{Page name, path, alias, or page_uid.}

\item{vault}{Vault path.}

\item{body_chars}{Maximum chars of body to return. Default 300.}
}
\value{
A list with components \code{path} (relative path),
  \code{node_id}, \code{frontmatter} (named list), \code{body_head}
  (string), \code{outlinks} (data.frame), \code{backlinks}
  (data.frame), \code{class = "pensar_page_context"}.
}
\description{
Returns the frontmatter, a short body head, the page's outlinks, and
its backlinks in one struct so callers don't have to call four
functions. Resolves \code{name} through the registry, so a query
like \code{"Notes/Foo"} works alongside the basename style.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
fp <- ingest("Body text here.", type = "articles", source = "demo",
             vault = v)
ctx <- page_context(tools::file_path_sans_ext(basename(fp)),
                    vault = v)
names(ctx)
unlink(v, recursive = TRUE)
}
