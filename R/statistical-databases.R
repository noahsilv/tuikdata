#' Get Statistical Databases for a Theme from TUIK
#'
#' Retrieves interactive database URLs for a specific theme from the TUIK data
#' portal. Theme IDs can be obtained using \code{\link{statistical_themes}}.
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
#'   query interface, not direct downloads. For SDMX-based datasets, use
#'   \code{\link{statistical_tables}} and filter by \code{node_type == "dataflow"}.
#'
#' @examples
#' \dontrun{
#' # Get databases for Population and Demography (theme 11)
#' databases <- statistical_databases(11)
#'
#' # Open a database in the browser
#' browseURL(databases$db_url[1])
#' }
#'
#' @export
statistical_databases <- function(theme, lang = "tr") {
  theme_tree <- fetch_theme_tree(lang)
  theme_node <- validate_theme(theme, theme_tree)
  database_rows <- build_statistical_database_tibble(theme_node)
  return(database_rows)
}
