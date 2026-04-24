% tinyrox says don't edit this manually, but it can't stop you!
\name{init_vault}
\alias{init_vault}
\title{Vault initialization}
\usage{
init_vault(path = default_vault(), rproj = TRUE, agent_instructions = TRUE)
}
\arguments{
\item{path}{Path to the vault directory. Defaults to the standard
R user data directory for pensar.}

\item{rproj}{If \code{TRUE} (default), also write an RStudio project
file (\code{{basename(path)}.Rproj}). RStudio's GUI refuses to
create projects inside hidden folders like \code{~/.local/share/},
which is where the default vault lives. Seeding the project file
during init_vault() sidesteps that limitation so the vault opens
cleanly as a project. Code indexing is disabled in the project
file since the vault contents are markdown, not R source. The file
is a harmless ~14-line INI stub; delete it anytime if you prefer
not to use RStudio. Pass \code{rproj = FALSE} to skip it entirely.}

\item{agent_instructions}{If \code{TRUE} (default), write
\code{CLAUDE.md} and \code{AGENTS.md} with identical content
orienting an AI agent to work in this vault (CLI reminders,
editing rules, ingest workflow). If you don't plan to start an
AI agent session in the vault, pass \code{FALSE}.}
}
\value{
The vault path, invisibly.
}
\description{
Create and seed a pensar vault.
Initialize a pensar vault

Creates the vault directory structure and seeds the control files:
\code{schema.md}, \code{index.md}, \code{log.md}, and (by default)
agent instruction files for Claude Code and Codex.
}
