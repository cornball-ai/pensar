% tinyrox says don't edit this manually, but it can't stop you!
\name{autoresearch}
\alias{autoresearch}
\title{Autonomous research loop into a pensar vault}
\usage{
autoresearch(topic, vault = default_vault(), search_backend = NULL,
             fetch_backend = NULL, model_backend = NULL, program = NULL,
             force = FALSE, overwrite = TRUE, provider = "anthropic",
             model = NULL, verbose = TRUE)
}
\arguments{
\item{topic}{Character. Research topic, free-form string.}

\item{vault}{Character. Vault path.}

\item{search_backend}{Function with signature \code{function(query, n)}
returning a data.frame with at least \code{title}, \code{url}, and
\code{snippet}.}

\item{fetch_backend}{Function with signature \code{function(url)}
returning a list with \code{url}, \code{status_code},
\code{content_type}, \code{body}, and \code{fetched_at}.}

\item{model_backend}{Function with signature
\code{function(task, input, program)} returning structured lists for
the internal autoresearch tasks. When supplied, overrides
\code{provider} and \code{model}.}

\item{program}{Optional list or YAML path overriding the default
autoresearch program. Vault-level \code{_research/program.yml}
overrides package defaults when \code{program} is \code{NULL}.}

\item{force}{Logical. Allow writes into adopted vaults.}

\item{overwrite}{Logical. Allow planned wiki pages to overwrite
existing wiki files. Set \code{FALSE} to make existing-page updates
fail instead of replacing content.}

\item{provider}{Provider for the default \code{llm.api} model backend:
\code{"anthropic"}, \code{"openai"}, \code{"moonshot"},
\code{"ollama"}, \code{"auto"}, or \code{"heuristic"}.}

\item{model}{Optional model name for the default \code{llm.api}
backend.}

\item{verbose}{Logical. Print phase progress.}
}
\value{
A list of class \code{pensar_research} with topic, program,
  queries, search results, filed sources, extracted claims, written
  pages, synthesis metadata, and model usage.
}
\description{
Runs a bounded, package-owned research workflow. R controls the
loop, source ingestion, wiki writes, index refresh, and logging; model
calls are limited to structured decisions such as query planning,
source selection, evidence extraction, and page drafting.

The default search backend uses Tavily via \code{TAVILY_API_KEY}. The
default model backend uses \code{llm.api} when credentials are
available and otherwise falls back to deterministic heuristics. Tests
and integrations can pass fake \code{search_backend},
\code{fetch_backend}, and \code{model_backend} functions.
}
\examples{
\dontrun{
Sys.setenv(TAVILY_API_KEY = "tvly-...")
res <- autoresearch("transformer scaling laws")
print(res)
show_page(res$synthesis$slug)
}
}
