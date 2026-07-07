% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_merge}
\alias{vault_merge}
\title{Resolve a stopped git merge or rebase in the vault}
\usage{
vault_merge(vault = default_vault())
}
\arguments{
\item{vault}{Path to the vault directory.}
}
\value{
Invisibly, a data frame with one row per resolved path
  (columns \code{path}, \code{class}, \code{kept}, \code{digested}),
  or \code{NULL} when no merge or rebase was in progress.
}
\description{
Resolves every conflicted path mechanically where the correct
result is computable, and files genuine divergence into a committed
digest at \code{.pensar/merge-conflicts.md} for later synthesis.
The vault is never left mid-merge: after resolution the rebase is
continued (or the merge committed).
}
\details{
Resolution by class:
\itemize{
\item \code{index.md}: regenerated from the merged tree.
\item \code{.pensar/manifest.yml}: unioned by path and pruned to
the merged tree (see \code{merge_manifest_structs()}).
\item \code{log.md} and the digest itself: line union (both
sides' appended lines survive), covering vaults whose
\code{.gitattributes} predates the union-merge scaffold.
\item Raw add/add collisions: both files kept; the incoming side
is renamed with a numeric suffix and its manifest record is
re-keyed. Raw is ground truth; nothing is discarded.
\item Wiki (and other markdown) pages: a strict superset side
wins outright; otherwise the side with valid frontmatter and
strictly fewer broken wikilinks wins and the discarded version
goes to the digest; otherwise the current branch's side is kept
and both full versions go to the digest.
}

Digest entries carry a content-derived id (path + both blob shas +
class), so re-running the resolution is idempotent. Entries embed
both full versions inside code fences and use plain paths, never
wikilinks, so the digest stays out of the link graph.

\strong{Nested vaults} (a vault directory inside a larger repo)
are resolved conservatively: only conflicts under the vault
subtree are touched. If the stopped merge or rebase also has
conflicts outside the vault, the vault resolutions are staged and
the merge/rebase is left in place for the human to finish; pensar
never completes a merge that still has non-vault conflicts, and
never aborts one it did not start.

}
\examples{
v <- tempfile("vault-")
init_vault(v, rproj = FALSE, agent_instructions = FALSE)
# No git repo, nothing stopped: returns NULL with a message.
vault_merge(v)
unlink(v, recursive = TRUE)
}
