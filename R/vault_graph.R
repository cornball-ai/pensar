#' @title Vault wikilink graph
#' @description Render the vault's wikilink graph as SVG via saber.

#' Render a vault's wikilink graph as SVG
#'
#' Scans every markdown page in the vault (excluding control files),
#' extracts \code{[[wikilinks]]} as edges, and renders the result via
#' \code{saber::graph_svg()}. Node tooltips carry the page type, tags,
#' and date from YAML frontmatter; broken wikilinks (targets with no
#' matching page) appear as external nodes with a distinct tooltip.
#'
#' @param vault Path to the vault directory.
#' @param width,height Viewport in pixels. Defaults (1600 x 1200) are
#'   larger than \code{saber::graph_svg()}'s defaults since vaults tend
#'   toward many nodes.
#' @param ... Passed through to \code{saber::graph_svg()} (e.g.,
#'   \code{iterations}, \code{seed}).
#' @return Character vector of SVG lines. Write with \code{writeLines()}.
#' @export
vault_graph <- function(vault = default_vault(), width = 1600L,
                        height = 1200L, ...) {
    if (!requireNamespace("saber", quietly = TRUE)) {
        stop("Package 'saber' is required for vault_graph(). ",
             "Install it from https://github.com/cornball-ai/saber")
    }
    vault <- normalizePath(vault, mustWork = TRUE)

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
    control <- c("index.md", "log.md", "schema.md")
    all_md <- all_md[!basename(all_md) %in% control |
        dirname(all_md) != vault]

    if (length(all_md) == 0L) {
        stop("No pages in vault: ", vault)
    }

    names_vec <- unname(vapply(all_md, name_from_path, character(1L)))
    edges <- list()
    tooltips <- character(length(all_md))
    types <- character(length(all_md))

    for (i in seq_along(all_md)) {
        fm <- parse_frontmatter(all_md[i])
        types[i] <- fm$type %||% category_from_path(all_md[i], vault)
        if (length(fm$tags)) {
            tags <- paste(fm$tags, collapse = ", ")
        } else {
            tags <- "(no tags)"
        }
        date <- fm$date %||% "(no date)"
        title <- fm$title %||% names_vec[i]
        lede <- page_lede(all_md[i])
        tooltips[i] <- paste(c(
                               title,
                               sprintf("type: %s | date: %s", types[i], date),
                               sprintf("tags: %s", tags),
                if (nzchar(lede)) lede
            ), collapse = "\n")

        links <- unique(parse_wikilinks(all_md[i]))
        if (length(links)) {
            edges[[i]] <- data.frame(from = names_vec[i], to = links,
                                     stringsAsFactors = FALSE)
        }
    }
    edges <- do.call(rbind, edges)
    if (is.null(edges)) {
        edges <- data.frame(from = character(), to = character(),
                            stringsAsFactors = FALSE)
    }

    # Broken wikilinks: targets that aren't actual pages
    broken <- setdiff(unique(edges$to), names_vec)
    if (length(broken)) {
        names_vec <- c(names_vec, broken)
        tooltips <- c(tooltips, paste0(broken, "\n(broken wikilink)"))
        types <- c(types, rep("broken", length(broken)))
    }

    nodes <- data.frame(id = names_vec, label = names_vec,
                        href = NA_character_, tooltip = tooltips,
                        stringsAsFactors = FALSE)

    saber_graph_svg <- tryCatch(
        getExportedValue("saber", "graph_svg"),
        error = function(e) NULL
    )
    if (is.null(saber_graph_svg)) {
        stop("vault_graph() requires saber (>= 0.6.0) which exports ",
             "graph_svg(). Install the development version from ",
             "https://github.com/cornball-ai/saber")
    }
    saber_graph_svg(edges, nodes, width = width, height = height, ...)
}

#' Read the first non-empty, non-header body line from a markdown file,
#' truncated to a readable length for tooltip use.
#' @noRd
page_lede <- function(fp, max_chars = 140L) {
    lines <- readLines(fp, warn = FALSE)
    # Skip frontmatter block (--- ... ---)
    if (length(lines) >= 2L && trimws(lines[1L]) == "---") {
        end <- which(trimws(lines[-1L]) == "---")[1L]
        if (!is.na(end)) {
            lines <- lines[-(1L:(end + 1L))]
        }
    }
    # Strip markdown noise we don't want in a lede
    lines <- trimws(lines)
    lines <- lines[nzchar(lines)]
    lines <- lines[!grepl("^#+\\s", lines)]
    lines <- lines[!grepl("^---+$", lines)]
    # Drop YAML-like key: value lines that show up when an ingested page
    # has its own frontmatter block nested in the body.
    lines <- lines[!grepl("^[A-Za-z][A-Za-z0-9_-]*:", lines)]
    lines <- lines[!grepl("^-\\s", lines)]
    lines <- lines[!grepl("^!\\[", lines)]
    if (!length(lines)) {
        return("")
    }
    first <- lines[1L]
    if (nchar(first) > max_chars) {
        first <- paste0(substr(first, 1L, max_chars - 1L), "\u2026")
    }
    first
}

#' Infer category from a page's path when frontmatter type is missing
#' @noRd
category_from_path <- function(fp, vault) {
    rel <- sub(paste0("^", vault, "/?"), "", fp, fixed = FALSE)
    parts <- strsplit(rel, "/", fixed = TRUE)[[1L]]
    if (length(parts) >= 2L && parts[1L] == "raw") {
        return(parts[2L])
    }
    if (length(parts) >= 1L && parts[1L] == "wiki") {
        return("wiki")
    }
    "unknown"
}

