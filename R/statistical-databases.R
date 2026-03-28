#' Get Statistical Databases for a Theme from TUIK
#'
#' Retrieves interactive database URLs for a specific theme from the TUIK data
#' portal. Theme IDs can be obtained using \code{\link{statistical_themes}}.
#' This is a filtered convenience wrapper around
#' \code{\link{statistical_resources}} for \code{"database"} resources.
#'
#' @param theme Character or numeric. A single theme ID (e.g., \code{"11"} or
#'   \code{11}). Only one theme can be queried at a time. Invalid or multiple
#'   theme IDs return an error with a list of valid themes.
#' @param lang Character string. Portal language code. Default \code{"tr"} for
#'   Turkish. Use \code{"en"} for English.
#'
#' @return A tibble with 4 columns:
#' \describe{
#'   \item{theme_name}{Character. Name of the statistical theme.}
#'   \item{theme_id}{Character. Numeric ID of the theme.}
#'   \item{db_name}{Character. Name of the interactive database.}
#'   \item{db_url}{Character. URL to the database query interface.}
#' }
#'
#' @note Database URLs link to the legacy \code{biruni.tuik.gov.tr} interactive
#'   query interface, not direct downloads. For SDMX-backed datasets, use
#'   \code{\link{statistical_tables}} to discover \code{dataflow_id} values,
#'   then use \code{\link{statistical_data}}. For press releases and reports,
#'   use \code{\link{statistical_resources}} with \code{type = "press"} or
#'   \code{type = "report"}.
#'
#' @examples
#' \dontrun{
#' # Get databases for Population and Demography (theme 11)
#' databases <- statistical_databases(11)
#'
#' # Retrieve press releases for the same theme
#' press_releases <- statistical_resources(11, type = "press")
#'
#' # Open a database in the browser
#' browseURL(databases$db_url[1])
#' }
#'
#' @seealso
#' \code{\link{statistical_themes}}, \code{\link{statistical_resources}},
#' \code{\link{statistical_tables}}
#'
#' @export
statistical_databases <- function(theme, lang = "tr") {
  resource_rows <- statistical_resources(
    theme = theme,
    type = "database",
    lang = lang
  )

  return(dplyr::transmute(
    resource_rows,
    theme_name = .data$theme_name,
    theme_id = .data$theme_id,
    db_name = .data$resource_name,
    db_url = .data$resource_url
  ))
}
