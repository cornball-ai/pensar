#' @title Dependency graph matrix and clustering
#' @description Build weighted adjacency matrices and cluster terms using
#'   base R graph tools.

#' Build a weighted adjacency matrix from the ontology index
#'
#' Constructs a square numeric matrix where entry \code{[i,j]} is the weight
#' of the strongest relation from term \code{i} to term \code{j}. Only terms
#' that appear in at least one relation are included.
#'
#' @param vault_path Path to the ontology index directory
#'   (default: \code{file.path(tools::R_user_dir("pensar", "cache"), "index")}).
#' @param weights Named numeric vector mapping relation types to weights.
#'   Defaults cover the standard types.
#' @param symmetric Logical. If \code{TRUE} (default), the matrix is made
#'   symmetric by taking \code{max(A[i,j], A[j,i])} for each pair.
#' @return A named square numeric matrix. Row and column names are term IDs.
#' @export
adjacency <- function(vault_path = file.path(tools::R_user_dir("pensar",
            "cache"),
        "index"),
                      weights = c(depends = 1, imports = 1, links_to = 0.8, suggests = 0.3,
                                  is_a = 0.5, part_of = 0.5, uses = 1),
                      symmetric = TRUE) {
    idx <- load_index(vault_path)
    rels <- idx$relations
    if (nrow(rels) == 0L) {
        return(matrix(0, nrow = 0L, ncol = 0L))
    }

    # Only keep relation types that have weights
    rels <- rels[rels$relation_type %in% names(weights),, drop = FALSE]
    if (nrow(rels) == 0L) {
        return(matrix(0, nrow = 0L, ncol = 0L))
    }

    # Terms that participate in at least one relation
    terms <- sort(unique(c(rels$subject_id, rels$object_id)))
    n <- length(terms)
    mat <- matrix(0, nrow = n, ncol = n, dimnames = list(terms, terms))

    # Fill the matrix - take max weight per (i, j) pair
    for (k in seq_len(nrow(rels))) {
        s <- rels$subject_id[k]
        o <- rels$object_id[k]
        w <- weights[rels$relation_type[k]]
        if (w > mat[s, o]) {
            mat[s, o] <- w
        }
    }

    if (symmetric) {
        mat <- pmax(mat, t(mat))
    }

    mat
}

#' Cluster terms using hierarchical clustering
#'
#' Builds a weighted adjacency matrix and applies \code{\link{hclust}} to
#' find groups of related terms. Uses base R only.
#'
#' @param vault_path Path to the ontology index directory
#'   (default: \code{file.path(tools::R_user_dir("pensar", "cache"), "index")}).
#' @param k Number of clusters. If \code{NULL}, a silhouette-like heuristic
#'   is used to pick \code{k} automatically.
#' @param weights Named numeric vector of relation type weights, passed to
#'   \code{\link{adjacency}}.
#' @param method Agglomeration method for \code{\link{hclust}}.
#'   Default \code{"ward.D2"}.
#' @return A data.frame with columns \code{term} and \code{cluster}.
#' @export
clusters <- function(vault_path = file.path(tools::R_user_dir("pensar",
            "cache"),
        "index"),
                     k = NULL,
                     weights = c(depends = 1, imports = 1, links_to = 0.8, suggests = 0.3,
                                 is_a = 0.5, part_of = 0.5, uses = 1),
                     method = "ward.D2") {
    mat <- adjacency(vault_path = vault_path, weights = weights,
                     symmetric = TRUE)
    n <- nrow(mat)
    if (n < 2L) {
        return(data.frame(term = rownames(mat), cluster = rep(1L, n),
                          stringsAsFactors = FALSE))
    }

    # Similarity to distance: 1 - scaled similarity
    mx <- max(mat)
    if (mx > 0) {
        dist_mat <- 1 - mat / mx
    } else {
        dist_mat <- matrix(1, nrow = n, ncol = n)
    }
    diag(dist_mat) <- 0
    d <- as.dist(dist_mat)

    hc <- hclust(d, method = method)

    if (is.null(k)) {
        k <- auto_k(d, hc, max_k = min(n - 1L, 15L))
    }
    k <- max(1L, min(k, n))

    cl <- cutree(hc, k = k)
    data.frame(term = names(cl), cluster = as.integer(cl),
               stringsAsFactors = FALSE)
}

#' Pick k by maximizing mean silhouette width
#' @noRd
auto_k <- function(d, hc, max_k) {
    if (max_k < 2L) {
        return(1L)
    }
    d_mat <- as.matrix(d)
    n <- nrow(d_mat)
    best_k <- 2L
    best_sil <- -Inf

    for (k in 2L:max_k) {
        cl <- cutree(hc, k = k)
        sil <- mean_silhouette(d_mat, cl)
        if (!is.na(sil) && sil > best_sil) {
            best_sil <- sil
            best_k <- k
        }
    }
    best_k
}

#' Mean silhouette width (base R, no cluster package)
#' @noRd
mean_silhouette <- function(d_mat, cl) {
    n <- nrow(d_mat)
    sil <- numeric(n)
    clusters <- unique(cl)
    if (length(clusters) < 2L) {
        return(0)
    }
    for (i in seq_len(n)) {
        own <- cl[i]
        own_members <- which(cl == own & seq_len(n) != i)
        if (length(own_members) == 0L) {
            sil[i] <- 0
            next
        }
        a_i <- mean(d_mat[i, own_members])
        b_i <- Inf
        for (c in clusters) {
            if (c == own) {
                next
            }
            other <- which(cl == c)
            b_i <- min(b_i, mean(d_mat[i, other]))
        }
        sil[i] <- (b_i - a_i) / max(a_i, b_i)
    }
    mean(sil)
}
