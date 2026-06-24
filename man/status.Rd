% tinyrox says don't edit this manually, but it can't stop you!
\name{status}
\alias{status}
\title{Vault status summary}
\usage{
status(vault = NULL)
}
\arguments{
\item{vault}{Path to the vault directory. \code{NULL} (default)
triggers automatic resolution.}
}
\value{
A list with class \code{pensar_status}, including the
  resolved \code{vault} path and a \code{source} label
  (\code{"env"}, \code{"walkup"}, \code{"walkup-subdir"},
  \code{"option"}, or \code{"explicit"}).
}
\description{
Returns page counts by category, total pages, and wikilink count.
When \code{vault} is \code{NULL} (default), the vault is resolved
via \code{PENSAR_VAULT}, walk-up from \code{getwd()}, or
\code{options("pensar.vault")}, and the source of the match is
recorded for display.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
status(v)
unlink(v, recursive = TRUE)
}
