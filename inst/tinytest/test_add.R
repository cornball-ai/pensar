# Tests for add.R

library(pensar)

# --- Setup: create a vault with one term ---

vault <- tempfile("vault")
dir.create(vault)

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Existing Term"
), file.path(vault, "Existing Term.md"))

index_vault(vault)

annotations_dir <- tempfile("annotations")

# --- Test adding terms ---

res <- add(
  terms = c("alpha", "beta", "gamma"),
  vault_path = vault,
  annotations_dir = annotations_dir
)

expect_equal(res$terms, 3L)
expect_equal(res$relations, 0L)

# Verify in index
idx <- pensar:::load_index(vault)
expect_true("alpha" %in% idx$terms$id)
expect_true("beta" %in% idx$terms$id)
expect_true("gamma" %in% idx$terms$id)

# --- Test adding relations ---

rels_df <- data.frame(
  subject = c("alpha", "beta"),
  relation_type = c("is_a", "uses"),
  object = c("gamma", "alpha"),
  stringsAsFactors = FALSE
)

res2 <- add(
  relations = rels_df,
  vault_path = vault,
  annotations_dir = annotations_dir
)

expect_equal(res2$relations, 2L)

idx <- pensar:::load_index(vault)
manual_rels <- idx$relations[idx$relations$source == "manual", , drop = FALSE]
expect_equal(nrow(manual_rels), 2L)
expect_true(all(manual_rels$confirmed == 1L))

# alpha is_a gamma
expect_true(any(manual_rels$subject_id == "alpha" &
                manual_rels$relation_type == "is_a" &
                manual_rels$object_id == "gamma"))
# beta uses alpha
expect_true(any(manual_rels$subject_id == "beta" &
                manual_rels$relation_type == "uses" &
                manual_rels$object_id == "alpha"))

# --- Test annotation file written ---

ann_files <- list.files(annotations_dir, pattern = "\\.md$")
expect_true(length(ann_files) >= 1L)

# --- Test duplicate inserts are ignored ---

res3 <- add(
  terms = c("alpha", "new_term"),
  relations = rels_df,
  vault_path = vault,
  annotations_dir = annotations_dir
)

# alpha already exists, only new_term is new
expect_equal(res3$terms, 1L)
# relations already exist
expect_equal(res3$relations, 0L)

# --- Test bad relations input ---

expect_error(
  add(relations = data.frame(a = 1, b = 2), vault_path = vault,
          annotations_dir = NULL),
  "subject, relation_type, object"
)

# --- Cleanup ---
unlink(c(vault, annotations_dir), recursive = TRUE)
