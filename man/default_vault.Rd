% tinyrox says don't edit this manually, but it can't stop you!
\name{default_vault}
\alias{default_vault}
\title{Resolve the active vault path}
\usage{
default_vault()
}
\value{
Character string: the normalized vault path. Errors if no
  vault is configured.
}
\description{
Returns the path of the vault pensar will act on, resolved from the
same opt-in sources as every other entry point: the
\code{PENSAR_VAULT} environment variable, a walk-up for
\code{schema.md}, then \code{options("pensar.vault")} (set by
\code{\link{use_vault}}). This is the public getter paired with the
\code{use_vault()} setter; call it to confirm which vault a bare
\code{\link{ingest}()} or \code{\link{status}()} will use before
running them.
}
\details{
Per CRAN policy there is no implicit home-filespace fallback. If no
source is configured this errors with a setup hint rather than
guessing a path. For the resolution source as well as the path
(useful when debugging "why is it filing to the wrong vault?"), call
\code{\link{status}()}, which reports both.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
use_vault(v)
default_vault()
options(pensar.vault = NULL)
unlink(v, recursive = TRUE)
}
\seealso{
\code{\link{use_vault}} to set the vault for a session.
}
