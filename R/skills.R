#' @title Skill bundle paths
#' @description Helper to locate pensar's bundled agent skills.

#' Locate pensar's bundled skill directory
#'
#' Pensar ships markdown skill bundles under \code{inst/skills/}.
#' Returns the absolute path to the bundle root, or to a specific
#' skill when \code{skill} is given. Useful for symlinking pensar
#' skills into an agent's skill directory. Link the specific directory returned by
#' \code{pensar_skill_path("autoresearch")}, rather than the bundle root.
#'
#' @param skill Optional skill name (e.g., \code{"autoresearch"}).
#'   \code{NULL} returns the bundle root.
#' @return Absolute path. Returns an empty string when the skill is
#'   not installed (matching \code{system.file()} behavior).
#' @examples
#' pensar_skill_path()
#' pensar_skill_path("autoresearch")
#' @export
pensar_skill_path <- function(skill = NULL) {
    base <- system.file("skills", package = "pensar")
    if (!nzchar(base)) {
        return("")
    }
    if (is.null(skill)) {
        return(base)
    }
    candidate <- file.path(base, skill)
    if (!dir.exists(candidate)) {
        return("")
    }
    candidate
}
