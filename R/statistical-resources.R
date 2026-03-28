#' Get Statistical Resources for a Theme from TUIK
#'
#' Retrieves all supported resource nodes for a specific theme from the TUIK
#' data portal. Theme IDs can be obtained using
#' \code{\link{statistical_themes}}.
#'
#' @param theme Character or numeric. A single theme ID (e.g., \code{"11"} or
#'   \code{11}). Only one theme can be queried at a time. Invalid or multiple
#'   theme IDs return an error with a list of valid themes.
#' @param type Character vector or \code{NULL}. Optional resource types to keep.
#'   Supported values are \code{"dataflow"}, \code{"istab"},
#'   \code{"database"}, \code{"press"}, and \code{"report"}. Default
#'   \code{NULL} returns all supported resources for the theme.
#' @param lang Character string. Portal language code. Default \code{"tr"} for
#'   Turkish. Use \code{"en"} for English.
#'
#' @return A tibble with 6 columns:
#' \describe{
#'   \item{theme_name}{Character. Name of the statistical theme.}
#'   \item{theme_id}{Character. Numeric ID of the theme.}
#'   \item{resource_name}{Character. Name of the portal resource.}
#'   \item{resource_type}{Character. One of \code{"dataflow"},
#'     \code{"istab"}, \code{"database"}, \code{"press"}, or
#'     \code{"report"}.}
#'   \item{dataflow_id}{Character. SDMX dataflow identifier for
#'     \code{"dataflow"} rows. \code{NA} for other resource types.}
#'   \item{resource_url}{Character. Absolute URL for the resource.}
#' }
#'
#' @details Use \code{resource_type} to decide how to handle a resource:
#' \code{"dataflow"} rows work with \code{\link{statistical_data}}; \code{"istab"},
#' \code{"press"}, and \code{"report"} rows expose downloadable or browsable
#' URLs; \code{"database"} rows point to the legacy interactive database
#' interface.
#'
#' @examples
#' \dontrun{
#' resources <- statistical_resources(11)
#'
#' press_releases <- statistical_resources(11, type = "press")
#'
#' reports_and_files <- statistical_resources(
#'   11,
#'   type = c("report", "istab")
#' )
#' }
#'
#' @seealso
#' \code{\link{statistical_themes}} to get theme IDs,
#' \code{\link{statistical_tables}} for the tables-only view,
#' \code{\link{statistical_databases}} for the databases-only view,
#' \code{\link{statistical_data}} to download SDMX observations
#'
#' @export
statistical_resources <- function(theme, type = NULL, lang = "tr") {
  validated_type <- validate_statistical_resource_types(type)
  theme_tree <- fetch_theme_tree(lang)
  theme_node <- validate_theme(theme, theme_tree)
  resource_rows <- build_statistical_resource_tibble(theme_node)

  if (is.null(validated_type)) {
    return(resource_rows)
  }

  return(dplyr::filter(
    resource_rows,
    .data$resource_type %in% validated_type
  ))
}
