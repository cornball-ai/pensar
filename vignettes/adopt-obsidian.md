<!--
%\VignetteEngine{simplermarkdown::mdweave_to_html}
%\VignetteIndexEntry{Adopt an existing Obsidian vault}
-->
---
title: Adopt an existing Obsidian vault
---

# Adopt an existing Obsidian vault

`init_vault(path, adopt = TRUE)` lets pensar attach to an existing
Obsidian vault without rewriting its layout. Adoption is **in place**:
pensar adds three small files (`schema.md`, `index.md`, `log.md`) to
the path you pass and flags them with `adopted: true` frontmatter.
Nothing else in the vault is touched. After adoption the vault is
read-first: `ingest()` and the wiki writer refuse to write unless you
pass `force = TRUE`.

This vignette runs adopt mode against six real Obsidian vault repos
collected at `~/pensar-test-vaults`. The chunks evaluate only when
that directory exists; on CRAN the code blocks are rendered as-is
without output. The demos copy each vault to a tempdir before
adopting it so the source tree in `~/pensar-test-vaults` stays
untouched; production users would adopt their actual vault in place.

## What adopt mode does

```r
library(pensar)

v <- tempfile("vault-")
dir.create(v)
writeLines("# Hello", file.path(v, "Hello.md"))

init_vault(v, adopt = TRUE, rproj = FALSE, agent_instructions = FALSE)

list.files(v)
#> [1] "Hello.md"  "index.md"  "log.md"  "schema.md"

# Adopted vaults refuse ingest writes:
tryCatch(ingest("body", source = "test://1", title = "T", vault = v),
         error = function(e) conditionMessage(e))
#> [1] "Adopt mode: read-first. ingest() refuses writes unless force = TRUE."

# Page-level reads still work:
reg <- vault_registry(vault = v, cache = "none", refresh = TRUE)
nrow(reg)
#> [1] 4   # schema.md + index.md + log.md + Hello.md

unlink(v, recursive = TRUE)
```

## Coverage across six real Obsidian vaults

```{r setup, eval = dir.exists("~/pensar-test-vaults"), echo = TRUE}
library(pensar)
vaults_dir <- "~/pensar-test-vaults"
vaults <- list.dirs(vaults_dir, recursive = FALSE)
basename(vaults)
```

```{r adopt_all, eval = dir.exists("~/pensar-test-vaults"), echo = TRUE}
summarize_adoption <- function(src) {
    parent <- tempfile("adopt-")
    dir.create(parent)
    file.copy(src, parent, recursive = TRUE)
    dest <- file.path(parent, basename(src))
    init_vault(dest, adopt = TRUE, rproj = FALSE,
               agent_instructions = FALSE)
    reg <- suppressWarnings(
        vault_registry(vault = dest, cache = "none", refresh = TRUE))
    out <- data.frame(
        vault = basename(src),
        pages = nrow(reg),
        adopted = pensar:::vault_is_adopted(dest),
        stringsAsFactors = FALSE)
    unlink(parent, recursive = TRUE)
    out
}

results <- do.call(rbind, lapply(vaults, summarize_adoption))
results
```

Notes on each vault:

- **bramses-highly-opinionated-vault-2023** (37M) — Zettelkasten with
  date-stamped notes. Adopts cleanly.
- **claude-obsidian** (16M) — `AGENTS.md` / `CLAUDE.md` already
  present; adopt mode leaves them alone.
- **dusk-obsidian-vault** (199M) — Distributed mostly as zip themes;
  contains few `.md` files. Adopt mode handles "vault with no
  markdown content" gracefully (no error, low page count).
- **kepano-obsidian** (1.1M) — Steph Ango's example vault. The
  smallest of the six and the cleanest demo. A handful of pages
  use bare integers in frontmatter (ISBNs) that overflow R's
  integer range; pensar's YAML loader surfaces a warning and
  continues.
- **Obsidian-Vault-Structure** (7.4M) — Templated layout with
  `01 - Primary`, `02 - Secondary`, `03 - Content`, `04 - Templates`
  directories. Adopts cleanly.
- **obsidian-wiki** (1.6M) — Already wiki-shaped. Adopts cleanly.

## Walkthrough: kepano-obsidian

```{r walkthrough, eval = dir.exists("~/pensar-test-vaults/kepano-obsidian"), echo = TRUE}
src <- "~/pensar-test-vaults/kepano-obsidian"
parent <- tempfile("kepano-")
dir.create(parent)
file.copy(src, parent, recursive = TRUE)
vault <- file.path(parent, basename(src))

init_vault(vault, adopt = TRUE, rproj = FALSE,
           agent_instructions = FALSE)

# What got written?
new_files <- setdiff(list.files(vault),
                     list.files(src))
new_files

# Look at the adopted schema:
readLines(file.path(vault, "schema.md"))[1:6]

# Page breakdown:
status(vault)

unlink(parent, recursive = TRUE)
```

## Caveats

- Adopt writes three small files to the vault root. Check the diff
  with `git status` before committing.
- `init_vault(adopt = TRUE)` is one-way at the data level. To revert,
  delete `schema.md`, `index.md`, and `log.md`.
- Frontmatter quirks in the wild (ISBNs as bare integers, dates in
  non-ISO formats) surface as warnings, not errors. The page is
  still indexed; the offending field becomes `NA`.
- Adopt does not migrate Obsidian's `.obsidian/` plugin config to
  pensar. Plugins keep working on the Obsidian side.
- The `force = TRUE` escape hatch is available on `ingest()` and the
  wiki writer if you need to write into an adopted vault. Use
  sparingly; the read-first default exists so an LLM agent can't
  surprise you with destructive writes.

## Related

- `inst/tinytest/test_adopt_real.R` exercises the same six vaults
  with assertions; gated by `tinytest::at_home()` and the
  `PENSAR_TEST_VAULTS` environment variable.
- `inst/tinytest/test_adopt.R` covers the adopt-mode mechanism with
  synthetic directories and runs in every `R CMD check`.
