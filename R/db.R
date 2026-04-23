#' @title Vault utility helpers
#' @description Internal helpers for vault path resolution, timestamps,
#'   slug generation, and path manipulation.

#' Default vault path
#'
#' Resolution order:
#' \enumerate{
#'   \item \code{options("pensar.vault")} (set by \code{use_vault()} within a session).
#'   \item The \code{PENSAR_VAULT} environment variable (for one-shot CLI invocations).
#'   \item \code{tools::R_user_dir("pensar", "data")} (CRAN-safe fallback).
#' }
#' The \code{R_user_dir()} fallback is ugly (\code{~/.local/share/R/pensar/}
#' on Linux). Most users \code{init_vault("~/wiki")} and persist
#' \code{use_vault("~/wiki")} in \code{~/.Rprofile}.
#' @return Character string.
#' @noRd
default_vault <- function() {
    opt <- getOption("pensar.vault", NULL)
    if (!is.null(opt)) return(path.expand(opt))
    env <- Sys.getenv("PENSAR_VAULT", unset = "")
    if (nzchar(env)) return(path.expand(env))
    tools::R_user_dir("pensar", "data")
}

#' Remember a vault path for this R session
#'
#' Sets \code{options("pensar.vault")} so subsequent pensar calls
#' resolve to \code{path} without repeating the argument. Persist by
#' adding \code{pensar::use_vault("~/wiki")} to \code{~/.Rprofile}.
#' @param path Path to your pensar vault directory.
#' @return The resolved path, invisibly.
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
#' Falls back to the R user cache directory.
#' @return Character string.
#' @noRd
default_site_dir <- function() {
    env <- Sys.getenv("PENSAR_SITE_DIR", unset = "")
    if (nchar(env) > 0L) {
        return(path.expand(env))
    }
    file.path(tools::R_user_dir("pensar", "cache"), "site")
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

