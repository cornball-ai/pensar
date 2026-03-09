# Tests for promote.R

library(pensar)

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

index_vault(vault)

# --- Promote a term ---
new_id <- promote("Neural Networks", vault)
expect_true(grepl("^ONTO:", new_id))
expect_equal(new_id, "ONTO:0000002")

# Check the file was updated
lines <- readLines(file.path(vault, "Neural Networks.md"))
expect_true(any(grepl("^id: ONTO:0000002", lines)))

# Check the index was updated
idx <- pensar:::load_index(vault)
row <- idx$terms[idx$terms$name == "Neural Networks", ]
expect_equal(row$id, "ONTO:0000002")
expect_equal(row$promoted, 1L)

# --- Already promoted ---
expect_message(promote("Neural Networks", vault), "already promoted")

# --- Unknown term ---
expect_error(promote("Nonexistent", vault))

unlink(vault, recursive = TRUE)
