# Tests for query.R

library(pensar)

# Build a test vault with a small hierarchy:
# Deep Learning is_a Neural Networks is_a Machine Learning
vault <- tempfile("vault")
dir.create(vault)

writeLines(c(
  "---",
  "id: ONTO:0000001",
  "type: term",
  "---",
  "# Machine Learning"
), file.path(vault, "Machine Learning.md"))

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Neural Networks",
  "is_a:: [[Machine Learning]]"
), file.path(vault, "Neural Networks.md"))

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Deep Learning",
  "is_a:: [[Neural Networks]]"
), file.path(vault, "Deep Learning.md"))

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Random Forest",
  "is_a:: [[Machine Learning]]"
), file.path(vault, "Random Forest.md"))

index_vault(vault)

# --- Ancestors ---
anc <- query("Deep Learning", "is_a", "ancestors", vault_path = vault)
expect_true(nrow(anc) >= 2L)
expect_true("Neural Networks" %in% anc$name)
expect_true("Machine Learning" %in% anc$name)

# --- Descendants ---
desc <- query("Machine Learning", "is_a", "descendants", vault_path = vault)
expect_true(nrow(desc) >= 2L)
expect_true("Neural Networks" %in% desc$name)

# --- Siblings ---
sibs <- query("Neural Networks", "is_a", "siblings", vault_path = vault)
expect_true("Random Forest" %in% sibs$name)

# --- Error: unknown term ---
expect_error(query("Nonexistent", "is_a", "ancestors", vault_path = vault))

unlink(vault, recursive = TRUE)
