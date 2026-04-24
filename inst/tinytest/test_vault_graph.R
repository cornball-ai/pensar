# Tests for vault_graph.R

library(pensar)

if (!requireNamespace("saber", quietly = TRUE)) {
    exit_file("saber not installed")
}
if (packageVersion("saber") < "0.6.0") {
    exit_file("needs saber >= 0.6.0 for graph_svg()")
}

tmp <- file.path(tempdir(), paste0("vault-graph-",
                                   format(Sys.time(), "%H%M%S")))
init_vault(tmp)

# Ingest two pages that link to each other + one broken link
ingest("Discusses [[Beta]] and [[Missing]].", type = "articles",
       source = "alpha-src", title = "Alpha",
       tags = c("R", "intro"), vault = tmp)
ingest("References back to [[Alpha]].", type = "articles",
       source = "beta-src", title = "Beta", vault = tmp)

svg <- vault_graph(vault = tmp)
expect_true(is.character(svg))
expect_true(any(grepl("^<svg", svg)))

# Node present for each ingested page (slugified by ingest())
expect_true(any(grepl("type: articles", svg, fixed = TRUE)))

# Broken wikilink appears as a node with "(broken wikilink)" tooltip
expect_true(any(grepl("(broken wikilink)", svg, fixed = TRUE)))
expect_true(any(grepl("Missing", svg, fixed = TRUE)))

# Empty vault errors cleanly
empty <- file.path(tempdir(), paste0("empty-vault-",
                                     format(Sys.time(), "%H%M%S")))
init_vault(empty, agent_instructions = FALSE, rproj = FALSE)
# Remove the only seeded content so there are no pages (schema/index/log
# are filtered as control files).
# init_vault leaves schema/index/log only, which the function filters out.
expect_error(vault_graph(vault = empty), "No pages in vault")
