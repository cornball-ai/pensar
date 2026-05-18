#' @title Autoresearch program loading
#' @description Internal helpers for loading the machine-readable
#' autoresearch runtime program.

#' Load the autoresearch runtime program
#'
#' Merges package defaults with either an explicit \code{program} override
#' or a vault-local \code{_research/program.yml}.
#'
#' @param vault Vault path.
#' @param program Optional list or YAML path.
#' @return Named list of validated program settings.
#' @noRd
load_autoresearch_program <- function(vault = default_vault(), program = NULL) {
    vault <- normalizePath(vault, mustWork = TRUE)
    base <- .default_autoresearch_program()

    override <- NULL
    if (is.list(program)) {
        override <- program
    } else if (is.character(program) && length(program) == 1L &&
        nzchar(program)) {
        override <- .read_autoresearch_program(program)
    } else {
        vault_program <- file.path(vault, "_research", "program.yml")
        if (file.exists(vault_program)) {
            override <- .read_autoresearch_program(vault_program)
        }
    }

    if (!is.null(override)) {
        base <- .merge_autoresearch_program(base, override)
    }
    .validate_autoresearch_program(base)
}

#' @noRd
.default_autoresearch_program <- function() {
    path <- system.file("autoresearch", "program.yml", package = "pensar")
    if (nzchar(path) && file.exists(path)) {
        return(.read_autoresearch_program(path))
    }
    list(
         max_rounds = 3L,
         max_queries_per_round = 5L,
         max_sources_per_round = 5L,
         max_pages = 15L,
         source_preferences = c("official documentation", "primary sources",
                                "peer-reviewed papers",
                                "established publications"),
         confidence = list(
                           high = "multiple independent authoritative sources agree",
                           medium = "one good source, or sources partially agree",
                           low = paste("speculation, opinion, informal source, or",
                                       "unverified claim")
        ),
         stale_after_days = 1095L,
         required_tags = "research"
    )
}

#' @noRd
.read_autoresearch_program <- function(path) {
    if (!file.exists(path)) {
        stop("Autoresearch program file not found: ", path, call. = FALSE)
    }
    x <- yaml::yaml.load_file(path)
    if (is.null(x)) {
        x <- list()
    }
    if (!is.list(x)) {
        stop("Autoresearch program must parse to a YAML mapping: ", path,
             call. = FALSE)
    }
    x
}

#' @noRd
.merge_autoresearch_program <- function(base, override) {
    for (nm in names(override)) {
        if (is.list(base[[nm]]) && is.list(override[[nm]])) {
            base[[nm]] <- .merge_autoresearch_program(base[[nm]],
                override[[nm]])
        } else {
            base[[nm]] <- override[[nm]]
        }
    }
    base
}

#' @noRd
.validate_autoresearch_program <- function(program) {
    int_fields <- c("max_rounds", "max_queries_per_round",
                    "max_sources_per_round", "max_pages", "stale_after_days")
    for (field in int_fields) {
        value <- program[[field]]
        if (is.null(value) || length(value) != 1L ||
            is.na(suppressWarnings(as.integer(value))) ||
            as.integer(value) < 1L) {
            stop("Autoresearch program field `", field,
                 "` must be a positive integer.", call. = FALSE)
        }
        program[[field]] <- as.integer(value)
    }

    char_fields <- c("source_preferences", "required_tags")
    for (field in char_fields) {
        value <- program[[field]]
        if (is.null(value)) {
            program[[field]] <- character(0L)
        } else {
            program[[field]] <- as.character(value)
        }
    }

    if (!is.list(program$confidence)) {
        program$confidence <- list()
    }
    program
}

