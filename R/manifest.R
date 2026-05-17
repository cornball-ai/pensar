#' @title Vault manifest
#' @description Pensar-owned bookkeeping at \code{.pensar/manifest.yml}:
#' per-source ingest provenance and an opt-in \code{path -> page_uid}
#' address map. Read by retrieval primitives that need delta info;
#' written by \code{ingest()} and \code{ingest_repo()} after a
#' successful page write. Read-only operations
#' (\code{vault_registry()}, \code{update_index()}, \code{status()})
#' never touch the manifest.

#' Canonical manifest path inside a vault
#'
#' Returns \code{<vault>/.pensar/manifest.yml}. The directory is created
#' lazily by \code{update_manifest()} so simply asking for the path
#' doesn't materialize \code{.pensar/}.
#' @param vault Vault path.
#' @return Absolute path to the manifest file.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' manifest_path(v)
#' unlink(v, recursive = TRUE)
#' @export
manifest_path <- function(vault) {
    vault <- normalizePath(vault, mustWork = TRUE)
    file.path(vault, ".pensar", "manifest.yml")
}

#' Read the pensar manifest for a vault
#'
#' Returns a normalized list with \code{version}, \code{created},
#' \code{sources}, and \code{address_map} fields. When the manifest
#' file is missing, returns a fresh empty struct with the current date
#' as \code{created}; the manifest file is not written.
#'
#' Malformed YAML logs a warning and returns the empty struct so callers
#' can keep going.
#' @param vault Vault path.
#' @return A list with components \code{version} (integer),
#'   \code{created} (\code{YYYY-MM-DD} string), \code{sources}
#'   (named list of per-source records), and \code{address_map}
#'   (named list mapping relative path to page_uid).
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' read_manifest(v)$sources
#' unlink(v, recursive = TRUE)
#' @export
read_manifest <- function(vault) {
    vault <- normalizePath(vault, mustWork = TRUE)
    fp <- file.path(vault, ".pensar", "manifest.yml")
    if (!file.exists(fp)) {
        return(empty_manifest())
    }
    parsed <- tryCatch(yaml::read_yaml(fp),
                       error = function(e) {
        warning("malformed manifest at ", fp, ": ", conditionMessage(e),
                call. = FALSE)
        NULL
    })
    if (!is.list(parsed)) {
        return(empty_manifest())
    }
    parsed$version <- parsed$version %||% 1L
    parsed$created <- parsed$created %||% format(Sys.Date(), "%Y-%m-%d")
    parsed$sources <- parsed$sources %||% list()
    parsed$address_map <- parsed$address_map %||% list()
    parsed
}

#' Update the pensar manifest for a vault
#'
#' Patches a manifest record for one page. Writes \emph{only}
#' \code{.pensar/manifest.yml}; never edits other tools' manifest
#' formats (\code{.manifest.json}, \code{.raw/.manifest.json}).
#'
#' \code{source}, \code{hash}, or \code{ingested_at} together write or
#' refresh a \code{sources[path]} record. \code{page_uid} (or
#' \code{address}, which is treated as an alias) writes an
#' \code{address_map[path]} record. A call with only \code{path} and
#' \code{page_uid} updates the address map without touching the
#' \code{sources} record.
#'
#' @param vault Vault path.
#' @param source Source identifier (URL, session id, etc.). Optional.
#' @param path Relative path inside the vault that this update is
#'   about. Required if any of the other fields are set.
#' @param page_uid Stable page identity from frontmatter
#'   \code{id} / \code{address}. Goes into both the \code{sources}
#'   record (when other source fields are set) and the
#'   \code{address_map}.
#' @param address Alias for \code{page_uid} that only writes to
#'   \code{address_map}. Useful when the caller wants to record an
#'   address without touching the source record.
#' @param hash Content hash (typically \code{paste0("sha1:", ...)} from
#'   \code{digest::digest()}).
#' @param ingested_at Timestamp string. Defaults to current time when
#'   any source-shaped field is set.
#' @return The manifest path, invisibly.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' update_manifest(v, source = "demo",
#'                 path = "raw/articles/demo.md",
#'                 hash = "sha1:abc")
#' read_manifest(v)$sources[["raw/articles/demo.md"]]
#' unlink(v, recursive = TRUE)
#' @export
update_manifest <- function(vault, source = NULL, path = NULL,
                            page_uid = NULL, address = NULL, hash = NULL,
                            ingested_at = NULL) {
    vault <- normalizePath(vault, mustWork = TRUE)
    if (is.null(path)) {
        return(invisible(file.path(vault, ".pensar", "manifest.yml")))
    }

    m <- read_manifest(vault)
    has_source_fields <- !is.null(source) || !is.null(hash) ||
    !is.null(ingested_at)
    if (has_source_fields) {
        entry <- m$sources[[path]] %||% list()
        if (!is.null(source)) {
            entry$source <- source
        }
        if (!is.null(hash)) {
            entry$hash <- hash
        }
        entry$ingested_at <- ingested_at %||%
        format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
        if (!is.null(page_uid)) {
            entry$page_uid <- page_uid
        }
        m$sources[[path]] <- entry
    }
    addr <- address %||% page_uid
    if (!is.null(addr)) {
        m$address_map[[path]] <- addr
    }

    fp <- file.path(vault, ".pensar", "manifest.yml")
    dir.create(dirname(fp), recursive = TRUE, showWarnings = FALSE)
    yaml::write_yaml(m, fp)
    invisible(fp)
}

#' Fresh empty manifest struct
#' @noRd
empty_manifest <- function() {
    list(version = 1L, created = format(Sys.Date(), "%Y-%m-%d"),
         sources = list(), address_map = list())
}

