% tinyrox says don't edit this manually, but it can't stop you!
\name{migrate_briefings_to_repos}
\alias{migrate_briefings_to_repos}
\title{Migrate legacy briefings to the repo provenance layout}
\usage{
migrate_briefings_to_repos(vault = default_vault(), dry_run = TRUE,
                           drop_old = TRUE,
                           rename_map = c(llamaR = "corteza", llamar = "corteza"))
}
\arguments{
\item{vault}{Path to the vault.}

\item{dry_run}{If \code{TRUE} (default), prints planned moves and link
rewrites without touching files. Set \code{FALSE} to apply.}

\item{drop_old}{If \code{TRUE} (default), removes superseded dated
briefings after the chosen file is moved. If \code{FALSE}, leaves
them in place.}

\item{rename_map}{Named character vector mapping legacy slug stems to
current repo names. Defaults handle the \code{llamaR -> corteza}
rename. Pass an extended map if your vault carries other renames.}
}
\value{
Invisibly, a data.frame with columns \code{file},
  \code{repo}, \code{artifact}, \code{action}, \code{destination}.
}
\description{
Walks \code{raw/briefings/}, classifies each file as a briefing or AST
artifact, maps the slug to a repo name, keeps the newest file per
\code{(repo, artifact)} pair, and moves it to
\code{raw/repos/<repo>/<artifact>.md}. Older duplicates are dropped if
\code{drop_old = TRUE} (git history retains them).
}
\details{
Wikilinks are rewritten in \code{wiki/*.md} only -- \code{raw/} is left
untouched, per the immutability rule. Aliases (e.g.
\code{[[2026-04-30-corteza|corteza]]}) are preserved.

Run with \code{dry_run = TRUE} (the default) first and review the
planned operations before committing.

}
