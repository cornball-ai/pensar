#' @title Vault utility helpers
#' @description Internal helpers for vault path resolution, timestamps,
#'   slug generation, and path manipulation.

#' Default vault path
#'
#' Resolves to a user-configured vault path. Per CRAN policy, pensar
#' will not silently write to the user's home filespace, so there is
#' no implicit fallback location -- the user must opt in.
#'
#' Resolution order (all opt-in):
#' \enumerate{
#'   \item The \code{PENSAR_VAULT} environment variable.
#'   \item Walk-up from \code{getwd()} looking for a \code{schema.md} marker
#'     (project-local vault; mirrors how git finds \code{.git}).
#'   \item \code{options("pensar.vault")} (set by \code{use_vault()},
#'     typically in \code{~/.Rprofile} as a global default).
#' }
#' If none of these resolves, \code{default_vault()} errors with a
#' setup hint. Callers wanting a one-off path should pass
#' \code{vault =} explicitly (examples and tests use \code{tempfile()}
#' / \code{tempdir()}).
#' @return Character string.
#' @noRd
default_vault <- function() {
    env <- Sys.getenv("PENSAR_VAULT", unset = "")
    if (nzchar(env)) {
        return(path.expand(env))
    }
    proj <- find_vault_walkup()
    if (!is.null(proj)) {
        return(proj)
    }
    opt <- getOption("pensar.vault", NULL)
    if (!is.null(opt)) {
        return(path.expand(opt))
    }
    stop("No pensar vault configured. Choose one of:\n",
         "  - Set PENSAR_VAULT=/path/to/vault in your environment\n",
         "  - Call pensar::use_vault('/path/to/vault') ",
         "(persist via ~/.Rprofile)\n",
         "  - Run from inside a directory containing schema.md\n",
         "  - Pass vault = '/path' (or path = '/path' for ",
         "init_vault()) explicitly",
         call. = FALSE)
}

#' Walk up from a starting directory looking for a vault marker
#'
#' A directory containing \code{schema.md} is treated as a vault root.
#' \code{init_vault()} seeds \code{schema.md} and refuses to overwrite,
#' so its presence is a reliable marker.
#' @param start Starting directory. Defaults to \code{getwd()}.
#' @return Vault path, or \code{NULL} if no vault is found before reaching
#'   the filesystem root.
#' @noRd
find_vault_walkup <- function(start = getwd()) {
    dir <- normalizePath(start, mustWork = FALSE)
    repeat {
        if (file.exists(file.path(dir, "schema.md"))) {
            return(dir)
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
#' \code{schema.md} found via walk-up will override this option (see
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

