# Tests for graph.R

library(pensar)

# --- Setup: build a small index ---

vault <- tempfile("vault")
dir.create(vault, recursive = TRUE)
idx <- pensar:::empty_index()

# 4 terms: A imports B and C, B suggests C, D links_to A
idx$terms <- data.frame(
    id = c("A", "B", "C", "D"),
    name = c("A", "B", "C", "D"),
    filepath = NA_character_,
    aliases = "", promoted = 0L,
    updated_at = pensar:::now_ts(),
    stringsAsFactors = FALSE
)

idx$relations <- data.frame(
    subject_id = c("A", "A", "B", "D"),
    relation_type = c("imports", "imports", "suggests", "links_to"),
    object_id = c("B", "C", "C", "A"),
    confirmed = 1L,
    source = "auto",
    stringsAsFactors = FALSE
)

pensar:::save_index(idx, vault)

# --- adjacency: basic ---

mat <- adjacency(vault_path = vault)
expect_true(is.matrix(mat))
expect_equal(nrow(mat), 4L)
expect_equal(ncol(mat), 4L)
expect_true(all(c("A", "B", "C", "D") %in% rownames(mat)))

# A -> B is imports (weight 1.0)
expect_equal(mat["A", "B"], 1.0)
# B -> C is suggests (weight 0.3)
expect_equal(mat["B", "C"], 0.3)
# D -> A is links_to (weight 0.8)
expect_equal(mat["D", "A"], 0.8)

# --- adjacency: symmetric ---
# symmetric=TRUE: mat[i,j] == mat[j,i]
expect_equal(mat["B", "A"], mat["A", "B"])
expect_equal(mat["A", "D"], mat["D", "A"])

# --- adjacency: asymmetric ---

mat_asym <- adjacency(vault_path = vault, symmetric = FALSE)
expect_equal(mat_asym["A", "B"], 1.0)
# No reverse relation from B to A
expect_equal(mat_asym["B", "A"], 0)

# --- adjacency: empty index ---

empty_vault <- tempfile("empty_vault")
dir.create(empty_vault, recursive = TRUE)
pensar:::save_index(pensar:::empty_index(), empty_vault)
mat_empty <- adjacency(vault_path = empty_vault)
expect_equal(nrow(mat_empty), 0L)

# --- clusters: basic ---

cl <- clusters(vault_path = vault, k = 2L)
expect_true(is.data.frame(cl))
expect_equal(sort(cl$term), c("A", "B", "C", "D"))
expect_equal(ncol(cl), 2L)
expect_true(all(c("term", "cluster") %in% names(cl)))
expect_true(all(cl$cluster %in% 1:2))

# --- clusters: auto-k ---

cl_auto <- clusters(vault_path = vault)
expect_true(is.data.frame(cl_auto))
expect_true(max(cl_auto$cluster) >= 1L)

# --- clusters: single term ---

single_vault <- tempfile("single")
dir.create(single_vault, recursive = TRUE)
single_idx <- pensar:::empty_index()
single_idx$terms <- data.frame(
    id = "X", name = "X", filepath = NA_character_,
    aliases = "", promoted = 0L, updated_at = pensar:::now_ts(),
    stringsAsFactors = FALSE
)
single_idx$relations <- data.frame(
    subject_id = "X", relation_type = "imports", object_id = "X",
    confirmed = 1L, source = "auto", stringsAsFactors = FALSE
)
pensar:::save_index(single_idx, single_vault)
cl_single <- clusters(vault_path = single_vault, k = 1L)
expect_equal(nrow(cl_single), 1L)
expect_equal(cl_single$cluster, 1L)

# --- Cleanup ---
unlink(c(vault, empty_vault, single_vault), recursive = TRUE)
