# Tests for ingest_agent_context() (PR 9).

library(pensar)

# --- 1. Missing saber → clear stop message ---
# Use a mock environment to simulate saber not being installed.
if (!requireNamespace("saber", quietly = TRUE)) {
    v_no_saber <- file.path(tempdir(),
                            paste0("iac-nosaber-",
                                   format(Sys.time(), "%H%M%OS3")))
    init_vault(v_no_saber, rproj = FALSE, agent_instructions = FALSE)
    err <- tryCatch(ingest_agent_context("claude", vault = v_no_saber),
                    error = function(e) conditionMessage(e))
    expect_true(grepl("requires the 'saber' package", err))
    unlink(v_no_saber, recursive = TRUE)
}

# Remaining tests need saber installed.
if (!requireNamespace("saber", quietly = TRUE)) {
    exit_file("saber not installed; skipping rest of test_ingest_agent_context")
}

# --- 2. Fixture project with CLAUDE.md → writes raw/chats/ page ---
v2 <- file.path(tempdir(), paste0("iac-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v2, rproj = FALSE, agent_instructions = FALSE)
proj <- file.path(tempdir(), paste0("iac-proj-",
                                    format(Sys.time(), "%H%M%OS3")))
dir.create(proj)
writeLines(c("# Project agents",
             "",
             "Use snake_case for new variable names."),
           file.path(proj, "AGENTS.md"))
rel <- ingest_agent_context("claude", vault = v2, project_dir = proj)
expect_true(is.character(rel) && nzchar(rel))
expect_true(grepl("^raw/chats/", rel))
expect_true(file.exists(file.path(v2, rel)))
# Frontmatter
fm <- pensar:::parse_frontmatter(file.path(v2, rel))
expect_equal(fm$type, "chats")
expect_equal(fm$source, "saber::agent_context(claude)")
expect_true("agent-context" %in% fm$tags)
expect_true("claude" %in% fm$tags)
# Body contains the AGENTS.md content
body_lines <- readLines(file.path(v2, rel), warn = FALSE)
expect_true(any(grepl("snake_case", body_lines)))
# Manifest recorded it
m <- read_manifest(v2)
expect_true(rel %in% names(m$sources))
expect_equal(m$sources[[rel]]$source,
             "saber::agent_context(claude)")
unlink(v2, recursive = TRUE)
unlink(proj, recursive = TRUE)

# --- 3. Empty context (no source files) → message, no write ---
v3 <- file.path(tempdir(), paste0("iac-empty-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v3, rproj = FALSE, agent_instructions = FALSE)
empty_proj <- file.path(tempdir(),
                        paste0("iac-empty-proj-",
                               format(Sys.time(), "%H%M%OS3")))
dir.create(empty_proj)
# Point at an empty memory base + isolated claude global path so
# saber finds nothing.
result <- ingest_agent_context(
    "claude", vault = v3, project_dir = empty_proj,
    memory_base = file.path(tempdir(), "iac-no-memory"),
    claude_global_path = file.path(tempdir(),
                                   "iac-no-claude-global.md"))
expect_null(result)
chats_dir <- file.path(v3, "raw", "chats")
chats_pages <- list.files(chats_dir, pattern = "\\.md$")
expect_equal(length(chats_pages), 0L)
unlink(v3, recursive = TRUE)
unlink(empty_proj, recursive = TRUE)

# --- 4. agent argument is validated ---
v4 <- file.path(tempdir(), paste0("iac-bad-agent-",
                                  format(Sys.time(), "%H%M%OS3")))
init_vault(v4, rproj = FALSE, agent_instructions = FALSE)
err <- tryCatch(ingest_agent_context("not-an-agent", vault = v4),
                error = function(e) conditionMessage(e))
expect_true(grepl("should be one of", err))
unlink(v4, recursive = TRUE)
