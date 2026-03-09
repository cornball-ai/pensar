# Tests for startup.R

library(pensar)

# --- Setup: fake home directory with projects ---

fake_home <- tempfile("home")
dir.create(fake_home)

# Project 1: R package with CLAUDE.md, fyi.md, and DESCRIPTION
proj1 <- file.path(fake_home, "mypackage")
dir.create(proj1)
writeLines(c(
  "# mypackage",
  "",
  "An R package for doing things.",
  "is_a:: [[r_package]]"
), file.path(proj1, "CLAUDE.md"))

writeLines(c(
  "# mypackage internals",
  "",
  "Exports: foo, bar, baz"
), file.path(proj1, "fyi.md"))

writeLines(c(
  "Package: mypackage",
  "Version: 0.1.0",
  "Title: My Package",
  "Depends: R (>= 4.0), methods",
  "Imports: RSQLite, yaml",
  "Suggests: tinytest",
  "LinkingTo: Rcpp"
), file.path(proj1, "DESCRIPTION"))

# Project 2: has CLAUDE.md and DESCRIPTION
proj2 <- file.path(fake_home, "otherapp")
dir.create(proj2)
writeLines(c(
  "# otherapp",
  "",
  "A downstream app."
), file.path(proj2, "CLAUDE.md"))

writeLines(c(
  "Package: otherapp",
  "Version: 0.1.0",
  "Title: Other App",
  "Imports: mypackage, jsonlite"
), file.path(proj2, "DESCRIPTION"))

# Project 3: has CLAUDE.md
proj3 <- file.path(fake_home, "agentproject")
dir.create(proj3)
writeLines(c(
  "# agentproject",
  "An agent project."
), file.path(proj3, "CLAUDE.md"))

# Project 4: AGENT.md only (no DESCRIPTION)
proj4 <- file.path(fake_home, "simpleproject")
dir.create(proj4)
writeLines(c(
  "# simpleproject",
  "A non-R project."
), file.path(proj4, "AGENT.md"))

# Project 5: README.md only
proj5 <- file.path(fake_home, "readmeonly")
dir.create(proj5)
writeLines(c(
  "# readmeonly",
  "",
  "A project with just a README."
), file.path(proj5, "README.md"))

# Directory with no metadata (should be skipped)
dir.create(file.path(fake_home, "nofiles"))

# Fake Claude Code memory directory
fake_claude <- file.path(fake_home, ".claude", "projects",
                         "-home-fakeuser-mypackage", "memory")
dir.create(fake_claude, recursive = TRUE)
writeLines(c(
  "# Memory for mypackage",
  "",
  "Key insight: uses RSQLite for everything."
), file.path(fake_claude, "MEMORY.md"))

# --- Test startup ---

cache_dir <- tempfile("cache")
claude_dir <- file.path(cache_dir, "claude")

st <- startup(scan_dir = fake_home,
              cache_dir = file.path(cache_dir, "pensar"),
              claude_dir = claude_dir,
              memory_dir = file.path(fake_home, ".claude", "projects"))

# Status should be returned
expect_true(inherits(st, "pensar_status"))

# Index directory should exist
idx_dir <- file.path(cache_dir, "pensar", "index", ".pensar")
expect_true(dir.exists(idx_dir))

# --- Auto-term registration ---
idx <- pensar:::load_index(file.path(cache_dir, "pensar", "index"))

# All 5 projects should be terms
expect_true("mypackage" %in% idx$terms$name)
expect_true("otherapp" %in% idx$terms$name)
expect_true("agentproject" %in% idx$terms$name)
expect_true("simpleproject" %in% idx$terms$name)
expect_true("readmeonly" %in% idx$terms$name)

# --- Typed links from CLAUDE.md parsed in place ---
inline_rels <- idx$relations[idx$relations$source == "inline", , drop = FALSE]
expect_true(any(inline_rels$subject_id == "mypackage" &
                inline_rels$relation_type == "is_a" &
                inline_rels$object_id == "r_package"))

# --- DESCRIPTION dependency relations ---
auto_rels <- idx$relations[idx$relations$source == "auto", , drop = FALSE]

# mypackage imports RSQLite and yaml
mp_deps <- auto_rels[auto_rels$subject_id == "mypackage", ]
expect_true("RSQLite" %in% mp_deps$object_id)
expect_true("yaml" %in% mp_deps$object_id)
mp_imports <- mp_deps[mp_deps$relation_type == "imports", ]
expect_true("RSQLite" %in% mp_imports$object_id)
expect_true("yaml" %in% mp_imports$object_id)

# mypackage suggests tinytest
mp_suggests <- mp_deps[mp_deps$relation_type == "suggests", ]
expect_true("tinytest" %in% mp_suggests$object_id)

# mypackage depends on methods (R filtered out)
mp_depends <- mp_deps[mp_deps$relation_type == "depends", ]
expect_true("methods" %in% mp_depends$object_id)
expect_false("R" %in% mp_depends$object_id)

# mypackage links_to Rcpp
mp_linksto <- mp_deps[mp_deps$relation_type == "links_to", ]
expect_true("Rcpp" %in% mp_linksto$object_id)

# otherapp imports mypackage and jsonlite
oa_deps <- auto_rels[auto_rels$subject_id == "otherapp", ]
expect_true("mypackage" %in% oa_deps$object_id)
expect_true("jsonlite" %in% oa_deps$object_id)
expect_true(all(oa_deps$relation_type == "imports"))

# --- No staging vault created ---
expect_false(dir.exists(file.path(cache_dir, "pensar", "vault")))

# --- Claude instructions (only if informR is installed) ---
if (requireNamespace("informR", quietly = TRUE)) {
    instructions_md <- file.path(cache_dir, "pensar", "instructions.md")
    expect_true(file.exists(instructions_md))
}

# Should NOT write directly to claude_dir
expect_false(file.exists(file.path(claude_dir, "CLAUDE.md")))

# --- Test with empty directory ---
empty_dir <- tempfile("empty")
dir.create(empty_dir)
result <- startup(scan_dir = empty_dir,
                  cache_dir = tempfile("emptycache"),
                  claude_dir = NULL,
                  memory_dir = NULL)
expect_true(is.null(result))

# --- Cleanup ---
unlink(c(fake_home, cache_dir, empty_dir), recursive = TRUE)
