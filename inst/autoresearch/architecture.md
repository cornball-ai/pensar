# Autoresearch Architecture

## Goal

`autoresearch()` should be a reliable R package workflow that uses an LLM
for bounded judgment, not an LLM prompt harness that happens to call R
tools. R should own the loop, vault writes, safety gates, and test seams.

The Claude/Codex skill remains useful as agent-facing operating guidance.
The package runtime should instead use explicit configuration, typed
intermediate data, and deterministic orchestration.

## Non-Goals

- Do not make package behavior depend on parsing agent-facing prose.
- Do not let an LLM choose when the run is complete by calling a
  `finalize()` tool.
- Do not let an LLM write arbitrary vault files through a raw file-write
  tool.
- Do not require live web or live model access for the core test suite.

## Proposed Shape

The exported entry point stays small:

```r
autoresearch <- function(topic, vault = default_vault(),
                         search_backend = NULL, fetch_backend = NULL,
                         model_backend = NULL, program = NULL,
                         force = FALSE, verbose = TRUE) {
    ...
}
```

R orchestrates these phases:

1. Resolve and validate the vault.
2. Load a machine-readable research program.
3. Ask the model for a query plan.
4. Search with a configured backend.
5. Ask the model to select sources from search results.
6. Fetch and ingest selected sources.
7. Extract source evidence from filed raw pages.
8. Ask the model for page plans and drafts from evidence.
9. Write wiki pages through a package writer.
10. Rebuild the index, log the run, and return a structured result.

Each phase returns a typed list or data frame that can be tested without
network or model access.

## Runtime Program

The runtime program should be data, not prose. Ship package defaults as:

```text
inst/autoresearch/program.yml
```

A vault can override those defaults with:

```text
<vault>/_research/program.yml
```

Suggested fields:

```yaml
max_rounds: 3
max_queries_per_round: 5
max_sources_per_round: 5
max_pages: 15
source_preferences:
  - official documentation
  - primary sources
  - peer-reviewed papers
  - established publications
confidence:
  high: multiple independent authoritative sources agree
  medium: one good source, or sources partially agree
  low: speculation, opinion, informal source, or unverified claim
stale_after_days: 1095
required_tags:
  - research
```

The existing `inst/skills/pensar/autoresearch/SKILL.md` can point humans
to this file, but `autoresearch()` should load the YAML directly.

## Model Boundary

Model calls should request structured JSON and validate it before use.
The model should never receive an open-ended filesystem tool.

Suggested internal model functions:

```r
autoresearch_plan_queries(topic, program, model_backend)
autoresearch_select_sources(topic, search_results, program, model_backend)
autoresearch_extract_claims(topic, source_pages, program, model_backend)
autoresearch_plan_pages(topic, claims, existing_pages, program, model_backend)
```

Page planning owns the draft body for each proposed page; there is no
separate open-ended drafting step.

Each function should:

- Build a narrow prompt.
- Request JSON.
- Parse with `jsonlite`.
- Validate required fields and scalar/vector shapes.
- Return base R structures.

The default `model_backend` can wrap `llm.api`, but tests should pass a
deterministic fake function.

## Search And Fetch Boundary

Search and fetch should be separate. Search snippets are useful for source
selection, but they are not enough evidence for synthesis.

Suggested backend signatures:

```r
search_backend(query, n)
fetch_backend(url)
```

`search_backend()` returns a data frame:

```r
data.frame(
    title = character(),
    url = character(),
    snippet = character(),
    date = character(),
    source = character()
)
```

`fetch_backend()` returns:

```r
list(
    url = url,
    status_code = 200L,
    content_type = "text/html",
    body = "...",
    fetched_at = now_ts()
)
```

The default search backend can use Tavily. The default fetch backend can
reuse the current `curl` logic from `ingest_url()`, but it should return
body text so evidence extraction is based on fetched content, not search
snippets.

## Ingest Boundary

Prefer one lower-level helper that ingests already-fetched content:

```r
ingest_url_content <- function(url, content, content_type = NULL,
                               vault = default_vault(), type = "articles",
                               title = NULL, tags = NULL,
                               force = FALSE)
```

Then `ingest_url()` becomes fetch plus `ingest_url_content()`, and
`autoresearch()` can fetch once, ingest once, and keep the body available
for evidence extraction.

Idempotency should still key off the manifest source URL.

## Wiki Write Boundary

Add a package-owned writer for wiki pages:

```r
write_wiki_page <- function(slug, frontmatter, body,
                            vault = default_vault(),
                            overwrite = TRUE,
                            force = FALSE)
```

Rules:

- Reject slugs with path separators, `:`, or `.md`.
- Serialize frontmatter through `yaml::as.yaml()`.
- Require `title`, `type`, and `source`.
- Refuse writes in adopted vaults unless `force = TRUE`.
- Preserve deterministic paths under `wiki/`.
- Return a list with `path`, `slug`, and `action`.

`autoresearch()` should only write through this helper.

## Evidence Model

After ingest, convert filed raw pages into evidence records:

```r
list(
    source_slug = "2026-05-18-example-com-paper",
    source_path = "raw/articles/2026-05-18-example-com-paper.md",
    url = "https://example.com/paper",
    title = "Paper title",
    claims = list(
        list(
            text = "Claim text",
            confidence = "medium",
            quote = "short supporting excerpt",
            locator = "section or paragraph if available"
        )
    )
)
```

Synthesis pages should cite raw source wikilinks derived from the filed
page slug, not URLs alone.

## Result Object

Return a classed object with enough detail to audit the run:

```r
structure(
    list(
        topic = topic,
        program = program,
        queries = queries,
        search_results = search_results,
        sources = source_records,
        claims = claim_records,
        pages = page_records,
        synthesis = synthesis_record,
        usage = usage
    ),
    class = "pensar_research"
)
```

The print method should summarize counts and the synthesis slug. Detailed
records stay available for debugging and tests.

## Testing Plan

Tests should cover the orchestration without live services:

- Program defaults load and vault overrides merge.
- Adopted vaults refuse wiki writes unless `force = TRUE`.
- Search backend output is validated.
- Fetch backend output is validated.
- `ingest_url_content()` dedups by source URL.
- Evidence extraction sees fetched page body, not only snippets.
- Page writer rejects unsafe slugs and malformed frontmatter.
- Full fake run writes expected raw pages, wiki pages, index entry, and log
  entry.
- A model response with invalid JSON fails early with a useful error.

Live Tavily and live LLM tests should be opt-in with `tinytest::at_home()`
and skipped on CRAN.

## Migration Path

1. Add the runtime program YAML and loader.
2. Add `write_wiki_page()` and tests.
3. Split `ingest_url()` into fetch and ingest-content helpers.
4. Add fake-backend orchestration tests.
5. Replace the current tool-driven `autoresearch()` with the orchestrator.
6. Keep the skill bundle, but update it to describe the package workflow
   and point to the runtime program.

This path keeps existing user-facing names stable while replacing the
unsafe prompt-harness internals with testable package code.
