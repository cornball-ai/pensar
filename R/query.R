#' @title Query the ontology graph
#' @description Traverse typed relations in the ontology index.

#' Query the ontology graph
#'
#' Traverse typed relations starting from a term. Supports ancestor,
#' descendant, and sibling traversal.
#'
#' @param term Term name or ID to start from.
#' @param relation Relation type to traverse (e.g., "is_a", "part_of").
#' @param direction One of "ancestors", "descendants", or "siblings".
#' @param vault_path Path to the vault.
#' @return A data.frame with columns: id, name, distance.
#' @export
query <- function(term, relation,
                  direction = c("ancestors", "descendants", "siblings"),
                  vault_path = file.path(tools::R_user_dir("pensar", "cache"), "index")) {
    direction <- match.arg(direction)
    idx <- load_index(vault_path)

    term_id <- resolve_term(idx$terms, term)
    if (is.na(term_id)) {
        stop("Term not found: ", term)
    }

    switch(direction, ancestors = traverse_ancestors(idx, term_id, relation),
           descendants = traverse_descendants(idx, term_id, relation),
           siblings = find_siblings(idx, term_id, relation))
}

#' Resolve a term name or alias to its ID
#' @noRd
resolve_term <- function(terms, term) {
    # Try exact ID match
    if (term %in% terms$id) {
        return(term)
    }

    # Try name match
    row <- terms[terms$name == term,, drop = FALSE]
    if (nrow(row) > 0L) {
        return(row$id[1L])
    }

    # Try alias match (pipe-separated)
    for (i in seq_len(nrow(terms))) {
        if (is.na(terms$aliases[i]) || terms$aliases[i] == "") {
            next
        }
        als <- strsplit(terms$aliases[i], "\\|")[[1L]]
        if (term %in% trimws(als)) {
            return(terms$id[i])
        }
    }

    NA_character_
}

#' Traverse ancestors (walk up the graph)
#' @noRd
traverse_ancestors <- function(idx, term_id, relation) {
    rels <- idx$relations[idx$relations$relation_type == relation &
        idx$relations$confirmed == 1L,, drop = FALSE]

    visited <- character()
    frontier <- term_id
    distance <- 0L
    results <- data.frame(id = character(), name = character(),
                          distance = integer(), stringsAsFactors = FALSE)

    while (length(frontier) > 0L) {
        distance <- distance + 1L
        parents <- rels[rels$subject_id %in% frontier,, drop = FALSE]
        parent_ids <- setdiff(parents$object_id, visited)
        if (length(parent_ids) == 0L) {
            break
        }

        parent_names <- idx$terms$name[match(parent_ids, idx$terms$id)]
        parent_names[is.na(parent_names)] <- parent_ids[is.na(parent_names)]

        results <- rbind(results,
                         data.frame(id = parent_ids, name = parent_names,
                                    distance = distance, stringsAsFactors = FALSE))
        visited <- c(visited, parent_ids)
        frontier <- parent_ids
    }

    results
}

#' Traverse descendants (walk down the graph)
#' @noRd
traverse_descendants <- function(idx, term_id, relation) {
    rels <- idx$relations[idx$relations$relation_type == relation &
        idx$relations$confirmed == 1L,, drop = FALSE]

    visited <- character()
    frontier <- term_id
    distance <- 0L
    results <- data.frame(id = character(), name = character(),
                          distance = integer(), stringsAsFactors = FALSE)

    while (length(frontier) > 0L) {
        distance <- distance + 1L
        children <- rels[rels$object_id %in% frontier,, drop = FALSE]
        child_ids <- setdiff(children$subject_id, visited)
        if (length(child_ids) == 0L) {
            break
        }

        child_names <- idx$terms$name[match(child_ids, idx$terms$id)]
        child_names[is.na(child_names)] <- child_ids[is.na(child_names)]

        results <- rbind(results,
                         data.frame(id = child_ids, name = child_names,
                                    distance = distance, stringsAsFactors = FALSE))
        visited <- c(visited, child_ids)
        frontier <- child_ids
    }

    results
}

#' Find siblings (terms sharing the same parent via a relation)
#' @noRd
find_siblings <- function(idx, term_id, relation) {
    rels <- idx$relations[idx$relations$relation_type == relation &
        idx$relations$confirmed == 1L,, drop = FALSE]

    # Find parents
    parents <- rels$object_id[rels$subject_id == term_id]
    if (length(parents) == 0L) {
        return(data.frame(id = character(), name = character(),
                          parent = character(), stringsAsFactors = FALSE))
    }

    # Find all other children of those parents
    sibling_rels <- rels[rels$object_id %in% parents &
        rels$subject_id != term_id,, drop = FALSE]

    if (nrow(sibling_rels) == 0L) {
        return(data.frame(id = character(), name = character(),
                          parent = character(), stringsAsFactors = FALSE))
    }

    sib_names <- idx$terms$name[match(sibling_rels$subject_id, idx$terms$id)]
    sib_names[is.na(sib_names)] <- sibling_rels$subject_id[is.na(sib_names)]

    data.frame(id = sibling_rels$subject_id, name = sib_names,
               parent = sibling_rels$object_id, stringsAsFactors = FALSE)
}
