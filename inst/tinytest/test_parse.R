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
  "Also [[Alpha]] again.",
  "Alias links target [[Delta|display text]].",
  "Pipes after the first stay in the label [[Epsilon|display | text]]."
), tmp4)

wl <- pensar:::parse_wikilinks(tmp4)
expect_true("Alpha" %in% wl)
expect_true("Beta" %in% wl)
expect_true("Gamma" %in% wl)
expect_true("Delta" %in% wl)
expect_true("Epsilon" %in% wl)
expect_false("display text" %in% wl)

parsed <- pensar:::parse_wikilink("[[Delta|display text]]")
expect_equal(parsed$target, "Delta")
expect_equal(parsed$label, "display text")

# Code regions are not scanned: R's [[ ]] indexing is not a wikilink.
tmp5 <- tempfile(fileext = ".md")
writeLines(c(
  "Real link [[Alpha]] in prose.",
  "Inline code `merged[[name]] <- project[[name]]` is not a link.",
  "```r",
  "x <- registry[[uuid]]",
  "y <- [[Beta]]",
  "```",
  "After the fence [[Gamma]] counts again."
), tmp5)

wl2 <- pensar:::parse_wikilinks(tmp5)
expect_true("Alpha" %in% wl2)
expect_true("Gamma" %in% wl2)
expect_false("name" %in% wl2)
expect_false("uuid" %in% wl2)
expect_false("Beta" %in% wl2)
unlink(tmp5)

# --- name_from_path ---
expect_equal(pensar:::name_from_path("/vault/Neural Networks.md"), "Neural Networks")

unlink(c(tmp, tmp2, tmp4))
