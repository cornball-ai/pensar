% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_export}
\alias{vault_export}
\title{Export the vault to static HTML}
\usage{
vault_export(vault = default_vault(), out_dir = default_site_dir())
}
\arguments{
\item{vault}{Path to the vault directory.}

\item{out_dir}{Destination directory. No default: pass an explicit
path or set \code{PENSAR_SITE_DIR} (per CRAN policy, pensar will
not silently render into a home-filespace location).}
}
\value{
The output directory path, invisibly.
}
\description{
Renders every markdown page in the vault to HTML, resolving
\code{[[wikilinks]]} to relative anchor tags. Output is a standalone
site that can be served from any static file server or opened via
\code{file://}.
}
\details{
No default \code{out_dir}: pass an explicit path or set the
\code{PENSAR_SITE_DIR} environment variable. Per CRAN policy
pensar will not silently render into a home-filespace location
(e.g., \code{tools::R_user_dir()}). \code{PENSAR_SITE_DIR} is the
recommended escape hatch -- point it at a Syncthing folder so edits
propagate to other devices on export.

Requires the \code{pandoc} command-line tool to be available.

Export is incremental. The first export to a given \code{out_dir} is a
full build; subsequent exports re-render only pages whose source
changed, plus any page whose wikilinks point at a name that was
added, removed, or moved (so broken/resolved links stay correct).
State is kept in \code{.pensar-export-cache.yml} inside \code{out_dir};
delete it to force a full rebuild. The stylesheet and site index are
always regenerated (they don't invoke pandoc).

}
\examples{
\donttest{
if (nzchar(Sys.which("pandoc"))) {
    v <- tempfile("vault-")
    init_vault(v, rproj = FALSE, agent_instructions = FALSE)
    ingest("Body.", type = "articles", source = "demo", vault = v)
    vault_export(v, out_dir = tempfile("site-"))
    unlink(v, recursive = TRUE)
}
}
}
