#' Autonomous research loop into a pensar vault
#'
#' @description
#' Runs a bounded, package-owned research workflow. R controls the
#' loop, source ingestion, wiki writes, index refresh, and logging; model
#' calls are limited to structured decisions such as query planning,
#' source selection, evidence extraction, and page drafting.
#'
#' The default search backend uses Tavily via \code{TAVILY_API_KEY}. The
#' default model backend uses \code{llm.api} when credentials are
#' available and otherwise falls back to deterministic heuristics. Tests
#' and integrations can pass fake \code{search_backend},
#' \code{fetch_backend}, and \code{model_backend} functions.
#'
#' @param topic Character. Research topic, free-form string.
#' @param vault Character. Vault path.
#' @param search_backend Function with signature \code{function(query, n)}
#'   returning a data.frame with at least \code{title}, \code{url}, and
#'   \code{snippet}.
#' @param fetch_backend Function with signature \code{function(url)}
#'   returning a list with \code{url}, \code{status_code},
#'   \code{content_type}, \code{body}, and \code{fetched_at}.
#' @param model_backend Function with signature
#'   \code{function(task, input, program)} returning structured lists for
#'   the internal autoresearch tasks. When supplied, overrides
#'   \code{provider} and \code{model}.
#' @param program Optional list or YAML path overriding the default
#'   autoresearch program. Vault-level \code{_research/program.yml}
#'   overrides package defaults when \code{program} is \code{NULL}.
#' @param overwrite Logical. Allow planned wiki pages to overwrite
#'   existing wiki files. Set \code{FALSE} to make existing-page updates
#'   fail instead of replacing content.
#' @param force Logical. Allow writes into adopted vaults.
#' @param provider Provider for the default \code{llm.api} model backend:
#'   \code{"anthropic"}, \code{"openai"}, \code{"moonshot"},
#'   \code{"ollama"}, \code{"auto"}, or \code{"heuristic"}.
#' @param model Optional model name for the default \code{llm.api}
#'   backend.
#' @param verbose Logical. Print phase progress.
#' @return A list of class \code{pensar_research} with topic, program,
#'   queries, search results, filed sources, extracted claims, written
#'   pages, synthesis metadata, and model usage.
#' @examples
#' \dontrun{
#' Sys.setenv(TAVILY_API_KEY = "tvly-...")
#' res <- autoresearch("transformer scaling laws")
#' print(res)
#' show_page(res$synthesis$slug)
#' }
#' @export
autoresearch <- function(topic, vault = default_vault(),
                         search_backend = NULL, fetch_backend = NULL,
                         model_backend = NULL, program = NULL, force = FALSE,
                         overwrite = TRUE, provider = "anthropic",
                         model = NULL, verbose = TRUE) {
    if (!is.character(topic) || length(topic) != 1L || !nzchar(topic)) {
        stop("`topic` must be a single non-empty string.", call. = FALSE)
    }
    vault <- normalizePath(vault, mustWork = TRUE)
    if (!file.exists(file.path(vault, "schema.md"))) {
        stop("Not a pensar vault: ", vault, ". Run init_vault() first.")
    }

    program <- load_autoresearch_program(vault = vault, program = program)
    search_backend <- search_backend %||% .default_search_backend()
    fetch_backend <- fetch_backend %||% .autoresearch_default_fetch_backend()
    model_backend <- model_backend %||%
    .autoresearch_default_model_backend(provider = provider, model = model)

    all_queries <- .empty_queries()
    all_queries$round <- integer()
    search_results <- .empty_search_results()
    search_results$round <- integer()
    selected <- data.frame(url = character(), reason = character(),
                           round = integer(), stringsAsFactors = FALSE)
    sources <- .empty_sources()
    sources$round <- integer()
    claims <- .empty_claims()
    claims$round <- integer()
    gaps <- .empty_gaps()
    rounds <- list()

    if (isTRUE(verbose)) {
        message("autoresearch: planning queries")
    }
    next_queries <- autoresearch_plan_queries(topic, program, model_backend)
    next_queries$gap <- ""

    for (round in seq_len(program$max_rounds)) {
        if (nrow(next_queries) == 0L) {
            break
        }
        round_queries <- next_queries
        round_queries$round <- as.integer(round)
        round_queries <- round_queries[, c("query", "angle", "gap", "round"),
            drop = FALSE]
        all_queries <- .autoresearch_bind_rows(all_queries, round_queries)

        if (isTRUE(verbose)) {
            message("autoresearch: round ", round, " searching ",
                    nrow(round_queries), " queries")
        }
        round_search <- autoresearch_run_searches(round_queries,
                                                  search_backend, program)
        round_search$round <- rep.int(as.integer(round), nrow(round_search))
        search_results <- .autoresearch_bind_rows(search_results, round_search)

        if (isTRUE(verbose)) {
            message("autoresearch: round ", round, " selecting sources")
        }
        round_selected <- autoresearch_select_sources(topic, round_search,
                                                      program, model_backend)
        if (nrow(round_selected) > 0L && nrow(selected) > 0L) {
            round_selected <- round_selected[
                !round_selected$url %in% selected$url,, drop = FALSE]
        }
        round_selected$round <- rep.int(as.integer(round),
                                        nrow(round_selected))
        selected <- .autoresearch_bind_rows(selected, round_selected)

        if (isTRUE(verbose)) {
            message("autoresearch: round ", round, " fetching and ingesting ",
                    nrow(round_selected), " sources")
        }
        round_sources <- autoresearch_fetch_and_ingest(round_selected,
                                                       fetch_backend, vault,
                                                       topic, force = force)
        round_sources$round <- rep.int(as.integer(round), nrow(round_sources))
        sources <- .autoresearch_bind_rows(sources, round_sources)

        if (isTRUE(verbose)) {
            message("autoresearch: round ", round, " extracting evidence")
        }
        round_claims <- autoresearch_extract_claims(topic, round_sources,
                                                    program, model_backend)
        round_claims$round <- rep.int(as.integer(round), nrow(round_claims))
        claims <- .autoresearch_bind_rows(claims, round_claims)

        rounds[[length(rounds) + 1L]] <- list(
            round = round,
            queries = round_queries,
            search_results = round_search,
            selected_sources = round_selected,
            sources = round_sources,
            claims = round_claims
        )

        if (round >= program$max_rounds) {
            break
        }
        if (isTRUE(verbose)) {
            message("autoresearch: round ", round, " analyzing gaps")
        }
        gap_plan <- autoresearch_analyze_gaps(topic, claims, sources,
                                              all_queries, program,
                                              model_backend, round)
        gaps <- .autoresearch_bind_rows(gaps, gap_plan$gaps)
        next_queries <- gap_plan$queries
    }

    existing_pages <- autoresearch_existing_pages(vault)

    if (isTRUE(verbose)) {
        message("autoresearch: planning pages")
    }
    pages <- autoresearch_plan_pages(topic, claims, sources, existing_pages,
                                     program, model_backend)

    if (isTRUE(verbose)) {
        message("autoresearch: writing ", nrow(pages$pages), " wiki pages")
    }
    written <- autoresearch_write_pages(pages$pages, vault, program,
                                        overwrite = overwrite,
                                        force = force)

    update_index(vault = vault)
    log_entry(
              sprintf("autoresearch on '%s': %d sources, %d pages",
                      topic, nrow(sources), nrow(written)),
              operation = "autoresearch",
              vault = vault
    )

    synthesis <- .autoresearch_synthesis_record(pages, written)
    structure(
              list(topic = topic,
                   program = program,
                   queries = all_queries,
                   search_results = search_results,
                   selected_sources = selected,
                   sources = sources,
                   claims = claims,
                   gaps = gaps,
                   existing_pages = existing_pages,
                   rounds = rounds,
                   pages = written,
                   synthesis = synthesis,
                   usage = .autoresearch_model_usage(model_backend)),
              class = "pensar_research"
    )
}

#' Print a pensar research session result
#' @param x A \code{pensar_research} object.
#' @param ... Unused.
#' @return \code{x}, invisibly.
#' @export
print.pensar_research <- function(x, ...) {
    cat("pensar research session\n")
    cat("  Topic:    ", x$topic, "\n", sep = "")
    cat("  Sources:  ", nrow(x$sources), "\n", sep = "")
    cat("  Claims:   ", nrow(x$claims), "\n", sep = "")
    cat("  Pages:    ", nrow(x$pages), "\n", sep = "")
    if (!is.null(x$synthesis) && nzchar(x$synthesis$slug)) {
        cat("  Synthesis: ", x$synthesis$slug, "\n", sep = "")
        cat("  Headline:  ", x$synthesis$headline, "\n", sep = "")
    } else {
        cat("  (no synthesis page written)\n")
    }
    invisible(x)
}

# ---- internals ----

#' Resolve the default search backend
#'
#' Returns a Tavily-backed function if \code{TAVILY_API_KEY} is set,
#' otherwise errors with a setup hint.
#'
#' @noRd
.default_search_backend <- function() {
    key <- Sys.getenv("TAVILY_API_KEY", unset = "")
    if (nzchar(key)) {
        function(query, n = 5L) .tavily_search(query, n, api_key = key)
    } else {
        stop("No search backend configured. Either:\n",
             "  - set TAVILY_API_KEY in your environment (free tier: https://tavily.com), or\n",
             "  - pass search_backend = function(query, n) { ... } returning",
             " data.frame(title, url, snippet)",
             call. = FALSE)
    }
}

#' Tavily search backend
#'
#' POSTs to api.tavily.com and returns up to \code{n} results as a
#' data.frame with columns \code{title}, \code{url}, \code{snippet}.
#'
#' @noRd
.tavily_search <- function(query, n = 5L,
                           api_key = Sys.getenv("TAVILY_API_KEY")) {
    if (!nzchar(api_key)) {
        stop("TAVILY_API_KEY not set", call. = FALSE)
    }
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
        stop("Tavily search requires the 'jsonlite' package.",
             call. = FALSE)
    }
    body <- jsonlite::toJSON(
                             list(api_key = api_key, query = query, max_results = as.integer(n)),
                             auto_unbox = TRUE
    )
    h <- curl::new_handle()
    curl::handle_setheaders(h, "Content-Type" = "application/json")
    curl::handle_setopt(h, post = TRUE, postfields = body)
    resp <- curl::curl_fetch_memory("https://api.tavily.com/search", handle = h)
    if (resp$status_code != 200L) {
        stop(sprintf("Tavily HTTP %d: %s", resp$status_code,
                     rawToChar(resp$content)),
             call. = FALSE)
    }
    data <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
    results <- data$results
    if (length(results) == 0L) {
        return(data.frame(title = character(),
                          url = character(),
                          snippet = character(),
                          stringsAsFactors = FALSE))
    }
    pick <- function(r, key, default = "") {
        v <- r[[key]]
        if (is.null(v)) {
            default
        } else {
            as.character(v)
        }
    }
    data.frame(
               title = vapply(results, pick, "", key = "title"),
               url = vapply(results, pick, "", key = "url"),
               snippet = substr(vapply(results, pick, "", key = "content"), 1L, 500L),
               stringsAsFactors = FALSE
    )
}
