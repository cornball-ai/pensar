#' @title Markdown parsing
#' @description Parse frontmatter and typed links from markdown files.

#' Parse YAML frontmatter from a markdown file
#'
#' @param filepath Path to a markdown file.
#' @return A list with frontmatter fields, or an empty list if none found.
#' @noRd
parse_frontmatter <- function(filepath) {
    lines <- readLines(filepath, warn = FALSE)
    if (length(lines) < 2L || trimws(lines[1L]) != "---") {
        return(list())
    }
    end <- which(trimws(lines[-1L]) == "---")[1L]
    if (is.na(end)) {
        return(list())
    }
    end <- end + 1L
    yaml_text <- paste(lines[2L:(end - 1L)], collapse = "\n")
    tryCatch(yaml::yaml.load(yaml_text), error = function(e) list())
}

#' Parse all wikilinks from a markdown file
#'
#' @param filepath Path to a markdown file.
#' @return Character vector of link targets.
#' @noRd
parse_wikilinks <- function(filepath) {
    lines <- readLines(filepath, warn = FALSE)
    all_links <- regmatches(lines, gregexpr("\\[\\[([^]]+)\\]\\]", lines))
    all_links <- unlist(all_links)
    if (length(all_links) == 0L) {
        return(character(0L))
    }
    vapply(all_links, wikilink_target, character(1L), USE.NAMES = FALSE)
}

#' Extract the target page from a raw wikilink
#'
#' Supports Obsidian-style aliases: [[page-slug|display text]] links to
#' page-slug while displaying "display text".
#' @noRd
wikilink_target <- function(link) {
    parsed <- parse_wikilink(link)
    parsed$target
}

#' Parse a raw wikilink into target and label
#' @noRd
parse_wikilink <- function(link) {
    inner <- gsub("^\\[\\[|\\]\\]$", "", link)
    parts <- strsplit(inner, "|", fixed = TRUE)[[1L]]
    target <- trimws(parts[1L])
    label <- if (length(parts) > 1L) {
        trimws(paste(parts[-1L], collapse = "|"))
    } else {
        target
    }
    list(target = target, label = label)
}

#' Derive the term name from a filepath
#'
#' Path-aware: files under \code{raw/repos/<repo>/} return
#' \code{<repo>/<basename>} so that artifacts of different repos do not
#' collide on a shared filename like \code{briefing.md}. Everything else
#' returns the basename without extension.
#'
#' @param filepath Path to a markdown file.
#' @return The term name used in the wikilink graph.
#' @noRd
name_from_path <- function(filepath) {
    base <- tools::file_path_sans_ext(basename(filepath))
    parent <- basename(dirname(filepath))
    grandparent <- basename(dirname(dirname(filepath)))
    if (grandparent == "repos") {
        return(paste0(parent, "/", base))
    }
    base
}

#' Compute a file hash for change detection
#'
#' @param filepath Path to a file.
#' @return MD5 hash as a hex string.
#' @noRd
file_hash <- function(filepath) {
    tools::md5sum(filepath)[[1L]]
}

#' Parse an R package DESCRIPTION file
#'
#' Extracts Package name and all four dependency fields.
#'
#' @param filepath Path to a DESCRIPTION file.
#' @return A list with components: package, depends, imports, suggests,
#'   links_to (character vectors).
#' @noRd
parse_description <- function(filepath) {
    dcf <- tryCatch(read.dcf(filepath,
                             fields = c("Package", "Depends", "Imports", "Suggests",
                                        "LinkingTo")),
                    error = function(e) return(NULL))
    if (is.null(dcf) || nrow(dcf) == 0L) {
        return(list(package = NA_character_, depends = character(0L),
                    imports = character(0L), suggests = character(0L),
                    links_to = character(0L)))
    }
    pkg <- dcf[1L, "Package"]
    depends <- parse_dcf_list(dcf[1L, "Depends"])
    depends <- depends[depends != "R"]
    imports <- parse_dcf_list(dcf[1L, "Imports"])
    suggests <- parse_dcf_list(dcf[1L, "Suggests"])
    links_to <- parse_dcf_list(dcf[1L, "LinkingTo"])
    list(package = pkg, depends = depends, imports = imports,
         suggests = suggests, links_to = links_to)
}

#' Parse a comma-separated DCF field into a clean character vector
#' @noRd
parse_dcf_list <- function(x) {
    if (is.na(x) || nchar(trimws(x)) == 0L) {
        return(character(0L))
    }
    parts <- strsplit(x, ",")[[1L]]
    parts <- trimws(parts)
    # Strip version constraints like (>= 1.0)
    parts <- sub("\\s*\\(.*\\)", "", parts)
    parts <- parts[nchar(parts) > 0L]
    parts
}

