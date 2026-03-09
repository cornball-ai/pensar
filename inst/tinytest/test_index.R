# Tests for index.R

library(pensar)

# Create a temp vault
vault <- tempfile("vault")
dir.create(vault)

# Write some test files
writeLines(c(
  "---",
  "id: ONTO:0000001",
  "type: term",
  "aliases:",
  "  - ML",
  "---",
  "# Machine Learning",
  "A field of study."
), file.path(vault, "Machine Learning.md"))

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Neural Networks",
  "is_a:: [[Machine Learning]]",
  "Some content about NNs."
), file.path(vault, "Neural Networks.md"))

writeLines(c(
  "# Just a note",
  "This is not a term.",
  "It links to [[Machine Learning]] though."
), file.path(vault, "Random Note.md"))

# --- index_vault ---

idx_dir <- index_vault(vault)
expect_true(dir.exists(idx_dir))

idx <- pensar:::load_index(vault)

# Check terms were created
expect_true(nrow(idx$terms) >= 2L)
expect_true("Machine Learning" %in% idx$terms$name)
expect_true("Neural Networks" %in% idx$terms$name)

# ML should be promoted (has id:)
ml <- idx$terms[idx$terms$name == "Machine Learning", ]
expect_equal(ml$promoted, 1L)
expect_equal(ml$id, "ONTO:0000001")

# NN should not be promoted
nn <- idx$terms[idx$terms$name == "Neural Networks", ]
expect_equal(nn$promoted, 0L)

# Check relations
expect_true(nrow(idx$relations) >= 1L)
isa <- idx$relations[idx$relations$relation_type == "is_a", ]
expect_true(nrow(isa) >= 1L)

# Check files tracking
expect_true(nrow(idx$files) >= 2L)

# --- Incremental re-index (no changes) ---
idx_dir2 <- index_vault(vault)
expect_equal(idx_dir, idx_dir2)

# --- Re-index after change ---
writeLines(c(
  "---",
  "type: term",
  "---",
  "# Deep Learning",
  "is_a:: [[Neural Networks]]"
), file.path(vault, "Deep Learning.md"))

index_vault(vault)
idx2 <- pensar:::load_index(vault)
expect_true("Deep Learning" %in% idx2$terms$name)

unlink(vault, recursive = TRUE)
