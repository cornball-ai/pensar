#' @title Vault utility helpers
#' @description Internal helpers for vault path resolution, timestamps,
#'   slug generation, and path manipulation.

#' Default vault path
#'
#' Returns the standard R user data directory for pensar.
#' @return Character string.
#' @noRd
default_vault <- function() {
    tools::R_user_dir("pensar", "data")
}

#' Default site (export) directory
#'
#' Regenerable rendered HTML lives in the R user cache directory.
#' @return Character string.
#' @noRd
default_site_dir <- function() {
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
    path <- normalizePath(path, mustWork = FALSE)
    base <- paste0(normalizePath(base, mustWork = FALSE), "/")
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

