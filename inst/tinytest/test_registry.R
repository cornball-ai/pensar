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

# --- 13. find_page() resolves path-style wikilinks ---
v13 <- file.path(tempdir(), paste0("reg-path-", format(Sys.time(), "%H%M%OS3")))
init_vault(v13, rproj = FALSE, agent_instructions = FALSE)
make_page(v13, "Notes/Foo.md", frontmatter = list(title = "Foo"))
expect_true(grepl("Notes/Foo\\.md$",
                  pensar:::find_page("Notes/Foo", v13)))
expect_true(grepl("Notes/Foo\\.md$",
                  pensar:::find_page("Notes/Foo.md", v13)))
unlink(v13, recursive = TRUE)

# --- 14. find_page() strips anchors and block IDs ---
v14 <- file.path(tempdir(), paste0("reg-anch-", format(Sys.time(), "%H%M%OS3")))
init_vault(v14, rproj = FALSE, agent_instructions = FALSE)
make_page(v14, "wiki/Foo.md", frontmatter = list(title = "Foo"))
expect_true(grepl("Foo\\.md$", pensar:::find_page("Foo#section", v14)))
expect_true(grepl("Foo\\.md$",
                  pensar:::find_page("Foo#^block-id", v14)))
unlink(v14, recursive = TRUE)

# --- 15. outlinks() existence resolves path-style links ---
v15 <- file.path(tempdir(), paste0("reg-out-", format(Sys.time(), "%H%M%OS3")))
init_vault(v15, rproj = FALSE, agent_instructions = FALSE)
make_page(v15, "Notes/Foo.md", frontmatter = list(title = "Foo"))
make_page(v15, "Notes/Bar.md", frontmatter = list(title = "Bar"),
          body = "Body cites [[Notes/Foo]] and [[ghost]].")
ol <- outlinks("Notes/Bar", vault = v15)
expect_true(ol$exists[ol$target == "Notes/Foo"])
expect_false(ol$exists[ol$target == "ghost"])
unlink(v15, recursive = TRUE)

# --- 16. Registry exposes `category` field ---
v16 <- file.path(tempdir(), paste0("reg-cat-", format(Sys.time(), "%H%M%OS3")))
init_vault(v16, rproj = FALSE, agent_instructions = FALSE)
make_page(v16, "wiki/Foo.md",
          frontmatter = list(title = "Foo", category = "concept"))
reg <- vault_registry(v16, cache = "none")
expect_true("category" %in% names(reg))
foo <- reg[reg$node_id == "Foo", ]
expect_equal(foo$category, "concept")
unlink(v16, recursive = TRUE)

# --- 17. Cache invalidates on rename (path+mtime+size signature) ---
v17 <- file.path(tempdir(), paste0("reg-ren-", format(Sys.time(), "%H%M%OS3")))
init_vault(v17, rproj = FALSE, agent_instructions = FALSE)
p_old <- make_page(v17, "wiki/A.md", frontmatter = list(title = "A"))
r1 <- vault_registry(v17, cache = "session")
expect_true("A" %in% r1$node_id)
# Rename A.md -> B.md (same content, same size, same mtime preserved)
p_new <- file.path(v17, "wiki/B.md")
file.rename(p_old, p_new)
r2 <- vault_registry(v17, cache = "session")
expect_false("A" %in% r2$node_id)
expect_true("B" %in% r2$node_id)
unlink(v17, recursive = TRUE)

# --- 18. backlinks() resolves path-style wikilinks ---
v18 <- file.path(tempdir(), paste0("reg-bl-path-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v18, rproj = FALSE, agent_instructions = FALSE)
make_page(v18, "Notes/Foo.md", frontmatter = list(title = "Foo"))
make_page(v18, "Notes/Bar.md", frontmatter = list(title = "Bar"),
          body = "Body cites [[Notes/Foo]].")
bl_by_basename <- backlinks("Foo", vault = v18)
bl_by_path <- backlinks("Notes/Foo", vault = v18)
expect_true("Bar" %in% bl_by_basename$source)
expect_true("Bar" %in% bl_by_path$source)
unlink(v18, recursive = TRUE)

# --- 19. lint() does not flag path-style links as broken, Foo not orphan ---
v19 <- file.path(tempdir(), paste0("reg-lint-path-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v19, rproj = FALSE, agent_instructions = FALSE)
make_page(v19, "Notes/Foo.md", frontmatter = list(title = "Foo"))
make_page(v19, "Notes/Bar.md", frontmatter = list(title = "Bar"),
          body = "Body cites [[Notes/Foo]].")
li <- lint(v19)
expect_false("Notes/Foo" %in% li$broken_links$link)
expect_false("Foo" %in% li$orphans)
unlink(v19, recursive = TRUE)

# --- 20. lint() tag clusters key raw pages by path so duplicate
#    basenames count separately ---
v20 <- file.path(tempdir(), paste0("reg-lint-tags-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v20, rproj = FALSE, agent_instructions = FALSE)
make_page(v20, "raw/articles/Foo.md",
          frontmatter = list(title = "Foo A", tags = c("topic-x")))
make_page(v20, "raw/chats/Foo.md",
          frontmatter = list(title = "Foo B", tags = c("topic-x")))
li <- lint(v20, min_cluster_size = 2L)
expect_true("topic-x" %in% li$suggested_clusters$tag)
unlink(v20, recursive = TRUE)

# --- 21. outlinks() surfaces ambiguity warnings to the caller ---
v21 <- file.path(tempdir(), paste0("reg-out-amb-",
                                   format(Sys.time(), "%H%M%OS3")))
init_vault(v21, rproj = FALSE, agent_instructions = FALSE)
make_page(v21, "A/Foo.md", frontmatter = list(title = "Foo A"))
make_page(v21, "B/Foo.md", frontmatter = list(title = "Foo B"))
make_page(v21, "wiki/Caller.md", frontmatter = list(title = "Caller"),
          body = "Cites [[Foo]].")
warns <- character(0L)
ol <- withCallingHandlers(outlinks("Caller", vault = v21),
                          warning = function(w) {
                              warns <<- c(warns, conditionMessage(w))
                              invokeRestart("muffleWarning")
                          })
expect_true(any(grepl("ambiguous wikilink", warns)))
expect_true(ol$exists[ol$target == "Foo"])
unlink(v21, recursive = TRUE)
