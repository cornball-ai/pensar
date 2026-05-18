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

# --- 6. autoresearch ships with the MIT NOTICE for claude-obsidian ---
# Attribution lives in NOTICE.md next to SKILL.md. Test guards against
# accidentally dropping it in a future skill rewrite.
notice_path <- file.path(ar_dir, "NOTICE.md")
expect_true(file.exists(notice_path))
notice <- readLines(notice_path, warn = FALSE)
expect_true(any(grepl("MIT License", notice)))
expect_true(any(grepl("AgriciDaniel", notice)))
# SKILL.md surfaces the acknowledgment so readers see it without
# digging for a separate file.
skill_lines <- readLines(file.path(ar_dir, "SKILL.md"), warn = FALSE)
expect_true(any(grepl("claude-obsidian", skill_lines)))
