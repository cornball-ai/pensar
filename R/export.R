#' @title Static HTML export
#' @description Render the vault to a directory of static HTML files.

#' Export the vault to static HTML
#'
#' Renders every markdown page in the vault to HTML, resolving
#' \code{[[wikilinks]]} to relative anchor tags. Output is a standalone
#' site that can be served from any static file server or opened via
#' \code{file://}.
#'
#' The rendered site is regenerable from the vault, so it defaults to
#' the R user cache directory (\code{tools::R_user_dir("pensar",
#' "cache")/site}) rather than living inside the vault itself. Pass a
#' different \code{out_dir} to override, or set the
#' \code{PENSAR_SITE_DIR} environment variable to change the default
#' globally (e.g., point it at a Syncthing folder so edits propagate
#' to other devices on export).
#'
#' Requires the \code{pandoc} command-line tool to be available.
#'
#' @param vault Path to the vault directory.
#' @param out_dir Destination directory. Defaults to the R user cache
#'   directory for pensar.
#' @return The output directory path, invisibly.
#' @export
vault_export <- function(vault = default_vault(),
                         out_dir = default_site_dir()) {
    vault <- normalizePath(vault, mustWork = TRUE)
    check_pandoc()

    out_dir <- normalizePath(out_dir, mustWork = FALSE)
    if (dir.exists(out_dir)) {
        unlink(out_dir, recursive = TRUE)
    }
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

    all_md <- list.files(vault, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)

    # Build a map of page name -> relative output path for wikilink resolution
    page_map <- build_page_map(all_md, vault)

    # Render each file
    for (fp in all_md) {
        render_page(fp, vault, out_dir, page_map)
    }

    # Write style.css and site index
    writeLines(default_css(), file.path(out_dir, "style.css"))
    write_site_index(all_md, vault, out_dir)

    log_entry(sprintf("Exported vault to %s", out_dir),
              operation = "export", vault = vault)

    message("Exported ", length(all_md), " pages to: ", out_dir)
    invisible(out_dir)
}

#' @noRd
check_pandoc <- function() {
    if (nchar(Sys.which("pandoc")) == 0L) {
        stop("pandoc not found on PATH. Install pandoc to use vault_export().")
    }
}

#' Build page-name -> relative HTML path map
#' @noRd
build_page_map <- function(all_md, vault) {
    names <- vapply(all_md, name_from_path, character(1L))
    rel_md <- vapply(all_md, make_relative, character(1L), base = vault)
    rel_html <- sub("\\.md$", ".html", rel_md)
    setNames(rel_html, names)
}

#' Resolve a [[wikilink]] to a relative href from a given source path
#' @noRd
resolve_link <- function(link, page_map, from_rel) {
    target_rel <- page_map[link]
    if (is.na(target_rel)) {
        return(NULL)
    }
    # Compute relative path from source to target
    from_parts <- strsplit(dirname(from_rel), "/", fixed = TRUE)[[1L]]
    from_parts <- from_parts[from_parts != "" & from_parts != "."]
    depth <- length(from_parts)
    if (depth > 0L) {
        prefix <- paste(rep("..", depth), collapse = "/")
        href <- paste0(prefix, "/", target_rel)
    } else {
        href <- target_rel
    }
    utils::URLencode(href)
}

#' Render one markdown file to HTML
#' @noRd
render_page <- function(fp, vault, out_dir, page_map) {
    rel_md <- make_relative(fp, vault)
    rel_html <- sub("\\.md$", ".html", rel_md)
    out_path <- file.path(out_dir, rel_html)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

    content <- paste(readLines(fp, warn = FALSE), collapse = "\n")

    # Replace [[wikilinks]] with markdown links before handing to pandoc
    content <- replace_wikilinks(content, page_map, rel_md)

    # Run through pandoc
    tf_in <- tempfile(fileext = ".md")
    tf_out <- tempfile(fileext = ".html")
    on.exit(unlink(c(tf_in, tf_out)), add = TRUE)
    writeLines(content, tf_in)
    status <- system2("pandoc",
                      c("-f", "markdown+yaml_metadata_block",
                        "-t", "html", "-o", tf_out, tf_in),
                      stdout = FALSE, stderr = FALSE)
    if (status != 0L) {
        warning("pandoc failed for: ", fp)
        return(invisible(NULL))
    }

    html_body <- paste(readLines(tf_out, warn = FALSE), collapse = "\n")
    fm <- parse_frontmatter(fp)
    title <- fm$title %||% name_from_path(fp)
    writeLines(wrap_html(title, html_body, rel_md), out_path)
    invisible(out_path)
}

#' Replace [[wikilinks]] with markdown links
#' @noRd
replace_wikilinks <- function(text, page_map, from_rel) {
    pattern <- "\\[\\[([^]]+)\\]\\]"
    m <- gregexpr(pattern, text, perl = TRUE)
    matches <- regmatches(text, m)[[1L]]
    if (length(matches) == 0L) {
        return(text)
    }
    for (raw in unique(matches)) {
        target <- gsub("^\\[\\[|\\]\\]$", "", raw)
        href <- resolve_link(target, page_map, from_rel)
        replacement <- if (is.null(href)) {
            # Broken link: render as plain span so it's visible but not a link
            paste0("<span class=\"broken-link\">", target, "</span>")
        } else {
            paste0("[", target, "](", href, ")")
        }
        text <- gsub(raw, replacement, text, fixed = TRUE)
    }
    text
}

#' HTML template
#' @noRd
wrap_html <- function(title, body, rel_md) {
    depth <- length(strsplit(dirname(rel_md), "/", fixed = TRUE)[[1L]])
    if (dirname(rel_md) %in% c(".", "")) {
        depth <- 0L
    } else {
        depth <- depth
    }
    css_path <- if (depth > 0L) {
        paste0(paste(rep("..", depth), collapse = "/"), "/style.css")
    } else {
        "style.css"
    }
    index_path <- if (depth > 0L) {
        paste0(paste(rep("..", depth), collapse = "/"), "/index.html")
    } else {
        "index.html"
    }

    c(
        "<!DOCTYPE html>",
        "<html lang=\"en\">",
        "<head>",
        "<meta charset=\"utf-8\">",
        sprintf("<title>%s</title>", html_escape(title)),
        sprintf("<link rel=\"stylesheet\" href=\"%s\">", css_path),
        "</head>",
        "<body>",
        sprintf("<nav><a href=\"%s\">&larr; Index</a></nav>", index_path),
        "<main>",
        body,
        "</main>",
        "</body>",
        "</html>"
    )
}

#' Minimal HTML escape for title attribute
#' @noRd
html_escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
}

#' Default CSS for the exported site
#' @noRd
default_css <- function() {
    c(
        "body { font-family: -apple-system, system-ui, sans-serif;",
        "  max-width: 780px; margin: 2em auto; padding: 0 1em;",
        "  line-height: 1.6; color: #222; }",
        "nav { margin-bottom: 2em; font-size: 0.9em; }",
        "nav a { color: #666; text-decoration: none; }",
        "nav a:hover { text-decoration: underline; }",
        "h1, h2, h3 { line-height: 1.2; }",
        "h1 { border-bottom: 1px solid #eee; padding-bottom: 0.2em; }",
        "a { color: #0066cc; }",
        "code { background: #f4f4f4; padding: 0.1em 0.3em; border-radius: 3px;",
        "  font-size: 0.9em; }",
        "pre { background: #f4f4f4; padding: 1em; overflow-x: auto; }",
        "pre code { background: none; padding: 0; }",
        "table { border-collapse: collapse; margin: 1em 0; }",
        "th, td { border: 1px solid #ddd; padding: 0.4em 0.8em; text-align: left; }",
        "th { background: #f9f9f9; }",
        ".broken-link { color: #c00; text-decoration: line-through; }",
        "blockquote { border-left: 3px solid #ccc; margin: 1em 0;",
        "  padding: 0.2em 1em; color: #555; }"
    )
}

#' Write a top-level site index listing all pages
#' @noRd
write_site_index <- function(all_md, vault, out_dir) {
    page_names <- vapply(all_md, name_from_path, character(1L))
    rel_md <- vapply(all_md, make_relative, character(1L), base = vault)
    rel_html <- sub("\\.md$", ".html", rel_md)

    categories <- list(
                       "Wiki" = file.path("wiki", ""),
                       "Raw: Articles" = file.path("raw", "articles", ""),
                       "Raw: Chats" = file.path("raw", "chats", ""),
                       "Raw: Briefings" = file.path("raw", "briefings", ""),
                       "Raw: Matrix" = file.path("raw", "matrix", "")
    )
    controls <- c("index.md", "log.md", "schema.md")

    body_lines <- c("<h1>Vault</h1>")
    # Control files section
    control_indices <- which(basename(rel_md) %in% controls &
                             !grepl("/", rel_md))
    if (length(control_indices) > 0L) {
        body_lines <- c(body_lines, "<h2>Control</h2>", "<ul>")
        for (i in control_indices) {
            body_lines <- c(body_lines,
                            sprintf("<li><a href=\"%s\">%s</a></li>",
                                    utils::URLencode(rel_html[i]),
                                    html_escape(page_names[i])))
        }
        body_lines <- c(body_lines, "</ul>")
    }

    for (cat_name in names(categories)) {
        cat_prefix <- categories[[cat_name]]
        idx <- which(startsWith(rel_md, cat_prefix))
        if (length(idx) == 0L) {
            next
        }
        body_lines <- c(body_lines,
                        sprintf("<h2>%s (%d)</h2>", html_escape(cat_name), length(idx)),
                        "<ul>")
        for (i in sort(idx)) {
            fm <- parse_frontmatter(all_md[i])
            title <- fm$title %||% page_names[i]
            body_lines <- c(body_lines,
                            sprintf("<li><a href=\"%s\">%s</a></li>",
                                    utils::URLencode(rel_html[i]),
                                    html_escape(title)))
        }
        body_lines <- c(body_lines, "</ul>")
    }

    html <- c(
              "<!DOCTYPE html>",
              "<html lang=\"en\">",
              "<head>",
              "<meta charset=\"utf-8\">",
              "<title>Vault</title>",
              "<link rel=\"stylesheet\" href=\"style.css\">",
              "</head>",
              "<body>",
              "<main>",
              body_lines,
              "</main>",
              "</body>",
              "</html>"
    )
    writeLines(html, file.path(out_dir, "index.html"))
}

