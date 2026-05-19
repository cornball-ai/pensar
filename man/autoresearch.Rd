% tinyrox says don't edit this manually, but it can't stop you!
\name{autoresearch}
\alias{autoresearch}
\title{Autonomous research loop into a pensar vault}
\usage{
autoresearch(topic, vault = default_vault(), search_backend = NULL,
             fetch_backend = NULL, model_backend = NULL, program = NULL,
             force = FALSE, overwrite = TRUE, update = TRUE, slug = NULL,
             provider = "auto", model = NULL, verbose = TRUE)
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

\item{update}{Logical. When \code{TRUE} (default), planned pages whose
slug matches an existing wiki page run through a \code{revise_page}
model task that reads the existing body and produces an edit-aware
revision, so hand-written prose survives a re-run. When
\code{FALSE}, the planner's new draft body replaces the existing
body wholesale.}

\item{slug}{Optional character. When supplied, force the synthesis
row's slug to this value, bypassing the title-overlap collision
guard. Useful for explicitly amending an existing wiki page
(\code{slug = "my-existing-page"} updates \code{wiki/my-existing-page.md}
in place) or naming a fresh synthesis page. The synthesis row is
the first \code{type == "analysis"} entry in the planner output,
else row 1. Other planned rows (concepts, entities) keep their
planner-assigned slugs and still go through normal collision and
dedup checks.}

\item{provider}{Provider for the default \code{llm.api} model backend:
\code{"auto"} (default; picks whichever of \code{ANTHROPIC_API_KEY},
\code{OPENAI_API_KEY}, or \code{MOONSHOT_API_KEY} is set),
\code{"anthropic"}, \code{"openai"}, \code{"moonshot"},
\code{"ollama"}, or \code{"heuristic"} (force the deterministic
fallback).}

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
vault <- file.path(tempdir(), "ar-example")
init_vault(vault, rproj = FALSE, agent_instructions = FALSE)
use_vault(vault)
Sys.setenv(TAVILY_API_KEY = "tvly-...")
res <- autoresearch("transformer scaling laws")
print(res)
show_page(res$synthesis$slug)
}
}
