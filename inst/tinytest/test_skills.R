# Tests for the bundled skills (PR 7).

library(pensar)

# --- 1. pensar_skill_path() returns the bundle root ---
base <- pensar_skill_path()
expect_true(nzchar(base))
expect_true(dir.exists(base))

# --- 2. autoresearch skill is shipped ---
ar_dir <- pensar_skill_path("autoresearch")
expect_true(dir.exists(ar_dir))
expect_true(file.exists(file.path(ar_dir, "SKILL.md")))
expect_true(file.exists(file.path(ar_dir, "references",
                                  "program.md")))

# --- 3. SKILL.md frontmatter parses and exposes name/description ---
fm <- pensar:::parse_frontmatter(file.path(ar_dir, "SKILL.md"))
expect_equal(fm$name, "autoresearch")
expect_true(nzchar(fm$description))

# --- 4. program.md is readable and non-empty ---
prog_lines <- readLines(file.path(ar_dir, "references", "program.md"),
                        warn = FALSE)
expect_true(length(prog_lines) > 0L)
expect_true(any(grepl("Loop constraints", prog_lines)))

# --- 5. pensar_skill_path() with a bogus name returns "" ---
# Matches system.file() convention so callers can test with nzchar().
expect_equal(pensar_skill_path("does-not-exist"), "")
