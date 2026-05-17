% tinyrox says don't edit this manually, but it can't stop you!
\name{recent_activity}
\alias{recent_activity}
\title{Recent vault activity from log.md}
\usage{
recent_activity(vault = default_vault(), days = 7L)
}
\arguments{
\item{vault}{Vault path.}

\item{days}{Window in days. Default 7.}
}
\value{
A data.frame with columns \code{timestamp} (POSIXct),
  \code{operation}, \code{message}, sorted newest first.
}
\description{
Parses entries from \code{log.md} (the format written by
\code{log_entry()}). Returns entries from the last \code{days} days,
newest first.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
recent_activity(v, days = 30)
unlink(v, recursive = TRUE)
}
