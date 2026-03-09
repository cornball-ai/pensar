#' @title Promote a term with a stable ID
#' @description Write a stable ontology ID into a file's frontmatter.

#' Promote a term with a stable ID
#'
#' Assigns a stable \code{PREFIX:NNNNNNN} identifier to a term by writing
#' it into the markdown file's YAML frontmatter.
#'
#' @param term Term name to promote.
#' @param vault_path Path to the markdown vault directory.
#' @param prefix ID prefix (default "ONTO").
#' @return The new ID (invisibly).
#' @export
promote <- function(term,
                    vault_path = file.path(tools::R_user_dir("pensar", "cache"), "index"),
                    prefix = "ONTO") {
    vault_path <- normalizePath(vault_path, mustWork = TRUE)
    idx <- load_index(vault_path)

    # Find the term
    row <- idx$terms[idx$terms$name == term |
        idx$terms$id == term,, drop = FALSE]

    if (nrow(row) == 0L) {
        stop("Term not found: ", term)
    }
    if (row$promoted[1L] == 1L) {
        message("Term already promoted with ID: ", row$id[1L])
        return(invisible(row$id[1L]))
    }
    if (is.na(row$filepath[1L])) {
        stop("Term has no source file. Cannot promote a term inferred from links alone.")
    }

    # Generate next ID
    new_id <- next_id(idx, prefix)

    # Write ID into frontmatter
    filepath <- file.path(vault_path, row$filepath[1L])
    write_id_to_frontmatter(filepath, new_id)

    # Update index
    old_id <- row$id[1L]
    i <- which(idx$terms$id == old_id)
    idx$terms$id[i] <- new_id
    idx$terms$promoted[i] <- 1L
    idx$terms$updated_at[i] <- now_ts()

    # Update relations referencing old ID
    idx$relations$subject_id[idx$relations$subject_id == old_id] <- new_id
    idx$relations$object_id[idx$relations$object_id == old_id] <- new_id

    save_index(idx, vault_path)

    message("Promoted '", row$name[1L], "' -> ", new_id)
    invisible(new_id)
}

#' Generate the next ID
#' @noRd
next_id <- function(idx, prefix) {
    promoted <- idx$terms[idx$terms$promoted == 1L &
        grepl(paste0("^", prefix, ":"), idx$terms$id),,
        drop = FALSE]

    if (nrow(promoted) == 0L) {
        return(sprintf("%s:%07d", prefix, 1L))
    }

    nums <- as.integer(sub("^[^:]+:", "", promoted$id))
    nums <- nums[!is.na(nums)]
    if (length(nums) == 0L) {
        next_num <- 1L
    } else {
        next_num <- max(nums) + 1L
    }
    sprintf("%s:%07d", prefix, next_num)
}

#' Write an id field into YAML frontmatter
#' @noRd
write_id_to_frontmatter <- function(filepath, id) {
    lines <- readLines(filepath, warn = FALSE)

    if (length(lines) < 2L || trimws(lines[1L]) != "---") {
        # No frontmatter: add it
        lines <- c("---", paste0("id: ", id), "---", lines)
    } else {
        end <- which(trimws(lines[-1L]) == "---")[1L] + 1L
        # Insert id just after opening ---
        lines <- c(lines[1L], paste0("id: ", id), lines[2L:length(lines)])
    }

    writeLines(lines, filepath)
}
