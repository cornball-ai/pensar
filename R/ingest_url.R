#' @title URL ingest
#' @description Fetch a URL with \code{curl}, write the body into the
#' vault via \code{ingest()}, and record the source URL in the
#' manifest.

#' Ingest content from a URL
#'
#' Fetches \code{url} (10s timeout), refuses non-2xx responses or
#' content types outside text/JSON/XML, and writes the body into the
#' vault through \code{ingest()}. If the manifest already records this
#' URL as a source, returns the existing page path without re-fetching.
#'
#' For HTML responses the page's \code{<title>} is extracted and used
#' as the page title when \code{title} is not supplied.
#'
#' @param url URL to fetch.
#' @param vault Vault path.
#' @param type Ingest type. Default \code{"articles"}.
#' @param title Optional page title. If \code{NULL}, derived from
#'   HTML \code{<title>}, or falls back to the URL.
#' @param tags Optional character vector of tags.
#' @return The relative path of the written (or existing) page,
#'   invisibly.
#' @examples
#' \dontrun{
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest_url("https://example.com", vault = v)
#' unlink(v, recursive = TRUE)
#' }
#' @export
ingest_url <- function(url, vault = default_vault(), type = "articles",
                       title = NULL, tags = NULL) {
    vault <- normalizePath(vault, mustWork = TRUE)
    if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
        stop("`url` must be a single non-empty string.", call. = FALSE)
    }

    # Dedup: if the manifest already records this URL, return its path
    # without re-fetching.
    existing <- existing_source_path(url, vault)
    if (!is.null(existing)) {
        message("URL already ingested at: ", existing)
        return(invisible(existing))
    }

    fetched <- fetch_url_content(url)
    ingest_url_content(url = url, content = fetched$body,
                       content_type = fetched$content_type, vault = vault,
                       type = type, title = title, tags = tags)
}

#' Fetch textual content from a URL
#'
#' @param url URL to fetch.
#' @return A list with \code{url}, \code{status_code},
#'   \code{content_type}, \code{body}, \code{fetched_at}, and
#'   \code{title}.
#' @noRd
fetch_url_content <- function(url) {
    if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
        stop("`url` must be a single non-empty string.", call. = FALSE)
    }
    h <- curl::new_handle()
    curl::handle_setopt(h, timeout = 10L, followlocation = TRUE,
                        ssl_verifypeer = TRUE)
    resp <- tryCatch(curl::curl_fetch_memory(url, handle = h),
                     error = function(e) {
        stop(sprintf("Failed to fetch %s: %s", url, conditionMessage(e)),
             call. = FALSE)
    })

    if (resp$status_code < 200L || resp$status_code >= 300L) {
        stop(sprintf("Refusing non-2xx response from %s: HTTP %d",
                     url, resp$status_code), call. = FALSE)
    }

    ctype <- response_content_type(resp)
    if (!content_type_allowed(ctype)) {
        stop(sprintf("Refusing content-type '%s' from %s. Allowed: ",
                     ctype, url),
             "text/html, text/plain, application/json, application/xml.",
             call. = FALSE)
    }

    body <- tryCatch(rawToChar(resp$content),
                     error = function(e) {
        stop("Failed to decode response body as text: ",
             conditionMessage(e), call. = FALSE)
    })

    list(url = url,
         status_code = resp$status_code,
         content_type = ctype,
         body = body,
         fetched_at = now_ts(),
         title = if (grepl("html", ctype, ignore.case = TRUE)) {
            extract_html_title(body)
        } else {
            NULL
        })
}

#' Ingest already-fetched URL content
#'
#' @param url Source URL.
#' @param content Fetched body text.
#' @param content_type Optional content type.
#' @param vault Vault path.
#' @param type Ingest type.
#' @param title Optional title.
#' @param tags Optional tags.
#' @param force Logical. Allow adopted-vault writes.
#' @return Relative path of the written or existing page, invisibly.
#' @noRd
ingest_url_content <- function(url, content, content_type = NULL,
                               vault = default_vault(), type = "articles",
                               title = NULL, tags = NULL, force = FALSE) {
    vault <- normalizePath(vault, mustWork = TRUE)
    if (!is.character(url) || length(url) != 1L || !nzchar(url)) {
        stop("`url` must be a single non-empty string.", call. = FALSE)
    }
    if (!is.character(content) || length(content) != 1L) {
        stop("`content` must be a single character string.", call. = FALSE)
    }
    existing <- existing_source_path(url, vault)
    if (!is.null(existing)) {
        message("URL already ingested at: ", existing)
        return(invisible(existing))
    }
    if (!is.null(content_type) && nzchar(content_type)) {
        ctype <- tolower(strsplit(content_type, ";", fixed = TRUE)[[1L]][1L])
        if (!content_type_allowed(ctype)) {
            stop(sprintf("Refusing content-type '%s' from %s. Allowed: ",
                         ctype, url),
                 "text/html, text/plain, application/json, application/xml.",
                 call. = FALSE)
        }
        if (is.null(title) && grepl("html", ctype, ignore.case = TRUE)) {
            title <- extract_html_title(content) %||% NULL
        }
    }
    if (is.null(title)) {
        title <- url
    }

    fp <- ingest(content, type = type, source = url, title = title,
                 tags = tags, vault = vault, force = force)
    invisible(substring(fp, nchar(vault) + 2L))
}

#' Look up the relative path of an already-ingested source
#'
#' Returns the relative path of an existing page whose manifest record
#' matches \code{url}, or \code{NULL} otherwise. A manifest hit is
#' ignored when the recorded file has been deleted, so a stale entry
#' doesn't make \code{ingest_url()} silently return a dead path.
#' Malformed per-entry records (a scalar where a list was expected)
#' are skipped, not fatal.
#' @noRd
existing_source_path <- function(url, vault) {
    m <- tryCatch(read_manifest(vault), error = function(e) NULL)
    if (is.null(m) || length(m$sources) == 0L) {
        return(NULL)
    }
    for (path in names(m$sources)) {
        entry <- m$sources[[path]]
        if (!is.list(entry)) {
            next
        }
        if (!identical(entry$source, url)) {
            next
        }
        if (!file.exists(file.path(vault, path))) {
            next
        }
        return(path)
    }
    NULL
}

#' Normalize the Content-Type header value to its MIME prefix
#'
#' \code{resp$type} on a curl response often looks like
#' \code{"text/html; charset=UTF-8"}. Returns just \code{"text/html"}.
#' @noRd
response_content_type <- function(resp) {
    ctype <- resp$type %||% ""
    ctype <- tolower(trimws(strsplit(ctype, ";", fixed = TRUE)[[1L]][1L]))
    if (is.na(ctype)) {
        ""
    } else {
        ctype
    }
}

#' Is this content type one we accept for raw ingestion?
#' @noRd
content_type_allowed <- function(ctype) {
    ctype %in% c("text/html", "text/plain", "text/markdown",
                 "application/json", "application/xml", "text/xml")
}

#' Extract the first <title>...</title> contents from HTML
#'
#' Returns the trimmed inner text, or \code{NULL} if no \code{<title>}
#' tag is present. Intentionally simple: no DOM parsing, no entity
#' decoding beyond \code{&amp;}.
#' @noRd
extract_html_title <- function(html) {
    m <- regmatches(html,
                    regexec("<title[^>]*>([\\s\\S]*?)</title>", html, ignore.case = TRUE,
                            perl = TRUE))[[1L]]
    if (length(m) < 2L) {
        return(NULL)
    }
    title <- trimws(m[2L])
    if (!nzchar(title)) {
        return(NULL)
    }
    # Decode the few entities common in <title>.
    title <- gsub("&amp;", "&", title, fixed = TRUE)
    title <- gsub("&#x27;|&#39;", "'", title)
    title <- gsub("&quot;", "\"", title, fixed = TRUE)
    title <- gsub("&lt;", "<", title, fixed = TRUE)
    title <- gsub("&gt;", ">", title, fixed = TRUE)
    title
}

