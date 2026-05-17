% tinyrox says don't edit this manually, but it can't stop you!
\name{init_vault}
\alias{init_vault}
\title{Vault initialization}
\usage{
init_vault(path = default_vault(), rproj = TRUE, agent_instructions = TRUE,
           adopt = FALSE, commit = NULL, force = FALSE)
}
\arguments{
\item{path}{Path to the vault directory. No implicit default: pass
an explicit path, or configure one via \code{PENSAR_VAULT},
\code{use_vault()}, or a walk-up \code{schema.md} marker (either
in the current directory or in a \code{vault/} subdir). Per CRAN
policy pensar will not silently write to the user's home
filespace.}

\item{rproj}{If \code{TRUE} (default), also write an RStudio project
file (\code{{basename(path)}.Rproj}). The project file makes a
vault stored under a hidden directory (e.g., one configured via
\code{PENSAR_VAULT} pointing at \code{~/.local/share/...}) easy to
open as an RStudio project, since RStudio's GUI normally refuses
to create projects inside hidden folders. Code indexing is
disabled in the project file since the vault contents are
markdown, not R source. The file is a harmless ~14-line INI stub;
delete it anytime if you prefer not to use RStudio. Pass
\code{rproj = FALSE} to skip it entirely.}

\item{agent_instructions}{If \code{TRUE} (default), write
\code{CLAUDE.md} and \code{AGENTS.md} with identical content
orienting an AI agent to work in this vault (CLI reminders,
editing rules, ingest workflow). If you don't plan to start an
AI agent session in the vault, pass \code{FALSE}.}

\item{adopt}{Opt-in read-only adopt mode. When \code{TRUE} the
function writes only a minimal adopted \code{schema.md} (carrying
\code{adopted: true} frontmatter), plus \code{log.md} and
\code{index.md} if absent. No \code{raw/} or \code{wiki/}
scaffolding is created and no auto-commit runs. Use this when
pointing pensar at an existing Obsidian vault whose layout you
don't want to change. After adoption, \code{update_index()} and
\code{status()} switch to registry-driven enumeration; reads
work normally and \code{ingest()} refuses writes unless
\code{force = TRUE}.}

\item{commit}{Auto-commit gate. \code{NULL} (default) commits the
initial scaffold only when the target directory is pensar-owned
(empty, or already shaped like a pensar vault). \code{TRUE} commits
unconditionally (after \code{force = TRUE} writes); \code{FALSE}
skips the commit even for pensar-owned directories. Forcing pensar
into foreign content does not by itself grant permission to commit
to that content's history.}

\item{force}{Write gate. \code{FALSE} (default) refuses to scaffold
when the target directory already contains files or a git history
that aren't pensar's. \code{TRUE} scaffolds anyway. Use sparingly.}
}
\value{
The vault path, invisibly. Returns \code{NULL} invisibly when
  the safety gate refused to scaffold.
}
\description{
Create and seed a pensar vault.
Initialize a pensar vault

Creates the vault directory structure and seeds the control files:
\code{schema.md}, \code{index.md}, \code{log.md}, and (by default)
agent instruction files for Claude Code and Codex.
}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
list.files(v, recursive = TRUE)
unlink(v, recursive = TRUE)
}
