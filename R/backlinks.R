#' @title Backlink discovery
#' @description Find pages that link to a given page via wikilinks.

#' Find backlinks to a page
#'
#' Scans all markdown files in the vault for \code{[[wikilinks]]} that
#' reference the target page.
#'
#' @param page Page name (without \code{.md} extension).
#' @param vault Path to the vault directory.
#' @return A data.frame with columns \code{source} (page name) and
#'   \code{file} (path relative to the vault).
#' @examples
#' v <- tempfile("vault-")
#' init_vault(v, rproj = FALSE, agent_instructions = FALSE)
#' ingest("See [[seed]] for context.", type = "articles",
#'        source = "demo", vault = v)
#' backlinks("seed", vault = v)
#' unlink(v, recursive = TRUE)
#' @export
backlinks <- function(page, vault = default_vault()) {
    vault <- normalizePath(vault, mustWork = TRUE)

    # Resolve the query to a canonical relative path. Any wikilink that
    # also resolves there is a backlink source, even if its surface
    # spelling differs (e.g., `[[Notes/Foo]]` vs `[[Foo]]`).
    target_path <- resolve_target_path(page, vault)
    if (is.na(target_path)) {
        return(data.frame(source = character(0L), file = character(0L),
                          stringsAsFactors = FALSE))
    }

    reg <- vault_registry(vault)
    sources <- character(0L)
    files <- character(0L)

    for (i in seq_len(nrow(reg))) {
        if (isTRUE(reg$system_file[i])) {
            next
        }
        links <- reg$links_out[[i]]
        if (length(links) == 0L) {
            next
        }
        resolved <- vapply(links, resolve_target_path, character(1L),
                           vault = vault)
        if (target_path %in% resolved) {
            sources <- c(sources, reg$node_id[i])
            files <- c(files, reg$path[i])
        }
    }

    data.frame(source = sources, file = files, stringsAsFactors = FALSE)
}
