% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_export}
\alias{vault_export}
\title{Static HTML export}
\usage{
vault_export(vault = default_vault(), out_dir = default_site_dir())
}
\arguments{
\item{vault}{Path to the vault directory.}

\item{out_dir}{Destination directory. Defaults to the R user cache
directory for pensar.}
}
\value{
The output directory path, invisibly.
}
\description{
Render the vault to a directory of static HTML files.
Export the vault to static HTML

Renders every markdown page in the vault to HTML, resolving
\code{[[wikilinks]]} to relative anchor tags. Output is a standalone
site that can be served from any static file server or opened via
\code{file://}.

The rendered site is regenerable from the vault, so it defaults to
the R user cache directory (\code{tools::R_user_dir("pensar",
"cache")/site}) rather than living inside the vault itself. Pass a
different \code{out_dir} to override, or set the
\code{PENSAR_SITE_DIR} environment variable to change the default
globally (e.g., point it at a Syncthing folder so edits propagate
to other devices on export).

Requires the \code{pandoc} command-line tool to be available.
}
