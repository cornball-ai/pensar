#' @noRd
read_pensarignore <- function(vault) {
    fp <- file.path(vault, ".pensarignore")
    if (!file.exists(fp)) {
        return(character(0L))
    }
    lines <- readLines(fp, warn = FALSE)
    # Drop comments and blank lines
    lines <- trimws(lines)
    lines <- lines[!grepl("^#", lines)]
    lines <- lines[nzchar(lines)]
    if (length(lines) == 0L) {
        return(character(0L))
    }
    vapply(lines, function(g) utils::glob2rx(g), character(1L),
           USE.NAMES = FALSE)
}

#' @noRd
matches_pensarignore <- function(paths, patterns) {
    if (length(patterns) == 0L) {
        return(logical(length(paths)))
    }
    m <- vapply(patterns, function(p) grepl(p, paths), logical(length(paths)))
    if (is.matrix(m)) {
        apply(m, 1L, any)
    } else {
        as.logical(m)
    }
}

