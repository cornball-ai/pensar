#' Canonical manifest path inside a vault
#'
#' Returns \code{<vault>/.pensar/manifest.yml}. Pensar uses this file for
#' per-source ingest provenance and an opt-in \code{path -> page_uid}
#' address map.
#'
#' The manifest is written by \code{ingest()} and \code{ingest_repo()}
#' after a successful page write. Read-only operations
#' (\code{vault_registry()}, \code{update_index()}, and \code{status()})
#' never touch it. The directory is created lazily by
#' \code{update_manifest()}, so simply asking for the path does not
#' materialize \code{.pensar/}.
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
    normalize_manifest(parsed, fp)
}

#' Normalize a parsed manifest into the canonical struct
#'
#' Shared by \code{read_manifest()} and the merge path, which parses
#' manifest text from git index stages rather than a file.
#' @noRd
normalize_manifest <- function(parsed, fp = "<manifest>") {
    if (!is.list(parsed)) {
        return(empty_manifest())
    }
    parsed$version <- parsed$version %||% 1L
    parsed$created <- parsed$created %||% format(Sys.Date(), "%Y-%m-%d")
    parsed$sources <- coerce_manifest_map(parsed$sources, "sources", fp)
    parsed$address_map <- coerce_manifest_map(parsed$address_map,
        "address_map", fp)
    parsed
}

#' Coerce a manifest sub-field to a (possibly empty) named list
#'
#' YAML files in the wild sometimes use \code{sources: bad} (a scalar)
#' or \code{sources: []} (an unnamed list). Either would crash callers
#' that index with \code{[[path]]}. Coerce anything non-list to an
#' empty list and warn, so a corrupt manifest doesn't abort an ingest
#' midway.
#' @noRd
coerce_manifest_map <- function(x, field, fp) {
    if (is.null(x)) {
        return(list())
    }
    if (!is.list(x) || (length(x) > 0L && is.null(names(x)))) {
        warning("manifest field '", field, "' at ", fp,
                " is not a named list; treating as empty", call. = FALSE)
        return(list())
    }
    x
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
    other_fields_set <- !is.null(source) || !is.null(page_uid) ||
    !is.null(address) || !is.null(hash) || !is.null(ingested_at)
    if (is.null(path)) {
        if (other_fields_set) {
            stop("update_manifest(): `path` is required when any of ",
                 "source, page_uid, address, hash, or ingested_at is ",
                 "set.", call. = FALSE)
        }
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

#' Merge two manifest structs against a merged vault tree
#'
#' Union by path key, pruned to paths that exist in the tree (#52).
#' The manifest records ingest provenance, which cannot be regenerated
#' from files: union preserves it, pruning drops entries whose page no
#' longer exists after the merge. The result is independent of which
#' side is "ours": record conflicts are settled by hash match against
#' the merged file, then by earlier \code{ingested_at}.
#' @noRd
merge_manifest_structs <- function(ours, theirs, vault) {
    sources <- list()
    for (p in union(names(ours$sources), names(theirs$sources))) {
        fp <- file.path(vault, p)
        if (!file.exists(fp)) {
            next
        }
        sources[[p]] <- pick_manifest_record(ours$sources[[p]],
                                             theirs$sources[[p]], fp)
    }

    address_map <- list()
    for (p in union(names(ours$address_map), names(theirs$address_map))) {
        fp <- file.path(vault, p)
        if (!file.exists(fp)) {
            next
        }
        a <- ours$address_map[[p]]
        b <- theirs$address_map[[p]]
        if (is.null(a) || is.null(b) || identical(a, b)) {
            address_map[[p]] <- a %||% b
        } else {
            # Disagreement: the merged page's own frontmatter is the
            # authority for its uid (the registry derives it the same
            # way). Fall back to a symmetric tie-break.
            fm <- tryCatch(parse_frontmatter(fp), error = function(e) NULL)
            uid <- fm$id %||% fm$address
            if (is.null(uid) || is.list(uid) || length(uid) != 1L) {
                uid <- min(as.character(a)[1L], as.character(b)[1L])
            }
            address_map[[p]] <- as.character(uid)
        }
    }

    list(version = max(ours$version %||% 1L, theirs$version %||% 1L),
         created = min(ours$created, theirs$created),
         sources = sources, address_map = address_map)
}

#' Pick one of two per-path manifest records
#'
#' The record whose \code{hash} matches the merged file wins; ties go
#' to the earlier \code{ingested_at} (the original ingest). When
#' neither hash matches (a regenerated-in-place artifact, e.g. an
#' \code{ingest_repo()} overwrite), the kept record's hash is
#' refreshed so it describes the file that actually exists.
#' @noRd
pick_manifest_record <- function(a, b, fp) {
    if (!is.list(b)) {
        return(a)
    }
    if (!is.list(a)) {
        return(b)
    }
    if (identical(a, b)) {
        return(a)
    }
    tree_hash <- tryCatch(
                          paste0("sha1:", digest::digest(file = fp, algo = "sha1")),
                          error = function(e) NULL)
    a_match <- !is.null(tree_hash) && identical(a$hash, tree_hash)
    b_match <- !is.null(tree_hash) && identical(b$hash, tree_hash)
    if (a_match && !b_match) {
        return(a)
    }
    if (b_match && !a_match) {
        return(b)
    }
    ta <- as.character(a$ingested_at %||% "")[1L]
    tb <- as.character(b$ingested_at %||% "")[1L]
    chosen <- if (ta <= tb) a else b
    if (!a_match && !b_match && !is.null(tree_hash)) {
        chosen$hash <- tree_hash
    }
    chosen
}
