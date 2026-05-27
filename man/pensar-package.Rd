% tinyrox says don't edit this manually, but it can't stop you!
\docType{package}
\name{pensar-package}
\alias{pensar}
\alias{pensar-package}
\title{\packageTitle{pensar}}
\description{\packageDescription{pensar}}
\details{
Per CRAN policy, pensar never writes to a default location in the
user's home filespace. Configure a vault path via one of:

\itemize{
\item \code{Sys.setenv(PENSAR_VAULT = "/path/to/vault")}
\item \code{pensar::use_vault("/path/to/vault")} (typically in
\code{~/.Rprofile})
\item Working from a directory containing \code{schema.md}, or
whose \code{vault/} subdir contains it (auto-detected via
walk-up from \code{getwd()})
\item Passing \code{vault =} (or \code{path =} for \code{init_vault()})
explicitly to each call
}

}
\section{Package Content}{\packageIndices{pensar}}
\author{\packageAuthor{pensar}}
\section{Maintainer}{\packageMaintainer{pensar}}
\keyword{internal}
