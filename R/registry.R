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
#'   \code{category}, \code{tags}, \code{sources}, \code{links_out},
#'   \code{system_file}. Aliases / tags / links_out are list-columns.
#'   The \code{type} and \code{category} fields come from frontmatter
#'   verbatim; callers compute an effective type as \code{type}
#'   when present, falling back to \code{category} otherwise.
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

    category <- fm$category %||% NA_character_
    if (is.list(category) || length(category) != 1L) {
        category <- NA_character_
    }
    category <- as.character(category)

    sources <- fm$source %||% NA_character_
    if (is.list(sources) || length(sources) != 1L) {
        sources <- NA_character_
    }
    sources <- as.character(sources)

    aliases <- list(as.character(unlist(fm$aliases) %||% character(0L)))
    tags <- list(as.character(unlist(fm$tags) %||% character(0L)))
    links_out <- list(unique(parse_wikilinks(filepath)))

    # System / pensar-managed files we don't want to treat as content
    # in the registry: vault root control files (schema/index/log) and
    # anything under _proposals/ (audit outputs from dedup() / tags()).
    # Checked against the relative path so it's portable to Windows,
    # where list.files() uses forward slashes but normalizePath()
    # returns backslashes (so `dirname(filepath) == vault` was false).
    rel_dir <- dirname(rel_path)
    is_root_ctrl <- basename(filepath) %in%
        c("schema.md", "index.md", "log.md") &&
        identical(rel_dir, ".")
    in_proposals <- identical(rel_dir, "_proposals")
    system_file <- is_root_ctrl || in_proposals

    data.frame(path = rel_path, node_id = node_id, page_uid = page_uid,
               title = title, aliases = I(aliases), type = type,
               category = category, tags = I(tags), sources = sources,
               links_out = I(links_out), system_file = system_file,
               stringsAsFactors = FALSE)
}

#' Empty registry data.frame with correct columns
#' @noRd
empty_registry <- function() {
    data.frame(path = character(0L), node_id = character(0L),
               page_uid = character(0L), title = character(0L),
               aliases = I(list()), type = character(0L),
               category = character(0L), tags = I(list()),
               sources = character(0L), links_out = I(list()),
               system_file = logical(0L), stringsAsFactors = FALSE)
}

# --- cache ------------------------------------------------------------

#' Session-level cache. Keyed by SHA-1 of normalized vault path.
#' Each entry is list(sig = ..., df = ...). The signature is a sorted
#' character vector of \code{"<relpath>\\t<mtime>\\t<size>"} triples,
#' keyed by relative path so renames invalidate the cache.
#' @noRd
.registry_cache <- new.env(parent = emptyenv())

#' Cache key derived from the normalized vault path
#' @noRd
registry_cache_key <- function(vault) {
    digest::digest(vault, algo = "sha1")
}

#' Build the registry cache signature for a vault
#'
#' Triples of relative path / mtime / size, sorted by relative path.
#' Catches renames (path changes), edits (mtime changes), and partial
#' rewrites (size changes), unlike a sorted-mtime-only check which
#' could miss in-session renames between same-mtime files.
#' @noRd
registry_signature <- function(vault) {
    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    if (length(all_md) == 0L) {
        return(character(0L))
    }
    rel <- substring(all_md, nchar(vault) + 2L)
    info <- file.info(all_md)
    sig <- sprintf("%s\t%s\t%d", rel,
                   format(info$mtime, "%Y-%m-%dT%H:%M:%OS6"),
                   as.integer(info$size))
    sort(sig)
}

#' Get a cached registry if present and still valid
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

    current_sig <- registry_signature(vault)
    if (!identical(holder$sig, current_sig)) {
        return(NULL)
    }
    holder$df
}

#' Store a registry in the chosen cache
#' @noRd
registry_cache_put <- function(vault, cache, key, df) {
    holder <- list(sig = registry_signature(vault), df = df)
    if (cache == "session") {
        .registry_cache[[key]] <- holder
    } else {
        cache_dir <- tools::R_user_dir("pensar", "cache")
        dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
        saveRDS(holder, file.path(cache_dir, paste0(key, ".rds")))
    }
    invisible(NULL)
}

