#' @title Vault log
#' @description Append-only operation log for a pensar vault.

#' Append a log entry
#'
#' Appends a structured entry to \code{log.md} with timestamp, operation
#' type, and message.
#'
#' @param message Description of what happened.
#' @param operation Operation type (e.g., \code{"init"}, \code{"ingest"},
#'   \code{"lint"}).
#' @param vault Path to the vault directory.
#' @return Invisible \code{NULL}.
#' @export
log_entry <- function(message, operation = "note", vault = default_vault()) {
    log_path <- file.path(vault, "log.md")
    entry <- sprintf("- **%s** [%s] %s", now_ts(), operation, message)
    cat(entry, "\n", sep = "", file = log_path, append = TRUE)
    invisible(NULL)
}

