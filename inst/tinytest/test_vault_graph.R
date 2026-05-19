# Tests for vault_graph.R

library(pensar)

# These tests don't need saber, only the internal helper.
# Windows-style paths with backslashes must not blow up the prefix
# strip. The previous implementation built a regex from `vault`; on
# Windows that produced "Invalid back reference" errors during
# R CMD check on win-builder.
expect_equal(
    pensar:::category_from_path(
        "D:\\tmp\\vault\\raw\\articles\\foo.md",
        "D:\\tmp\\vault"),
    "articles")
expect_equal(
    pensar:::category_from_path(
        "D:\\tmp\\vault\\wiki\\Concept.md",
        "D:\\tmp\\vault"),
    "wiki")
expect_equal(
    pensar:::category_from_path("/tmp/vault/raw/chats/x.md",
                                "/tmp/vault"),
    "chats")

if (!requireNamespace("saber", quietly = TRUE)) {
    exit_file("saber not installed")
}

# Empty vault errors cleanly. This test doesn't need graph_svg
# (vault_graph errors before reaching the renderer); sits between
# the saber-installed gate and the graph_svg gate so it runs on
# every machine with saber, including ones whose saber is older
# than the one shipping graph_svg(). The bug it guards against is
# the path-separator mismatch on Windows that lets control files
# slip through the "No pages in vault" guard.
empty <- file.path(tempdir(), paste0("empty-vault-",
                                     format(Sys.time(), "%H%M%S")))
init_vault(empty, agent_instructions = FALSE, rproj = FALSE)
expect_error(vault_graph(vault = empty), "No pages in vault")

if (!"graph_svg" %in% getNamespaceExports("saber")) {
    exit_file("installed saber lacks graph_svg(); skipping")
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

