# Tests for outlinks.R

library(pensar)

tmp <- file.path(tempdir(), paste0("vault-", format(Sys.time(), "%H%M%S")))
init_vault(tmp)

writeLines(c("---", "title: A", "---",
             "Links to [[B]] and [[C]] and [[missing]]."),
           file.path(tmp, "wiki", "A.md"))
writeLines(c("---", "title: B", "---", "No links."),
           file.path(tmp, "wiki", "B.md"))
writeLines(c("---", "title: C", "---", "No links."),
           file.path(tmp, "wiki", "C.md"))

# --- Outlinks from A ---
ol <- outlinks("A", vault = tmp)
expect_true(is.data.frame(ol))
expect_true(all(c("B", "C", "missing") %in% ol$target))

# --- Existence flags ---
expect_true(ol$exists[ol$target == "B"])
expect_true(ol$exists[ol$target == "C"])
expect_false(ol$exists[ol$target == "missing"])

# --- No outlinks ---
ol2 <- outlinks("B", vault = tmp)
expect_equal(nrow(ol2), 0L)

# --- Missing page error ---
expect_error(outlinks("nonexistent", vault = tmp))

unlink(tmp, recursive = TRUE)
