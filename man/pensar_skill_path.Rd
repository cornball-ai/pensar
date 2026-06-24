% tinyrox says don't edit this manually, but it can't stop you!
\name{pensar_skill_path}
\alias{pensar_skill_path}
\title{Locate pensar's bundled skill directory}
\usage{
pensar_skill_path(skill = NULL)
}
\arguments{
\item{skill}{Optional skill name (e.g., \code{"autoresearch"}).
\code{NULL} returns the bundle root.}
}
\value{
Absolute path. Returns an empty string when the skill is
  not installed (matching \code{system.file()} behavior).
}
\description{
Pensar ships markdown skill bundles under \code{inst/skills/pensar/}.
Returns the absolute path to the bundle root, or to a specific
skill when \code{skill} is given. Useful for symlinking pensar
skills into an agent's skill directory, e.g.
\code{ln -s $(Rscript -e 'cat(pensar::pensar_skill_path())') \
~/.claude/skills/pensar}.
}
\examples{
pensar_skill_path()
pensar_skill_path("autoresearch")
}
