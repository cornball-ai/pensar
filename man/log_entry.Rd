% tinyrox says don't edit this manually, but it can't stop you!
\name{log_entry}
\alias{log_entry}
\title{Vault log}
\usage{
log_entry(message, operation = "note", vault = default_vault())
}
\arguments{
\item{message}{Description of what happened.}

\item{operation}{Operation type (e.g., \code{"init"}, \code{"ingest"},
\code{"lint"}).}

\item{vault}{Path to the vault directory.}
}
\value{
Invisible \code{NULL}.
}
\description{
Append-only operation log for a pensar vault.
Append a log entry

Appends a structured entry to \code{log.md} with timestamp, operation
type, and message.
}
