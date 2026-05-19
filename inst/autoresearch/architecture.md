# Autoresearch Architecture

## Goal

`autoresearch()` is a package-owned R workflow that uses an LLM for
bounded judgment, not an LLM prompt harness that happens to call R
tools. R owns the loop, vault writes, safety gates, and test seams.

The Claude Code skill remains useful as agent-facing operating
guidance. The package runtime uses explicit configuration, typed
intermediate data, and deterministic orchestration.

## Non-Goals

- Package behavior never depends on parsing agent-facing prose.
- The LLM never decides when the run is complete via a `finalize()`
  tool; R bounds the loop with `program$max_rounds`.
- The LLM never writes vault files through a raw file-write tool;
  writes route through `write_wiki_page()`.
- The core test suite never requires live web or live model access.

## Shape

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

`inst/skills/pensar/autoresearch/SKILL.md` points humans to this file;
`autoresearch()` loads the YAML directly.

## Model Boundary

Model calls request structured JSON and validate it before use. The
model never receives an open-ended filesystem tool.

Internal model functions:

```r
autoresearch_plan_queries(topic, program, model_backend)
autoresearch_select_sources(topic, search_results, program, model_backend)
autoresearch_extract_claims(topic, source_pages, program, model_backend)
autoresearch_analyze_gaps(topic, claims, sources, queries, program,
                          model_backend, round)
autoresearch_plan_pages(topic, claims, sources, existing_pages,
                        program, model_backend)
autoresearch_revise_pages(planned, topic, claims, sources, vault,
                          program, model_backend)
```

Page planning owns the draft body for each proposed page. When
`update = TRUE` (default) and the target slug already exists, a
`revise_page` model task gets the existing body plus the new draft and
returns an edit-aware revision.

Each function:

- Builds a narrow prompt.
- Requests JSON.
- Parses with `jsonlite`.
- Validates required fields and scalar/vector shapes.
- Returns base R structures.

The default `model_backend` wraps `llm.api`. Tests pass a deterministic
fake function instead.

## Search And Fetch Boundary

Search and fetch are separate. Search snippets are useful for source
selection but not enough evidence for synthesis.

Backend signatures:

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

The default search backend uses Tavily. The default fetch backend
reuses the `curl` logic from `ingest_url()` and returns body text so
evidence extraction is based on fetched content, not search snippets.

## Ingest Boundary

A lower-level helper ingests already-fetched content:

```r
ingest_url_content <- function(url, content, content_type = NULL,
                               vault = default_vault(), type = "articles",
                               title = NULL, tags = NULL,
                               force = FALSE)
```

`ingest_url()` layers on top of `fetch_url_content()` plus
`ingest_url_content()`, so `autoresearch()` fetches once, ingests
once, and keeps the body available for evidence extraction.

Idempotency keys off the manifest source URL.

## Wiki Write Boundary

The package-owned writer for wiki pages:

```r
write_wiki_page <- function(slug, frontmatter, body,
                            vault = default_vault(),
                            overwrite = TRUE,
                            force = FALSE)
```

Rules:

- Rejects slugs with path separators, `:`, or `.md`.
- Serializes frontmatter through `yaml::as.yaml()`.
- Requires `title`, `type`, and `source`.
- Refuses writes in adopted vaults unless `force = TRUE`.
- Refuses to overwrite an existing wiki file when `overwrite = FALSE`.
- On update (file exists, `overwrite = TRUE`), merges new frontmatter
  over existing: caller-supplied fields replace; `tags` are
  set-unioned; `id`, `aliases`, `status`, `related`, and custom keys
  survive untouched. Body is always replaced.
- Returns a one-row data.frame with `slug`, `path`, and `action`
  (`"created"` or `"updated"`).

`autoresearch()` only writes through this helper.

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

Synthesis pages cite raw source wikilinks derived from the filed page
slug, not URLs alone.

## Result Object

`autoresearch()` returns a classed object with enough detail to audit
the run:

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

The print method summarizes counts and the synthesis slug. Detailed
records stay available for debugging and tests.

## Testing Plan

Tests cover the orchestration without live services:

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

Live Tavily and live LLM tests are opt-in with `tinytest::at_home()`
and skipped on CRAN.

## Implementation History

The package landed in 0.6.1 via this sequence:

1. Add the runtime program YAML and loader.
2. Add `write_wiki_page()` and tests.
3. Split `ingest_url()` into fetch and ingest-content helpers.
4. Add fake-backend orchestration tests.
5. Replace the tool-driven autoresearch loop with the orchestrator.
6. Rewrite the skill bundle to route through the package workflow.
7. Add the read-for-update phase (`revise_page` model task plus
   `autoresearch_revise_pages()`) so existing wiki prose survives a
   re-run.
