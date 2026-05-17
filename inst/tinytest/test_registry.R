# Tests for vault_registry() and registry-aware find_page() (PR 2).

library(pensar)

make_page <- function(vault, relpath, frontmatter = list(), body = "") {
    fp <- file.path(vault, relpath)
    dir.create(dirname(fp), recursive = TRUE, showWarnings = FALSE)
    fm_lines <- character(0L)
    if (length(frontmatter) > 0L) {
        fm_lines <- c("---", yaml::as.yaml(frontmatter), "---")
        # yaml::as.yaml ends with a newline; the trailing "---" sits on
        # its own line via writeLines.
    }
    writeLines(c(fm_lines, body), fp)
    fp
}

# --- 1. Empty vault → empty registry ---
v1 <- file.path(tempdir(), paste0("reg-empty-", format(Sys.time(), "%H%M%OS3")))
init_vault(v1, rproj = FALSE, agent_instructions = FALSE)
# Remove the seeded log/index/schema for a truly empty md scan? Actually
# they count as system_file but they're still pages. Test counts include them.
reg <- vault_registry(v1, cache = "none")
expect_true(is.data.frame(reg))
expect_true(all(c("path", "node_id", "page_uid", "title", "aliases",
                  "type", "tags", "sources", "links_out", "system_file")
                %in% names(reg)))
# Initial vault has 3 system files
sys_files <- reg$path[reg$system_file]
expect_true(all(c("schema.md", "log.md", "index.md") %in% sys_files))
unlink(v1, recursive = TRUE)

# --- 2. Pages with frontmatter id → page_uid populated ---
v2 <- file.path(tempdir(), paste0("reg-id-", format(Sys.time(), "%H%M%OS3")))
init_vault(v2, rproj = FALSE, agent_instructions = FALSE)
make_page(v2, "wiki/Foo.md",
          frontmatter = list(title = "Foo", id = "c-000001",
                             type = "concept",
                             aliases = c("FooAlias", "foo-alt"),
                             tags = c("topic", "demo")),
          body = "Body with [[Bar]] link.")
reg <- vault_registry(v2, cache = "none")
foo <- reg[reg$node_id == "Foo", ]
expect_equal(nrow(foo), 1L)
expect_equal(foo$page_uid, "c-000001")
expect_equal(foo$title, "Foo")
expect_equal(foo$type, "concept")
expect_equal(foo$aliases[[1L]], c("FooAlias", "foo-alt"))
expect_equal(foo$tags[[1L]], c("topic", "demo"))
expect_true("Bar" %in% foo$links_out[[1L]])
unlink(v2, recursive = TRUE)

# --- 3. Page without frontmatter id → page_uid is NA ---
v3 <- file.path(tempdir(), paste0("reg-noid-", format(Sys.time(), "%H%M%OS3")))
init_vault(v3, rproj = FALSE, agent_instructions = FALSE)
make_page(v3, "wiki/Bare.md",
          frontmatter = list(title = "Bare"),
          body = "No id here.")
reg <- vault_registry(v3, cache = "none")
bare <- reg[reg$node_id == "Bare", ]
expect_true(is.na(bare$page_uid))
unlink(v3, recursive = TRUE)

# --- 4. find_page() unique node_id ---
v4 <- file.path(tempdir(), paste0("reg-fp-uniq-", format(Sys.time(), "%H%M%OS3")))
init_vault(v4, rproj = FALSE, agent_instructions = FALSE)
make_page(v4, "wiki/Unique.md", frontmatter = list(title = "Unique"))
fp <- pensar:::find_page("Unique", v4)
expect_true(!is.null(fp))
expect_true(grepl("Unique\\.md$", fp))
unlink(v4, recursive = TRUE)

# --- 5. find_page() ambiguous basename → warn + first-sorted ---
v5 <- file.path(tempdir(), paste0("reg-fp-amb-", format(Sys.time(), "%H%M%OS3")))
init_vault(v5, rproj = FALSE, agent_instructions = FALSE)
make_page(v5, "wiki/dup.md", frontmatter = list(title = "Wiki Dup"))
make_page(v5, "raw/articles/dup.md", frontmatter = list(title = "Raw Dup"))
warns <- character(0L)
fp <- withCallingHandlers(pensar:::find_page("dup", v5),
                          warning = function(w) {
                              warns <<- c(warns, conditionMessage(w))
                              invokeRestart("muffleWarning")
                          })
expect_true(length(warns) > 0L)
expect_true(grepl("ambiguous", warns[1L]))
expect_true(grepl("raw/articles/dup\\.md", fp))
unlink(v5, recursive = TRUE)

# --- 6. find_page() page_uid resolution ---
v6 <- file.path(tempdir(), paste0("reg-fp-uid-", format(Sys.time(), "%H%M%OS3")))
init_vault(v6, rproj = FALSE, agent_instructions = FALSE)
make_page(v6, "wiki/Anything.md",
          frontmatter = list(title = "Anything", id = "c-042"))
fp <- pensar:::find_page("c-042", v6)
expect_true(!is.null(fp))
expect_true(grepl("Anything\\.md$", fp))
unlink(v6, recursive = TRUE)

# --- 7. find_page() alias resolution ---
v7 <- file.path(tempdir(), paste0("reg-fp-alias-", format(Sys.time(), "%H%M%OS3")))
init_vault(v7, rproj = FALSE, agent_instructions = FALSE)
make_page(v7, "wiki/Canonical.md",
          frontmatter = list(title = "Canonical",
                             aliases = c("nickname", "AKA")))
fp <- pensar:::find_page("nickname", v7)
expect_true(!is.null(fp))
expect_true(grepl("Canonical\\.md$", fp))
unlink(v7, recursive = TRUE)

# --- 8. find_page() exact path match wins ---
v8 <- file.path(tempdir(), paste0("reg-fp-path-", format(Sys.time(), "%H%M%OS3")))
init_vault(v8, rproj = FALSE, agent_instructions = FALSE)
make_page(v8, "wiki/Foo.md", frontmatter = list(title = "Foo"))
fp <- pensar:::find_page("wiki/Foo.md", v8)
expect_true(!is.null(fp))
expect_true(grepl("wiki/Foo\\.md$", fp))
unlink(v8, recursive = TRUE)

# --- 9. find_page() returns NULL on no match ---
v9 <- file.path(tempdir(), paste0("reg-fp-none-", format(Sys.time(), "%H%M%OS3")))
init_vault(v9, rproj = FALSE, agent_instructions = FALSE)
expect_null(pensar:::find_page("nonexistent", v9))
unlink(v9, recursive = TRUE)

# --- 10. Session cache: second call returns cached result fast ---
v10 <- file.path(tempdir(), paste0("reg-cache-", format(Sys.time(), "%H%M%OS3")))
init_vault(v10, rproj = FALSE, agent_instructions = FALSE)
make_page(v10, "wiki/A.md", frontmatter = list(title = "A"))
r1 <- vault_registry(v10, cache = "session")
r2 <- vault_registry(v10, cache = "session")
expect_identical(r1, r2)
# No file written inside .pensar/ for session cache
expect_false(dir.exists(file.path(v10, ".pensar")))
unlink(v10, recursive = TRUE)

# --- 11. cache = "none" never writes inside vault ---
v11 <- file.path(tempdir(), paste0("reg-cnone-", format(Sys.time(), "%H%M%OS3")))
init_vault(v11, rproj = FALSE, agent_instructions = FALSE)
make_page(v11, "wiki/A.md", frontmatter = list(title = "A"))
vault_registry(v11, cache = "none")
expect_false(dir.exists(file.path(v11, ".pensar")))
unlink(v11, recursive = TRUE)

# --- 12. Cache invalidates when an md file mtime changes ---
v12 <- file.path(tempdir(), paste0("reg-inv-", format(Sys.time(), "%H%M%OS3")))
init_vault(v12, rproj = FALSE, agent_instructions = FALSE)
p1 <- make_page(v12, "wiki/A.md", frontmatter = list(title = "A"))
r1 <- vault_registry(v12, cache = "session")
n1 <- nrow(r1)
# Add a new page; mtime set changes
Sys.sleep(1.1)  # ensure mtime granularity
make_page(v12, "wiki/B.md", frontmatter = list(title = "B"))
r2 <- vault_registry(v12, cache = "session")
expect_equal(nrow(r2), n1 + 1L)
unlink(v12, recursive = TRUE)
