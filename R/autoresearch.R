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
#' @param update Logical. When \code{TRUE} (default), planned pages whose
#'   slug matches an existing wiki page run through a \code{revise_page}
#'   model task that reads the existing body and produces an edit-aware
#'   revision, so hand-written prose survives a re-run. When
#'   \code{FALSE}, the planner's new draft body replaces the existing
#'   body wholesale.
#' @param slug Optional character. When supplied, force the synthesis
#'   row's slug to this value, bypassing the title-overlap collision
#'   guard. Useful for explicitly amending an existing wiki page
#'   (\code{slug = "my-existing-page"} updates \code{wiki/my-existing-page.md}
#'   in place) or naming a fresh synthesis page. The synthesis row is
#'   the first \code{type == "analysis"} entry in the planner output,
#'   else row 1. Other planned rows (concepts, entities) keep their
#'   planner-assigned slugs and still go through normal collision and
#'   dedup checks.
#' @param force Logical. Allow writes into adopted vaults.
#' @param provider Provider for the default \code{llm.api} model backend:
#'   \code{"auto"} (default; picks whichever of \code{ANTHROPIC_API_KEY},
#'   \code{OPENAI_API_KEY}, or \code{MOONSHOT_API_KEY} is set),
#'   \code{"anthropic"}, \code{"openai"}, \code{"moonshot"},
#'   \code{"ollama"}, or \code{"heuristic"} (force the deterministic
#'   fallback).
#' @param model Optional model name for the default \code{llm.api}
#'   backend.
#' @param verbose Logical. Print phase progress.
#' @return A list of class \code{pensar_research} with topic, program,
#'   queries, search results, filed sources, extracted claims, written
#'   pages, synthesis metadata, and model usage.
#' @examples
#' \dontrun{
#' vault <- file.path(tempdir(), "ar-example")
#' init_vault(vault, rproj = FALSE, agent_instructions = FALSE)
#' use_vault(vault)
#' Sys.setenv(TAVILY_API_KEY = "tvly-...")
#' res <- autoresearch("transformer scaling laws")
#' print(res)
#' show_page(res$synthesis$slug)
#' }
#' @export
autoresearch <- function(topic, vault = default_vault(),
                         search_backend = NULL, fetch_backend = NULL,
                         model_backend = NULL, program = NULL, force = FALSE,
                         overwrite = TRUE, update = TRUE, slug = NULL,
                         provider = "auto", model = NULL, verbose = TRUE) {
    if (!is.character(topic) || length(topic) != 1L || !nzchar(topic)) {
        stop("`topic` must be a single non-empty string.", call. = FALSE)
    }
    if (!is.null(slug) &&
        (!is.character(slug) || length(slug) != 1L)) {
        stop("`slug` must be NULL or a single character value (got ",
             typeof(slug), " of length ", length(slug), ").",
             call. = FALSE)
    }
    vault <- normalizePath(vault, mustWork = TRUE)
    if (!file.exists(file.path(vault, "schema.md"))) {
        stop("Not a pensar vault: ", vault, ". Run init_vault() first.")
    }

    # Clear any caller-set elapsed-time limit (corteza wraps tool calls in
    # a 30s setTimeLimit; autoresearch is designed to take minutes). User
    # can still Ctrl-C. The caller's on.exit, if any, restores the limit
    # after autoresearch returns.
    setTimeLimit(cpu = Inf, elapsed = Inf, transient = TRUE)

    program <- load_autoresearch_program(vault = vault, program = program)
    search_backend <- search_backend %||% .default_search_backend()
    fetch_backend <- fetch_backend %||% .autoresearch_default_fetch_backend()
    if (is.null(model_backend)) {
        model_backend <- .autoresearch_default_model_backend(provider = provider,
                                                             model = model)
    }
    model_backend <- .verbose_model_backend(model_backend, verbose)
    t_start <- Sys.time()

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

    .ar_msg(verbose, "planning queries for '", topic, "'")
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

        .ar_msg(verbose, "round ", round, ": running ", nrow(round_queries),
                " search ", if (nrow(round_queries) == 1L) "query" else "queries")
        round_search <- autoresearch_run_searches(round_queries,
                                                  search_backend, program,
                                                  verbose = verbose)
        round_search$round <- rep.int(as.integer(round), nrow(round_search))
        search_results <- .autoresearch_bind_rows(search_results, round_search)
        .ar_msg(verbose, "round ", round, ": ", nrow(round_search),
                " search results")

        .ar_msg(verbose, "round ", round, ": selecting sources from ",
                nrow(round_search), " results")
        round_selected <- autoresearch_select_sources(topic, round_search,
                                                      program, model_backend)
        if (nrow(round_selected) > 0L && nrow(selected) > 0L) {
            round_selected <- round_selected[
                !round_selected$url %in% selected$url,, drop = FALSE]
        }
        round_selected$round <- rep.int(as.integer(round),
                                        nrow(round_selected))
        selected <- .autoresearch_bind_rows(selected, round_selected)
        .ar_msg(verbose, "round ", round, ": selected ", nrow(round_selected),
                " new ", if (nrow(round_selected) == 1L) "source" else "sources")

        .ar_msg(verbose, "round ", round, ": fetching ",
                nrow(round_selected), " ",
                if (nrow(round_selected) == 1L) "source" else "sources")
        round_sources <- autoresearch_fetch_and_ingest(round_selected,
                                                       fetch_backend, vault,
                                                       topic, force = force,
                                                       verbose = verbose)
        round_sources$round <- rep.int(as.integer(round), nrow(round_sources))
        sources <- .autoresearch_bind_rows(sources, round_sources)

        .ar_msg(verbose, "round ", round, ": extracting evidence from ",
                nrow(round_sources), " ",
                if (nrow(round_sources) == 1L) "source" else "sources")
        round_claims <- autoresearch_extract_claims(topic, round_sources,
                                                    program, model_backend)
        round_claims$round <- rep.int(as.integer(round), nrow(round_claims))
        claims <- .autoresearch_bind_rows(claims, round_claims)
        .ar_msg(verbose, "round ", round, ": extracted ", nrow(round_claims),
                " ", if (nrow(round_claims) == 1L) "claim" else "claims")

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
        .ar_msg(verbose, "round ", round, ": analyzing gaps")
        gap_plan <- autoresearch_analyze_gaps(topic, claims, sources,
                                              all_queries, program,
                                              model_backend, round)
        gaps <- .autoresearch_bind_rows(gaps, gap_plan$gaps)
        next_queries <- gap_plan$queries
        .ar_msg(verbose, "round ", round, ": ", nrow(gap_plan$gaps),
                " gaps, ", nrow(gap_plan$queries),
                " follow-up ",
                if (nrow(gap_plan$queries) == 1L) "query" else "queries")
    }

    existing_pages <- autoresearch_existing_pages(vault)
    .ar_msg(verbose, "vault has ", nrow(existing_pages),
            " existing wiki ",
            if (nrow(existing_pages) == 1L) "page" else "pages")

    .ar_msg(verbose, "planning pages from ", nrow(claims), " claims and ",
            nrow(sources), " sources")
    pages <- autoresearch_plan_pages(topic, claims, sources, existing_pages,
                                     program, model_backend)
    .ar_msg(verbose, "planner returned ", nrow(pages$pages),
            " ", if (nrow(pages$pages) == 1L) "page" else "pages")
    pages$pages <- .ar_apply_user_slug(pages$pages, slug, verbose)
    pages$pages <- .ar_dedupe_planned_slugs(pages$pages, topic, vault,
                                            verbose = verbose)

    if (isTRUE(update) && nrow(pages$pages) > 0L) {
        update_targets <- .ar_update_targets(pages$pages, vault)
        if (length(update_targets) > 0L) {
            .ar_msg(verbose, "revising ", length(update_targets),
                    " existing ",
                    if (length(update_targets) == 1L) "page" else "pages",
                    ": ", paste(update_targets, collapse = ", "))
        } else {
            .ar_msg(verbose, "no existing pages to revise; writing fresh")
        }
        pages$pages <- autoresearch_revise_pages(pages$pages, topic, claims,
                                                 sources, vault, program,
                                                 model_backend,
                                                 verbose = verbose)
    }

    .ar_msg(verbose, "writing ", nrow(pages$pages),
            " wiki ", if (nrow(pages$pages) == 1L) "page" else "pages")
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
    vault_commit(sprintf("autoresearch: %s (%d sources, %d pages)",
                         topic, nrow(sources), nrow(written)),
                 vault = vault)
    elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
    .ar_msg(verbose, "done in ", sprintf("%.1fs", elapsed), " (",
            nrow(sources), " sources, ", nrow(claims), " claims, ",
            nrow(written), " pages)")

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

#' Print a verbose progress line and flush in interactive sessions
#'
#' Prefixes with \code{"autoresearch: "} so the user can grep for our
#' messages, and calls \code{flush.console()} so RStudio shows progress
#' in real time instead of buffering until the function returns.
#'
#' @noRd
.ar_msg <- function(verbose, ...) {
    if (!isTRUE(verbose)) {
        return(invisible(NULL))
    }
    message("autoresearch: ", ...)
    if (interactive()) {
        try(utils::flush.console(), silent = TRUE)
    }
    invisible(NULL)
}

#' Wrap a model backend to print start/end + elapsed time per call
#'
#' Preserves the backend's \code{usage_env} attribute (used by
#' \code{.autoresearch_model_usage()} to surface cumulative tokens) by
#' copying it onto the wrapper.
#'
#' @noRd
.verbose_model_backend <- function(model_backend, verbose) {
    if (!isTRUE(verbose)) {
        return(model_backend)
    }
    usage_env <- attr(model_backend, "usage_env", exact = TRUE)
    wrapped <- function(task, input, program) {
        .ar_msg(TRUE, "  model call: ", task, " ...")
        t0 <- Sys.time()
        res <- model_backend(task, input, program)
        elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
        .ar_msg(TRUE, "  model call: ", task, " done in ",
                sprintf("%.1fs", elapsed))
        res
    }
    if (!is.null(usage_env)) {
        attr(wrapped, "usage_env") <- usage_env
    }
    wrapped
}

#' Identify planned slugs that already exist as wiki pages in the vault
#'
#' Used by \code{autoresearch()} for the verbose log line announcing
#' which pages are about to go through \code{revise_page}.
#'
#' @noRd
.ar_update_targets <- function(planned, vault) {
    if (nrow(planned) == 0L) {
        return(character(0L))
    }
    slugs <- as.character(planned$slug)
    paths <- file.path(vault, "wiki", paste0(slugs, ".md"))
    slugs[file.exists(paths)]
}

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
        body_text <- tryCatch(rawToChar(resp$content),
                              error = function(e) "<unreadable body>")
        stop(sprintf("Tavily HTTP %d: %s", resp$status_code, body_text),
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
