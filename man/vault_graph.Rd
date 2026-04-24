% tinyrox says don't edit this manually, but it can't stop you!
\name{vault_graph}
\alias{vault_graph}
\title{Vault wikilink graph}
\usage{
vault_graph(vault = default_vault(), width = 1600L, height = 1200L, ...)
}
\arguments{
\item{vault}{Path to the vault directory.}

\item{...}{Passed through to \code{saber::graph_svg()} (e.g.,
\code{iterations}, \code{seed}).}

\item{width,height}{Viewport in pixels. Defaults (1600 x 1200) are
larger than \code{saber::graph_svg()}'s defaults since vaults tend
toward many nodes.}
}
\value{
Character vector of SVG lines. Write with \code{writeLines()}.
}
\description{
Render the vault's wikilink graph as SVG via saber.
Render a vault's wikilink graph as SVG

Scans every markdown page in the vault (excluding control files),
extracts \code{[[wikilinks]]} as edges, and renders the result via
\code{saber::graph_svg()}. Node tooltips carry the page type, tags,
and date from YAML frontmatter; broken wikilinks (targets with no
matching page) appear as external nodes with a distinct tooltip.
}
