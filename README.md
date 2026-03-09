# pensar

Lightweight knowledge graph for R, built from markdown files with YAML frontmatter and typed links.

pensar ("to think") is part of [cerebro](https://github.com/cornball-ai/cerebro), the AI agent toolchain for R. It parses markdown vaults into a graph of terms and relations, stored as three TSV files. One dependency: `yaml`.

## Install

```r
remotes::install_github("cornball-ai/pensar")
```

## How it works

pensar reads markdown files that contain Dataview-style inline fields:

```markdown
---
id: ONTO:0000042
aliases: [kNN, k-nearest neighbors]
---

is_a:: [[classifier]]
uses:: [[distance_metric]]
```

Those typed links (`is_a::`, `uses::`, `part_of::`) become edges in the graph. Untyped `[[wikilinks]]` are picked up too, and pensar can suggest types for them based on folder structure and heading context.

## Usage

### Index a vault

Scan a directory of markdown files and build the graph:

```r
pensar::index_vault("~/notes/ml")
```

Incremental. Only re-parses files whose content changed (MD5 hash check).

### Startup scan

Or scan your entire home directory for project metadata (CLAUDE.md, DESCRIPTION, etc.) and wire up the graph automatically:

```r
pensar::startup()
```

This finds every project with recognized metadata, registers them as terms, and pulls dependency relations from DESCRIPTION files.

### Query the graph

Traverse typed relations in any direction:

```r
# Walk up: what is kNN?
pensar::query("kNN", "is_a", direction = "ancestors")

# Walk down: what classifiers exist?
pensar::query("classifier", "is_a", direction = "descendants")

# Siblings: other classifiers like kNN
pensar::query("kNN", "is_a", direction = "siblings")
```

Returns a data.frame with `id`, `name`, and `distance` (or `parent` for siblings).

### Check status

```r
pensar::status()
#> Ontology status:
#>   Terms:       42 (12 promoted)
#>   Relations:   87 confirmed
#>   Suggestions: 5 unconfirmed
#>   By type:
#>     is_a: 31
#>     uses: 24
#>     part_of: 18
```

### Suggest relations

Propose typed edges from untyped wikilinks, using heuristics (folder co-location, heading context):

```r
pensar::suggest("~/notes/ml")
```

Suggestions land in the index with `confirmed = 0`. Review them, then confirm or discard.

### Add terms and relations programmatically

```r
pensar::add(
  terms = c("svm", "random_forest"),
  relations = data.frame(
    subject = c("svm", "random_forest"),
    relation_type = c("is_a", "is_a"),
    object = c("classifier", "classifier")
  ),
  vault_path = "~/notes/ml"
)
```

Optionally writes annotation files so additions survive re-indexing.

### More

- `promote()` stamps a term with a stable `PREFIX:NNNNNNN` ID in its frontmatter
- `adjacency()` builds a weighted adjacency matrix from the graph
- `clusters()` groups related terms via hierarchical clustering
- `emit_obo()` exports the ontology in OBO 1.4 format

## Storage

The index lives in a `.pensar/` directory (three TSV files: `terms.tsv`, `relations.tsv`, `files.tsv`). For `startup()`, it writes to `~/.local/share/R/pensar/`.

No database. No server. Just flat files.

## Sister packages

pensar is one piece of the cerebro toolchain:

| Package | Purpose |
|---|---|
| [saber](https://github.com/cornball-ai/saber) | AST symbol index, blast radius, package introspection |
| [pensar](https://github.com/cornball-ai/pensar) | Knowledge graph from markdown (this package) |
| [informR](https://github.com/cornball-ai/informR) | Project briefings and instructions from the graph |
| [mirar](https://github.com/cornball-ai/mirar) | Runtime inspection of live R sessions |
| [llamaR](https://github.com/cornball-ai/llamaR) | Agent runtime and chat loop |

## License

Apache 2.0
