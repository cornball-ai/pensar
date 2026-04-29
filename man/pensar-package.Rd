% tinyrox says don't edit this manually, but it can't stop you!
\docType{package}
\name{pensar-package}
\alias{pensar}
\alias{pensar-package}
\title{pensar: LLM Wiki Engine}
\description{
Maintains a persistent, compounding knowledge base of markdown files
for large language model agents to summarize, cross-reference, and
edit. Humans curate sources; the agent maintains the wiki.
Per CRAN policy, pensar never writes to a default location in the
user's home filespace. Configure a vault path via one of:
\itemize{
\item \code{Sys.setenv(PENSAR_VAULT = "/path/to/vault")}
\item \code{pensar::use_vault("/path/to/vault")} (typically in
\code{~/.Rprofile})
\item Working from a directory containing \code{schema.md}
(auto-detected via walk-up from \code{getwd()})
\item Passing \code{vault =} (or \code{path =} for \code{init_vault()})
explicitly to each call
}
}
\author{
\strong{Maintainer}: Troy Hernandez \email{troy@cornball.ai}
}
\keyword{internal}
