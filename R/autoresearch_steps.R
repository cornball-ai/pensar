#' @title Autoresearch workflow steps
#' @description Typed orchestration helpers for \code{autoresearch()}.

#' @noRd
autoresearch_plan_queries <- function(topic, program, model_backend) {
    res <- model_backend("plan_queries", list(topic = topic), program)
    queries <- .list_to_df(res$queries, columns = c("query", "angle"))
    if (nrow(queries) == 0L) {
        queries <- data.frame(query = topic, angle = "topic",
                              stringsAsFactors = FALSE)
    }
    queries$query <- as.character(queries$query)
    queries$angle <- as.character(queries$angle)
    queries <- queries[nzchar(queries$query),, drop = FALSE]
    utils::head(queries, program$max_queries_per_round)
}

#' @noRd
autoresearch_run_searches <- function(queries, search_backend, program) {
    if (nrow(queries) == 0L) {
        return(.empty_search_results())
    }
    results <- vector("list", nrow(queries))
    for (i in seq_len(nrow(queries))) {
        raw <- search_backend(queries$query[[i]], program$max_sources_per_round)
        df <- .validate_autoresearch_search_results(raw)
        df$query <- queries$query[[i]]
        df$angle <- queries$angle[[i]]
        results[[i]] <- df
    }
    out <- do.call(rbind, results)
    if (is.null(out)) {
        return(.empty_search_results())
    }
    rownames(out) <- NULL
    out
}

#' @noRd
autoresearch_select_sources <- function(topic, search_results, program,
                                        model_backend) {
    res <- model_backend("select_sources",
                         list(topic = topic, search_results = search_results),
                         program)
    selected <- .list_to_df(res$sources, columns = c("url", "reason"))
    if (nrow(selected) == 0L) {
        return(data.frame(url = character(), reason = character(),
                          stringsAsFactors = FALSE))
    }
    selected$url <- as.character(selected$url)
    selected$reason <- as.character(selected$reason)
    selected <- selected[nzchar(selected$url),, drop = FALSE]
    selected <- selected[!duplicated(selected$url),, drop = FALSE]
    utils::head(selected, program$max_sources_per_round)
}

#' @noRd
autoresearch_fetch_and_ingest <- function(selected, fetch_backend, vault,
    topic, force = FALSE) {
    if (nrow(selected) == 0L) {
        return(.empty_sources())
    }
    tags <- unique(c("research", slugify(topic)))
    rows <- vector("list", nrow(selected))
    for (i in seq_len(nrow(selected))) {
        url <- selected$url[[i]]
        existing <- existing_source_path(url, vault)
        if (!is.null(existing)) {
            body <- extract_body(file.path(vault, existing), n_chars = NULL)
            title <- (parse_frontmatter(file.path(vault, existing))$title %||%
                url)
            rel <- existing
            content_type <- NA_character_
        } else {
            fetched <- .validate_autoresearch_fetch_result(fetch_backend(url))
            rel <- ingest_url_content(url = url, content = fetched$body,
                                      content_type = fetched$content_type,
                                      vault = vault,
                                      title = fetched$title %||% NULL,
                                      tags = tags, force = force)
            body <- fetched$body
            title <- fetched$title %||% url
            content_type <- fetched$content_type
        }
        injection_reasons <- .prompt_injection_reasons(body)
        rows[[i]] <- data.frame(
                                url = url,
                                title = title,
                                path = rel,
                                slug = tools::file_path_sans_ext(basename(rel)),
                                content_type = content_type,
                                injection_flag = length(injection_reasons) > 0L,
                                injection_reasons = paste(injection_reasons,
                                                          collapse = "; "),
                                body = I(list(body)),
                                stringsAsFactors = FALSE
        )
    }
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
}

#' @noRd
autoresearch_extract_claims <- function(topic, sources, program,
                                        model_backend) {
    excerpted <- .autoresearch_source_records(sources, include_body = TRUE)
    res <- model_backend("extract_claims",
                         list(topic = topic, sources = excerpted), program)
    claims <- .list_to_df(res$claims,
                          columns = c("source_path", "source_slug",
                                      "claim", "confidence", "quote"))
    if (nrow(claims) == 0L) {
        return(.empty_claims())
    }
    claims$source_path <- as.character(claims$source_path)
    claims$source_slug <- as.character(claims$source_slug)
    claims$claim <- as.character(claims$claim)
    claims$confidence <- as.character(claims$confidence)
    claims$quote <- as.character(claims$quote)
    claims[nzchar(claims$claim),, drop = FALSE]
}

#' @noRd
autoresearch_analyze_gaps <- function(topic, claims, sources, queries,
                                      program, model_backend, round) {
    res <- model_backend("analyze_gaps",
                         list(topic = topic,
                              claims = claims,
                              sources = .autoresearch_source_records(
                                  sources, include_body = FALSE),
                              previous_queries = queries,
                              completed_round = as.integer(round)),
                         program)
    gaps <- .list_to_df(res$gaps, columns = c("gap", "reason"))
    gaps$gap <- as.character(gaps$gap)
    gaps$reason <- as.character(gaps$reason)
    gaps <- gaps[nzchar(gaps$gap),, drop = FALSE]
    if (nrow(gaps) > 0L) {
        gaps$round <- as.integer(round)
        gaps <- gaps[, c("round", "gap", "reason"), drop = FALSE]
    } else {
        gaps <- .empty_gaps()
    }

    planned <- .list_to_df(res$queries,
                           columns = c("query", "angle", "gap"))
    if (nrow(planned) == 0L && !is.null(res$gap_queries)) {
        planned <- .list_to_df(res$gap_queries,
                               columns = c("query", "angle", "gap"))
    }
    if (nrow(planned) == 0L) {
        return(list(gaps = gaps, queries = .empty_queries()))
    }
    planned$query <- as.character(planned$query)
    planned$angle <- as.character(planned$angle)
    planned$gap <- as.character(planned$gap)
    planned <- planned[nzchar(planned$query),, drop = FALSE]
    if (nrow(queries) > 0L) {
        planned <- planned[!planned$query %in% queries$query,, drop = FALSE]
    }
    planned <- planned[!duplicated(planned$query),, drop = FALSE]
    planned <- utils::head(planned, program$max_queries_per_round)
    if (nrow(planned) == 0L) {
        planned <- .empty_queries()
    }
    list(gaps = gaps, queries = planned)
}

#' @noRd
autoresearch_existing_pages <- function(vault) {
    reg <- vault_registry(vault = vault, cache = "none", refresh = TRUE)
    if (nrow(reg) == 0L) {
        return(.empty_existing_pages())
    }
    keep <- !reg$system_file & grepl("^wiki/", reg$path)
    reg <- reg[keep,, drop = FALSE]
    if (nrow(reg) == 0L) {
        return(.empty_existing_pages())
    }
    out <- reg[, c("path", "node_id", "page_uid", "title", "type",
                   "category", "sources"), drop = FALSE]
    out$aliases <- vapply(reg$aliases, paste, collapse = ", ",
                          FUN.VALUE = character(1L))
    out$tags <- vapply(reg$tags, paste, collapse = ", ",
                       FUN.VALUE = character(1L))
    rownames(out) <- NULL
    out
}

#' @noRd
autoresearch_plan_pages <- function(topic, claims, sources, existing_pages,
                                    program, model_backend) {
    res <- model_backend("plan_pages",
                         list(topic = topic,
                              claims = claims,
                              sources = .autoresearch_source_records(
                                  sources, include_body = FALSE),
                              existing_pages = existing_pages),
                         program)
    pages <- .list_to_df(res$pages,
                         columns = c("slug", "title", "type", "source", "body"))
    if (nrow(pages) == 0L) {
        res <- .heuristic_plan_pages(list(topic = topic, claims = claims,
                sources = .autoresearch_source_records(sources,
                    include_body = FALSE),
                existing_pages = existing_pages), program)
        pages <- .list_to_df(res$pages,
                             columns = c("slug", "title", "type", "source", "body"))
    }
    pages <- pages[seq_len(min(nrow(pages), program$max_pages)),,
        drop = FALSE]
    list(headline = as.character(res$headline %||% ""), pages = pages)
}

#' @noRd
autoresearch_revise_pages <- function(planned, topic, claims, sources, vault,
                                      program, model_backend) {
    if (nrow(planned) == 0L) {
        return(planned)
    }
    for (i in seq_len(nrow(planned))) {
        slug <- planned$slug[[i]]
        path <- file.path(vault, "wiki", paste0(slug, ".md"))
        if (!file.exists(path)) {
            next
        }
        existing_body <- tryCatch(extract_body(path, n_chars = NULL),
                                  error = function(e) "")
        if (!nzchar(existing_body)) {
            next
        }
        res <- model_backend("revise_page",
                             list(slug = slug,
                                  topic = topic,
                                  page_title = planned$title[[i]],
                                  type = planned$type[[i]],
                                  existing_body = existing_body,
                                  new_draft_body = planned$body[[i]],
                                  claims = claims,
                                  sources = .autoresearch_source_records(
                                      sources, include_body = FALSE)),
                             program)
        revised <- if (!is.null(res$body) && nzchar(res$body)) {
            as.character(res$body)
        } else {
            planned$body[[i]]
        }
        planned$body[[i]] <- revised
    }
    planned
}

#' @noRd
autoresearch_write_pages <- function(pages, vault, program, overwrite = TRUE,
                                     force = FALSE) {
    if (nrow(pages) == 0L) {
        return(data.frame(slug = character(), path = character(),
                          action = character(), type = character(),
                          title = character(), stringsAsFactors = FALSE))
    }
    required_tags <- unique(as.character(program$required_tags %||%
                                         "research"))
    required_tags <- required_tags[nzchar(required_tags)]
    if (length(required_tags) == 0L) {
        required_tags <- "research"
    }
    rows <- vector("list", nrow(pages))
    for (i in seq_len(nrow(pages))) {
        page_tags <- unique(c(required_tags, pages$type[[i]]))
        frontmatter <- list(title = pages$title[[i]],
                            type = pages$type[[i]],
                            source = pages$source[[i]],
                            date = as.character(Sys.Date()),
                            tags = page_tags)
        row <- write_wiki_page(slug = pages$slug[[i]],
                               frontmatter = frontmatter,
                               body = pages$body[[i]],
                               vault = vault,
                               overwrite = overwrite,
                               force = force)
        row$type <- pages$type[[i]]
        row$title <- pages$title[[i]]
        rows[[i]] <- row
    }
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
}

#' @noRd
.autoresearch_synthesis_record <- function(pages, written) {
    if (nrow(written) == 0L) {
        return(list(slug = "", path = "", headline = pages$headline %||% ""))
    }
    analysis <- which(written$type == "analysis")
    if (length(analysis) > 0L) {
        idx <- analysis[[1L]]
    } else {
        idx <- 1L
    }
    list(slug = written$slug[[idx]], path = written$path[[idx]],
         headline = pages$headline %||% "")
}

#' @noRd
.validate_autoresearch_search_results <- function(x) {
    if (!is.data.frame(x)) {
        stop("search_backend() must return a data.frame.", call. = FALSE)
    }
    required <- c("title", "url", "snippet")
    missing <- required[!required %in% names(x)]
    if (length(missing) > 0L) {
        stop("search_backend() result missing column(s): ",
             paste(missing, collapse = ", "), call. = FALSE)
    }
    out <- x[, required, drop = FALSE]
    out$title <- as.character(out$title)
    out$url <- as.character(out$url)
    out$snippet <- as.character(out$snippet)
    out <- out[nzchar(out$url),, drop = FALSE]
    if ("date" %in% names(x)) {
        out$date <- as.character(x$date)
    } else {
        out$date <- ""
    }
    if ("source" %in% names(x)) {
        out$source <- as.character(x$source)
    } else {
        out$source <- ""
    }
    rownames(out) <- NULL
    out
}

#' @noRd
.validate_autoresearch_fetch_result <- function(x) {
    if (!is.list(x)) {
        stop("fetch_backend() must return a list.", call. = FALSE)
    }
    required <- c("url", "status_code", "content_type", "body", "fetched_at")
    missing <- required[!required %in% names(x)]
    if (length(missing) > 0L) {
        stop("fetch_backend() result missing field(s): ",
             paste(missing, collapse = ", "), call. = FALSE)
    }
    if (as.integer(x$status_code) < 200L || as.integer(x$status_code) >= 300L) {
        stop("fetch_backend() returned non-2xx status for ", x$url,
             ": HTTP ", x$status_code, call. = FALSE)
    }
    ctype <- tolower(strsplit(as.character(x$content_type), ";",
                              fixed = TRUE)[[1L]][1L])
    if (!content_type_allowed(ctype)) {
        stop("fetch_backend() returned unsupported content type for ",
             x$url, ": ", ctype, call. = FALSE)
    }
    title <- x$title %||%
    if (grepl("html", ctype, ignore.case = TRUE)) {
        extract_html_title(x$body)
    } else {
        NULL
    }
    list(url = as.character(x$url),
         status_code = as.integer(x$status_code),
         content_type = ctype,
         body = as.character(x$body),
         fetched_at = as.character(x$fetched_at),
         title = title)
}

#' @noRd
.list_to_df <- function(x, columns) {
    if (is.null(x) || length(x) == 0L) {
        return(.empty_df(columns))
    }
    if (is.data.frame(x)) {
        out <- x
    } else if (is.list(x)) {
        rows <- lapply(x, function(row) {
            if (!is.list(row)) {
                row <- as.list(row)
            }
            as.data.frame(as.list(row), stringsAsFactors = FALSE)
        })
        out <- do.call(rbind, rows)
    } else {
        return(.empty_df(columns))
    }
    for (col in columns) {
        if (!col %in% names(out)) {
            out[[col]] <- ""
        }
    }
    out <- out[, columns, drop = FALSE]
    rownames(out) <- NULL
    out
}

#' @noRd
.autoresearch_bind_rows <- function(a, b) {
    if (is.null(a) || nrow(a) == 0L) {
        return(b)
    }
    if (is.null(b) || nrow(b) == 0L) {
        return(a)
    }
    out <- rbind(a, b)
    rownames(out) <- NULL
    out
}

#' @noRd
.autoresearch_source_records <- function(sources, include_body = FALSE,
                                         body_chars = 4000L) {
    cols <- c("url", "title", "path", "slug", "content_type",
              "injection_flag", "injection_reasons")
    if (is.null(sources) || nrow(sources) == 0L) {
        out <- .empty_df(cols)
    } else {
        out <- sources[, cols, drop = FALSE]
        out$injection_flag <- as.logical(out$injection_flag)
        out$injection_reasons <- as.character(out$injection_reasons)
    }
    if (isTRUE(include_body)) {
        if (is.null(sources) || nrow(sources) == 0L) {
            out$body <- I(list())
        } else {
            out$body <- I(lapply(sources$body, function(x) {
                substr(.plain_text(x), 1L, body_chars)
            }))
        }
        out$body_untrusted <- rep(TRUE, nrow(out))
    }
    rownames(out) <- NULL
    out
}

#' @noRd
.prompt_injection_reasons <- function(text) {
    text <- tolower(.plain_text(paste(text, collapse = " ")))
    patterns <- c(
        ignore_previous = "ignore (all )?(previous|prior|above) instructions",
        disregard_previous = "disregard (all )?(previous|prior|above) instructions",
        system_prompt = "system prompt|developer message|hidden instructions",
        tool_use = "call (the )?tool|use (the )?tool|execute (this )?command",
        exfiltrate = "exfiltrate|api key|password|secret token",
        role_override = "you are now|new instructions|follow these instructions"
    )
    hits <- names(patterns)[vapply(patterns, function(pat) {
        grepl(pat, text, perl = TRUE)
    }, logical(1L))]
    unname(hits)
}

#' @noRd
.empty_df <- function(columns) {
    out <- as.data.frame(stats::setNames(replicate(length(columns),
                character(0L), simplify = FALSE),
            columns),
                         stringsAsFactors = FALSE)
    out
}

#' @noRd
.empty_search_results <- function() {
    data.frame(title = character(), url = character(), snippet = character(),
               date = character(), source = character(), query = character(),
               angle = character(), stringsAsFactors = FALSE)
}

#' @noRd
.empty_queries <- function() {
    data.frame(query = character(), angle = character(), gap = character(),
               stringsAsFactors = FALSE)
}

#' @noRd
.empty_gaps <- function() {
    data.frame(round = integer(), gap = character(), reason = character(),
               stringsAsFactors = FALSE)
}

#' @noRd
.empty_sources <- function() {
    data.frame(url = character(), title = character(), path = character(),
               slug = character(), content_type = character(),
               injection_flag = logical(),
               injection_reasons = character(),
               body = I(list()), stringsAsFactors = FALSE)
}

#' @noRd
.empty_claims <- function() {
    data.frame(source_path = character(), source_slug = character(),
               claim = character(), confidence = character(),
               quote = character(), stringsAsFactors = FALSE)
}

#' @noRd
.empty_existing_pages <- function() {
    data.frame(path = character(), node_id = character(),
               page_uid = character(), title = character(),
               type = character(), category = character(),
               sources = character(), aliases = character(),
               tags = character(), stringsAsFactors = FALSE)
}
