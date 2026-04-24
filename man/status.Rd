% tinyrox says don't edit this manually, but it can't stop you!
\name{status}
\alias{status}
\title{Vault status}
\usage{
status(vault = default_vault())
}
\arguments{
\item{vault}{Path to the vault directory.}
}
\value{
A list with class \code{pensar_status}.
}
\description{
Summary stats for a pensar vault.
Vault status summary

Returns page counts by category, total pages, and wikilink count.
}
