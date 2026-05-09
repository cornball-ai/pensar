# Tests for ingest_repo.R and migrate.R

library(pensar)

# --- Setup: a vault and a fixture repo ---
tmp <- file.path(tempdir(), paste0("vault-repo-",
                                   format(Sys.time(), "%H%M%S")))
init_vault(tmp, rproj = FALSE, agent_instructions = FALSE)

# Build a minimal git repo with an R package skeleton.
repo <- file.path(tempdir(), paste0("fixturepkg-",
                                    format(Sys.time(), "%H%M%S")))
dir.create(file.path(repo, "R"), recursive = TRUE)
writeLines(c("Package: fixturepkg", "Title: Fixture", "Version: 0.1.0",
             "Authors@R: person('Test', 'User', email = 'a@b.c',",
             "                  role = c('aut', 'cre'))",
             "Description: Fixture package for tests.",
             "License: Apache License (>= 2)", "Encoding: UTF-8"),
           file.path(repo, "DESCRIPTION"))
writeLines("hello <- function() 'hi'", file.path(repo, "R", "hello.R"))

# Init the repo and make one commit so HEAD resolves.
in_repo <- function(...) {
    system2("git", c("-C", repo, ...), stdout = TRUE, stderr = TRUE)
}
in_repo("init", "-q")
in_repo("config", "user.email", "test@example.com")
in_repo("config", "user.name", "TestUser")
in_repo("config", "commit.gpgsign", "false")
in_repo("add", "-A")
in_repo("commit", "-q", "-minit")

# --- ingest_repo: snapshot only (no saber needed) ---
written <- ingest_repo(repo, name = "fixturepkg",
                       enrich = "none", artifacts = "snapshot",
                       vault = tmp)
expect_true(length(written) == 1L)
expect_true(file.exists(file.path(tmp, "raw", "repos", "fixturepkg",
                                  "snapshot.md")))

fm <- pensar:::parse_frontmatter(file.path(tmp, "raw", "repos", "fixturepkg",
                                           "snapshot.md"))
expect_equal(fm$type, "repo-snapshot")
expect_equal(fm$repo$name, "fixturepkg")
expect_true(nzchar(fm$repo$commit))
expect_true(nchar(fm$repo$commit_short) == 7L)

# --- Path-aware name_from_path ---
expect_equal(pensar:::name_from_path(
                file.path(tmp, "raw", "repos", "fixturepkg", "snapshot.md")),
             "fixturepkg/snapshot")
expect_equal(pensar:::name_from_path(
                file.path(tmp, "raw", "articles", "2026-01-01-foo.md")),
             "2026-01-01-foo")

# --- Index picks up the new Raw: Repos category ---
idx <- readLines(file.path(tmp, "index.md"))
expect_true(any(grepl("Raw: Repos", idx)))
expect_true(any(grepl("\\[\\[fixturepkg/snapshot\\]\\]", idx)))

# --- ingest_briefing emits a deprecation warning ---
expect_warning(
    suppressMessages(ingest_briefing(project = "fixturepkg",
                                     scan_dir = dirname(repo),
                                     vault = tmp)),
    "deprecated"
)

# --- Migration: dry run on a fixture briefings dir ---
tmp2 <- file.path(tempdir(), paste0("vault-mig-",
                                    format(Sys.time(), "%H%M%S")))
init_vault(tmp2, rproj = FALSE, agent_instructions = FALSE)
br <- file.path(tmp2, "raw", "briefings")
dir.create(br, recursive = TRUE, showWarnings = FALSE)

mk_briefing <- function(name, date, body = "stub") {
    fp <- file.path(br, paste0(date, "-", name, ".md"))
    writeLines(c("---",
                 sprintf("title: 'Briefing: %s'", name),
                 "type: briefings",
                 sprintf("source: %s", name),
                 sprintf("date: '%s'", date),
                 "---",
                 "",
                 body),
               fp)
    fp
}
mk_briefing("llamar", "2026-04-13")            # -> corteza/briefing (older)
mk_briefing("corteza", "2026-04-30")           # -> corteza/briefing (newer; wins)
mk_briefing("ast-llamar", "2026-04-13")        # -> corteza/ast
mk_briefing("saber-2", "2026-04-13")           # -> saber-2/briefing (no rename)
mk_briefing("saber", "2026-04-18")             # different repo "saber" newer

# Wiki link rewrite target
dir.create(file.path(tmp2, "wiki"), showWarnings = FALSE)
writeLines(c("---", "title: Test", "type: concept", "---",
             "", "See [[2026-04-30-corteza]] and",
             "[[2026-04-13-ast-llamar|llamar AST]]."),
           file.path(tmp2, "wiki", "test-page.md"))

plan <- migrate_briefings_to_repos(tmp2, dry_run = TRUE)
expect_equal(sum(plan$action == "move"), 4L)  # corteza, corteza/ast, saber, saber-2
expect_true(any(plan$repo == "corteza" & plan$action == "move"))
# llamar -> corteza/briefing should NOT be the winner; corteza (later date) wins
llamar_row <- plan[basename(plan$file) == "2026-04-13-llamar.md", ]
expect_equal(llamar_row$action, "drop")

# Apply for real
suppressMessages(
    plan2 <- migrate_briefings_to_repos(tmp2, dry_run = FALSE,
                                        drop_old = TRUE)
)
expect_true(file.exists(file.path(tmp2, "raw", "repos", "corteza",
                                  "briefing.md")))
expect_true(file.exists(file.path(tmp2, "raw", "repos", "corteza",
                                  "ast.md")))
# Originals removed (drop_old = TRUE)
expect_false(file.exists(file.path(br, "2026-04-13-llamar.md")))
expect_false(file.exists(file.path(br, "2026-04-30-corteza.md")))
# Type field rewritten on the moved file
fm_moved <- pensar:::parse_frontmatter(
    file.path(tmp2, "raw", "repos", "corteza", "briefing.md"))
expect_equal(fm_moved$type, "repo-briefing")
# Wiki link was rewritten
wt <- readLines(file.path(tmp2, "wiki", "test-page.md"))
expect_true(any(grepl("\\[\\[corteza/briefing\\]\\]", wt)))
expect_true(any(grepl("\\[\\[corteza/ast\\|llamar AST\\]\\]", wt)))

unlink(tmp, recursive = TRUE)
unlink(tmp2, recursive = TRUE)
unlink(repo, recursive = TRUE)
