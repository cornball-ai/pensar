#' @title Vault page registry
#' @description Build a structured index of every page in a vault for
#' link resolution, frontmatter querying, and downstream features
#' (retrieval primitives, dedup audits, manifest sync).

#' Build a structured registry of a vault's pages
#'
#' Scans every \code{.md} file in \code{vault} and returns a data.frame
#' with one row per page. Used internally to resolve wikilinks and
#' query frontmatter without re-scanning the filesystem on every call.
#'
#' \strong{Identity columns:}
#' \itemize{
#'   \item \code{node_id} is the current link-resolution identity
#'     (path-aware basename via \code{name_from_path()}). This is what
#'     \code{[[page]]} matches against.
#'   \item \code{page_uid} is a stable identity sourced from frontmatter
#'     \code{id:} or \code{address:}. \code{NA} if the page declares
#'     neither. Stable identity is opt-in via frontmatter; pensar never
#'     fabricates one from a path hash, because path hashes change on
#'     rename.
#' }
#'
#' \strong{Cache} levels:
#' \itemize{
#'   \item \code{"session"} (default): memoized in a package-level
#'     environment, keyed by vault path. No disk write. Invalidates when
#'     any \code{.md} file's mtime changes.
#'   \item \code{"user"}: persisted to
#'     \code{tools::R_user_dir("pensar", "cache")}. CRAN-safe location;
#'     never writes inside the vault itself (\code{.pensar/} is reserved
#'     for vault-owned state).
#'   \item \code{"none"}: rebuild on every call.
#' }
#'
#' @param vault Vault path.
#' @param cache Cache policy: \code{"session"} (default), \code{"user"},
#'   or \code{"none"}.
#' @param refresh If \code{TRUE}, rebuild and overwrite the cache.
#' @return A data.frame with columns: \code{path}, \code{node_id},
#'   \code{page_uid}, \code{title}, \code{aliases}, \code{type},
#'   \code{tags}, \code{sources}, \code{links_out}, \code{system_file}.
#'   Aliases / tags / links_out are list-columns.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("Body cites [[other]].", type = "articles", source = "demo",
#'        vault = v)
#' reg <- vault_registry(v)
#' nrow(reg)
#' unlink(v, recursive = TRUE)
#' @export
vault_registry <- function(vault = default_vault(),
                           cache = c("session", "user", "none"),
                           refresh = FALSE) {
    cache <- match.arg(cache)
    vault <- normalizePath(vault, mustWork = TRUE)
    key <- registry_cache_key(vault)

    if (!isTRUE(refresh) && cache != "none") {
        cached <- registry_cache_get(vault, cache, key)
        if (!is.null(cached)) {
            return(cached)
        }
    }

    df <- build_registry(vault)

    if (cache != "none") {
        registry_cache_put(vault, cache, key, df)
    }
    df
}

#' Build the registry from scratch (uncached)
#' @noRd
build_registry <- function(vault) {
    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    if (length(all_md) == 0L) {
        return(empty_registry())
    }
    rows <- lapply(all_md, function(fp) build_registry_row(fp, vault))
    do.call(rbind, rows)
}

#' One registry row for one file
#' @noRd
build_registry_row <- function(filepath, vault) {
    rel_path <- substring(filepath, nchar(vault) + 2L)
    node_id <- name_from_path(filepath)
    fm <- parse_frontmatter(filepath)

    page_uid <- fm$id %||% fm$address %||% NA_character_
    if (is.list(page_uid) || length(page_uid) != 1L) {
        page_uid <- NA_character_
    }
    page_uid <- as.character(page_uid)

    title <- fm$title %||% NA_character_
    if (is.list(title) || length(title) != 1L) {
        title <- NA_character_
    }
    title <- as.character(title)

    type <- fm$type %||% NA_character_
    if (is.list(type) || length(type) != 1L) {
        type <- NA_character_
    }
    type <- as.character(type)

    sources <- fm$source %||% NA_character_
    if (is.list(sources) || length(sources) != 1L) {
        sources <- NA_character_
    }
    sources <- as.character(sources)

    aliases <- list(as.character(unlist(fm$aliases) %||% character(0L)))
    tags <- list(as.character(unlist(fm$tags) %||% character(0L)))
    links_out <- list(unique(parse_wikilinks(filepath)))

    system_file <- basename(filepath) %in% c("schema.md", "index.md",
        "log.md") &&
    identical(dirname(filepath), vault)

    data.frame(path = rel_path, node_id = node_id, page_uid = page_uid,
               title = title, aliases = I(aliases), type = type,
               tags = I(tags), sources = sources,
               links_out = I(links_out), system_file = system_file,
               stringsAsFactors = FALSE)
}

#' Empty registry data.frame with correct columns
#' @noRd
empty_registry <- function() {
    data.frame(path = character(0L), node_id = character(0L),
               page_uid = character(0L), title = character(0L),
               aliases = I(list()), type = character(0L), tags = I(list()),
               sources = character(0L), links_out = I(list()),
               system_file = logical(0L), stringsAsFactors = FALSE)
}

# --- cache ------------------------------------------------------------

#' Session-level cache. Keyed by SHA-1 of normalized vault path.
#' Each entry is list(mtimes = ..., df = ...).
#' @noRd
.registry_cache <- new.env(parent = emptyenv())

#' Cache key derived from the normalized vault path
#' @noRd
registry_cache_key <- function(vault) {
    digest::digest(vault, algo = "sha1")
}

#' Get a cached registry if present and still valid (mtimes match)
#' @noRd
registry_cache_get <- function(vault, cache, key) {
    holder <- if (cache == "session") {
        .registry_cache[[key]]
    } else {
        cache_file <- file.path(tools::R_user_dir("pensar", "cache"),
                                paste0(key, ".rds"))
        if (!file.exists(cache_file)) {
            NULL
        } else {
            tryCatch(readRDS(cache_file), error = function(e) NULL)
        }
    }
    if (is.null(holder)) {
        return(NULL)
    }

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    if (length(all_md) != length(holder$mtimes)) {
        return(NULL)
    }
    current_mtimes <- unname(file.info(all_md)$mtime)
    if (!identical(sort(holder$mtimes), sort(current_mtimes))) {
        return(NULL)
    }
    holder$df
}

#' Store a registry in the chosen cache
#' @noRd
registry_cache_put <- function(vault, cache, key, df) {
    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    mtimes <- unname(file.info(all_md)$mtime)
    holder <- list(mtimes = mtimes, df = df)
    if (cache == "session") {
        .registry_cache[[key]] <- holder
    } else {
        cache_dir <- tools::R_user_dir("pensar", "cache")
        dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
        saveRDS(holder, file.path(cache_dir, paste0(key, ".rds")))
    }
    invisible(NULL)
}

