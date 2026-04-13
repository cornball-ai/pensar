# Tests for parse.R

library(pensar)

# --- parse_frontmatter ---

# Happy path: standard frontmatter
tmp <- tempfile(fileext = ".md")
writeLines(c(
  "---",
  "id: ONTO:0000001",
  "type: term",
  "aliases:",
  "  - NN",
  "  - ANN",
  "---",
  "# Neural Networks",
  "Some content."
), tmp)

fm <- pensar:::parse_frontmatter(tmp)
expect_equal(fm$id, "ONTO:0000001")
expect_equal(fm$type, "term")
expect_equal(fm$aliases, c("NN", "ANN"))

# Edge case: no frontmatter
tmp2 <- tempfile(fileext = ".md")
writeLines(c("# Just a heading", "No frontmatter here."), tmp2)
fm2 <- pensar:::parse_frontmatter(tmp2)
expect_equal(fm2, list())

# --- parse_wikilinks ---

tmp4 <- tempfile(fileext = ".md")
writeLines(c(
  "This links to [[Alpha]] and [[Beta]].",
  "is_a:: [[Gamma]]",
  "Also [[Alpha]] again."
), tmp4)

wl <- pensar:::parse_wikilinks(tmp4)
expect_true("Alpha" %in% wl)
expect_true("Beta" %in% wl)
expect_true("Gamma" %in% wl)

# --- name_from_path ---
expect_equal(pensar:::name_from_path("/vault/Neural Networks.md"), "Neural Networks")

unlink(c(tmp, tmp2, tmp4))
