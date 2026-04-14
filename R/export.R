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
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
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
        ":root {",
        "  --fg: #1a1a1a; --fg-muted: #555; --bg: #fefefe;",
        "  --accent: #0066cc; --accent-visited: #6a4fcf;",
        "  --rule: #e5e5e5; --code-bg: #f4f4f4; --broken: #c00;",
        "  --card-bg: #fafafa; --card-border: #e5e5e5;",
        "}",
        "@media (prefers-color-scheme: dark) {",
        "  :root {",
        "    --fg: #e8e8e8; --fg-muted: #9aa0a6; --bg: #1a1b1e;",
        "    --accent: #66b3ff; --accent-visited: #b392f0;",
        "    --rule: #2b2d31; --code-bg: #26282d; --broken: #ff6b6b;",
        "    --card-bg: #1f2024; --card-border: #2b2d31;",
        "  }",
        "}",
        "* { box-sizing: border-box; }",
        "body {",
        "  font-family: ui-sans-serif, -apple-system, system-ui, sans-serif;",
        "  max-width: 820px; margin: 0 auto; padding: 1.5em 1.2em 4em;",
        "  line-height: 1.65; color: var(--fg); background: var(--bg);",
        "  font-size: 16px;",
        "}",
        "nav {",
        "  margin-bottom: 2em; font-size: 0.85em;",
        "  padding-bottom: 0.8em; border-bottom: 1px solid var(--rule);",
        "}",
        "nav a { color: var(--fg-muted); text-decoration: none; }",
        "nav a:hover { color: var(--accent); text-decoration: underline; }",
        "main { font-size: 1em; }",
        "h1, h2, h3, h4 { line-height: 1.25; margin-top: 1.6em;",
        "  margin-bottom: 0.5em; }",
        "h1 {",
        "  font-size: 1.8em; border-bottom: 1px solid var(--rule);",
        "  padding-bottom: 0.25em; margin-top: 0.5em;",
        "}",
        "h2 { font-size: 1.35em; color: var(--fg); }",
        "h3 { font-size: 1.1em; color: var(--fg-muted); }",
        "p { margin: 0.8em 0; }",
        "a { color: var(--accent); text-decoration: none; }",
        "a:hover { text-decoration: underline; }",
        "a:visited { color: var(--accent-visited); }",
        "code {",
        "  background: var(--code-bg); padding: 0.12em 0.35em;",
        "  border-radius: 3px; font-size: 0.88em;",
        "  font-family: ui-monospace, 'SF Mono', Menlo, Consolas, monospace;",
        "}",
        "pre {",
        "  background: var(--code-bg); padding: 0.9em 1em;",
        "  overflow-x: auto; border-radius: 5px; line-height: 1.45;",
        "  font-size: 0.88em;",
        "}",
        "pre code { background: none; padding: 0; font-size: 1em; }",
        "blockquote {",
        "  border-left: 3px solid var(--rule); margin: 1em 0;",
        "  padding: 0.2em 1em; color: var(--fg-muted);",
        "}",
        "table {",
        "  border-collapse: collapse; margin: 1em 0; width: 100%;",
        "  font-size: 0.95em;",
        "}",
        "th, td {",
        "  border: 1px solid var(--rule); padding: 0.5em 0.8em;",
        "  text-align: left; vertical-align: top;",
        "}",
        "th { background: var(--code-bg); font-weight: 600; }",
        "ul, ol { padding-left: 1.6em; }",
        "li { margin: 0.2em 0; }",
        "hr { border: none; border-top: 1px solid var(--rule); margin: 2em 0; }",
        ".broken-link {",
        "  color: var(--broken); text-decoration: line-through;",
        "  font-style: italic;",
        "}",
        "/* Index page: category cards + two-column on wide screens */",
        "main > h1:first-child { font-size: 2em; }",
        "main > h2 {",
        "  margin-top: 1.5em; padding: 0.5em 0.8em;",
        "  background: var(--card-bg); border: 1px solid var(--card-border);",
        "  border-radius: 6px; font-size: 1.1em;",
        "}",
        "main > h2 + ul {",
        "  list-style: none; padding: 0.5em 0 0 0.8em; margin-top: 0.3em;",
        "}",
        "main > h2 + ul li {",
        "  padding: 0.15em 0; border-bottom: 1px dotted var(--rule);",
        "}",
        "main > h2 + ul li:last-child { border-bottom: none; }",
        "@media (min-width: 900px) {",
        "  body.index main {",
        "    display: grid; grid-template-columns: 1fr 1fr; gap: 1.5em 2em;",
        "  }",
        "  body.index main > h1 { grid-column: 1 / -1; }",
        "}",
        "@media (max-width: 520px) {",
        "  body { padding: 1em 0.8em 3em; font-size: 15px; }",
        "  h1 { font-size: 1.5em; }",
        "  pre { font-size: 0.82em; }",
        "}"
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
              "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
              "<title>Vault</title>",
              "<link rel=\"stylesheet\" href=\"style.css\">",
              "</head>",
              "<body class=\"index\">",
              "<main>",
              body_lines,
              "</main>",
              "</body>",
              "</html>"
    )
    writeLines(html, file.path(out_dir, "index.html"))
}

