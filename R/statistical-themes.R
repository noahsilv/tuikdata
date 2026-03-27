#' Get Statistical Themes from TUIK
#'
#' Retrieves all top-level statistical themes from the TUIK data portal.
#' Theme IDs are used with \code{\link{statistical_tables}} and
#' \code{\link{statistical_databases}} to access specific data. For SDMX-backed
#' datasets, use \code{\link{statistical_tables}} to discover
#' \code{dataflow_id} values, then pass those identifiers to
#' \code{\link{statistical_data}} or \code{\link{statistical_data_structure}}.
#'
#' @param lang Character string. Portal language code. Default \code{"tr"} for
#'   Turkish. Use \code{"en"} for English.
#'
#' @return A tibble with 2 columns:
#' \describe{
#'   \item{theme_name}{Character. Name of the statistical theme.}
#'   \item{theme_id}{Character. Numeric ID used to query tables and databases.}
#' }
#'
#' @examples
#' \dontrun{
#' themes <- statistical_themes()
#' }
#'
#' @export
statistical_themes <- function(lang = "tr") {
  theme_list <- fetch_theme_tree(lang)
  return(tibble::tibble(
    theme_name = purrr::map_chr(theme_list, "name"),
    theme_id   = purrr::map_chr(theme_list, ~ as.character(.x[["id"]]))
  ))
}
