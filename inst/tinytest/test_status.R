# Tests for status.R

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

st <- status(vault_path = vault)
expect_true(inherits(st, "pensar_status"))
expect_true(st$terms >= 2L)
expect_true(st$promoted >= 1L)
expect_true(st$relations >= 1L)

unlink(vault, recursive = TRUE)
