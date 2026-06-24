% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_registry}
\alias{vault_registry}
\title{Build a structured registry of a vault's pages}
\usage{
vault_registry(vault = default_vault(), cache = c("session", "user", "none"),
               refresh = FALSE)
}
\arguments{
\item{vault}{Vault path.}

\item{cache}{Cache policy: \code{"session"} (default), \code{"user"},
or \code{"none"}.}

\item{refresh}{If \code{TRUE}, rebuild and overwrite the cache.}
}
\value{
A data.frame with columns: \code{path}, \code{node_id},
  \code{page_uid}, \code{title}, \code{aliases}, \code{type},
  \code{category}, \code{tags}, \code{sources}, \code{links_out},
  \code{system_file}. Aliases / tags / links_out are list-columns.
  The \code{type} and \code{category} fields come from frontmatter
  verbatim; callers compute an effective type as \code{type}
  when present, falling back to \code{category} otherwise.
}
\description{
Scans every \code{.md} file in \code{vault} and returns a data.frame
with one row per page. Used internally to resolve wikilinks and
query frontmatter without re-scanning the filesystem on every call.
}
\details{
\strong{Identity columns:}
\itemize{
\item \code{node_id} is the current link-resolution identity
(path-aware basename via \code{name_from_path()}). This is what
\code{[[page]]} matches against.
\item \code{page_uid} is a stable identity sourced from frontmatter
\code{id:} or \code{address:}. \code{NA} if the page declares
neither. Stable identity is opt-in via frontmatter; pensar never
fabricates one from a path hash, because path hashes change on
rename.
}

\strong{Cache} levels:
\itemize{
\item \code{"session"} (default): memoized in a package-level
environment, keyed by vault path. No disk write. Invalidates when
any \code{.md} file's mtime changes.
\item \code{"user"}: persisted to
\code{tools::R_user_dir("pensar", "cache")}. CRAN-safe location;
never writes inside the vault itself (\code{.pensar/} is reserved
for vault-owned state).
\item \code{"none"}: rebuild on every call.
}

}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
ingest("Body cites [[other]].", type = "articles", source = "demo",
       vault = v)
reg <- vault_registry(v)
nrow(reg)
unlink(v, recursive = TRUE)
}
