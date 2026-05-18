#' @title Vault utility helpers
#' @description Internal helpers for vault path resolution, timestamps,
#'   slug generation, and path manipulation.

#' Resolve a vault path and report where it came from
#'
#' Tries the configured sources in order and returns the first hit
#' along with a label describing which source matched. Used by
#' \code{default_vault()} (which discards the label) and by callers
#' that surface provenance to the user, e.g. \code{status()}.
#'
#' Resolution order (all opt-in):
#' \enumerate{
#'   \item The \code{PENSAR_VAULT} environment variable.
#'   \item Walk-up from \code{start} looking for \code{schema.md} in
#'     the current rung, then \code{vault/schema.md} one level down,
#'     then climb.
#'   \item \code{options("pensar.vault")} (set by \code{use_vault()},
#'     typically in \code{~/.Rprofile} as a global default).
#' }
#' Per CRAN policy, no implicit home-filespace fallback. If none of
#' these resolves, errors with a setup hint.
#' @param start Starting directory for walk-up. Defaults to
#'   \code{getwd()}. Exposed for testability.
#' @return Named list with \code{path} (normalized) and \code{source}
#'   (one of \code{"env"}, \code{"walkup"}, \code{"walkup-subdir"},
#'   \code{"option"}).
#' @noRd
resolve_vault <- function(start = getwd()) {
    env <- Sys.getenv("PENSAR_VAULT", unset = "")
    if (nzchar(env)) {
        return(list(path = normalizePath(path.expand(env), mustWork = FALSE),
                    source = "env"))
    }
    proj <- find_vault_walkup(start)
    if (!is.null(proj)) {
        return(proj)
    }
    opt <- getOption("pensar.vault", NULL)
    if (!is.null(opt)) {
        return(list(path = normalizePath(path.expand(opt), mustWork = FALSE),
                    source = "option"))
    }
    stop("No pensar vault configured. Choose one of:\n",
         "  - Set PENSAR_VAULT=/path/to/vault in your environment\n",
         "  - Call pensar::use_vault('/path/to/vault') ",
         "(persist via ~/.Rprofile)\n",
         "  - Run from inside a directory containing schema.md, or ",
         "from a parent directory whose vault/ subdir contains it\n",
         "  - Pass vault = '/path' (or path = '/path' for ",
         "init_vault()) explicitly", call. = FALSE)
}

#' Default vault path
#'
#' Thin wrapper around \code{resolve_vault()} that returns just the
#' path. Most callers want this; \code{status()} calls
#' \code{resolve_vault()} directly to keep the source label.
#' @return Character string.
#' @noRd
default_vault <- function() {
    resolve_vault()$path
}

#' Walk up from a starting directory looking for a vault marker
#'
#' A directory containing \code{schema.md} is treated as a vault root.
#' \code{init_vault()} seeds \code{schema.md} and refuses to overwrite,
#' so its presence is a reliable marker. At each rung the current
#' directory is preferred over a \code{vault/} subdir.
#' @param start Starting directory. Defaults to \code{getwd()}.
#' @return Named list with \code{path} and \code{source}
#'   (\code{"walkup"} or \code{"walkup-subdir"}), or \code{NULL} if no
#'   vault is found before reaching the filesystem root.
#' @noRd
find_vault_walkup <- function(start = getwd()) {
    dir <- normalizePath(start, mustWork = FALSE)
    repeat {
        if (file.exists(file.path(dir, "schema.md"))) {
            # Re-normalize: when `start` doesn't exist (e.g., a
            # subdir like /vault/wiki that hasn't been created),
            # normalizePath() with mustWork = FALSE returns the
            # input unchanged on Windows, keeping forward slashes.
            # By the time we land here `dir` actually exists, so
            # we can resolve it to the canonical platform form
            # (backslashes on Windows) and avoid drifting from
            # downstream `normalizePath()` calls.
            return(list(path = normalizePath(dir, mustWork = TRUE),
                        source = "walkup"))
        }
        sub <- file.path(dir, "vault")
        if (file.exists(file.path(sub, "schema.md"))) {
            return(list(path = normalizePath(sub, mustWork = TRUE),
                        source = "walkup-subdir"))
        }
        parent <- dirname(dir)
        if (parent == dir) {
            return(NULL)
        }
        dir <- parent
    }
}

#' Remember a vault path for this R session
#'
#' Sets \code{options("pensar.vault")} so subsequent pensar calls
#' resolve to \code{path} without repeating the argument. Persist by
#' adding \code{pensar::use_vault("~/wiki")} to \code{~/.Rprofile} as
#' a global default. Both \code{PENSAR_VAULT} and a project-local
#' \code{schema.md} found via walk-up (in the current directory or a
#' \code{vault/} subdir) will override this option (see
#' \code{default_vault} resolution order).
#' @param path Path to your pensar vault directory.
#' @return The resolved path, invisibly.
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' use_vault(v)
#' status()
#' options(pensar.vault = NULL)
#' unlink(v, recursive = TRUE)
#' @export
use_vault <- function(path) {
    path <- normalizePath(path.expand(path), mustWork = TRUE)
    options(pensar.vault = path)
    invisible(path)
}

#' Default site (export) directory
#'
#' Honors the \code{PENSAR_SITE_DIR} environment variable for users who
#' want the site to land in a synced folder (Syncthing, Dropbox, etc.).
#' Per CRAN policy, there is no implicit home-filespace fallback -- if
#' \code{PENSAR_SITE_DIR} is unset, \code{vault_export()} requires an
#' explicit \code{out_dir =}.
#' @return Character string.
#' @noRd
default_site_dir <- function() {
    env <- Sys.getenv("PENSAR_SITE_DIR", unset = "")
    if (nchar(env) > 0L) {
        return(path.expand(env))
    }
    stop("No pensar site directory configured. Choose one of:\n",
         "  - Set PENSAR_SITE_DIR=/path/to/site in your environment\n",
         "  - Pass out_dir = '/path' to vault_export() explicitly",
         call. = FALSE)
}

#' ISO 8601 timestamp
#' @noRd
now_ts <- function() {
    format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
}

#' Make a path relative to a base directory
#' @noRd
make_relative <- function(path, base) {
    path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    base <- paste0(normalizePath(base, winslash = "/", mustWork = FALSE), "/")
    sub(base, "", path, fixed = TRUE)
}

#' Convert a string to a filename-safe slug
#' @noRd
slugify <- function(x) {
    x <- tolower(x)
    x <- gsub("https?://", "", x)
    x <- gsub("[^a-z0-9]+", "-", x)
    x <- gsub("^-|-$", "", x)
    if (nchar(x) > 60L) {
        x <- substr(x, 1L, 60L)
        x <- sub("-$", "", x)
    }
    x
}

#' Generate a unique file path (append -2, -3, etc. on collision)
#' @noRd
unique_path <- function(path) {
    if (!file.exists(path)) {
        return(path)
    }
    dir <- dirname(path)
    base <- tools::file_path_sans_ext(basename(path))
    ext <- tools::file_ext(path)
    i <- 2L
    repeat {
        candidate <- file.path(dir, paste0(base, "-", i, ".", ext))
        if (!file.exists(candidate)) {
            return(candidate)
        }
        i <- i + 1L
    }
}

#' Null-coalescing operator
#' @noRd
`%||%` <- function(a, b) {
    if (is.null(a)) {
        b
    } else {
        a
    }
}

