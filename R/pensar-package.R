#' pensar: LLM Wiki Engine
#'
#' Maintains a persistent, compounding knowledge base of markdown files
#' for large language model agents to summarize, cross-reference, and
#' edit. Humans curate sources; the agent maintains the wiki.
#'
#' Per CRAN policy, pensar never writes to a default location in the
#' user's home filespace. Configure a vault path via one of:
#'
#' \itemize{
#'   \item \code{Sys.setenv(PENSAR_VAULT = "/path/to/vault")}
#'   \item \code{pensar::use_vault("/path/to/vault")} (typically in
#'     \code{~/.Rprofile})
#'   \item Working from a directory containing \code{schema.md}, or
#'     whose \code{vault/} subdir contains it (auto-detected via
#'     walk-up from \code{getwd()})
#'   \item Passing \code{vault =} (or \code{path =} for \code{init_vault()})
#'     explicitly to each call
#' }
#'
#' @keywords internal
"_PACKAGE"
