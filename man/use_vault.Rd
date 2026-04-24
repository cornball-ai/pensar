% tinyrox says don't edit this manually, but it can't stop you!
\name{use_vault}
\alias{use_vault}
\title{Remember a vault path for this R session}
\usage{
use_vault(path)
}
\arguments{
\item{path}{Path to your pensar vault directory.}
}
\value{
The resolved path, invisibly.
}
\description{
Sets \code{options("pensar.vault")} so subsequent pensar calls
resolve to \code{path} without repeating the argument. Persist by
adding \code{pensar::use_vault("~/wiki")} to \code{~/.Rprofile}.
}
