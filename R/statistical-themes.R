#' Get Statistical Themes from TUIK
#'
#' Retrieves all top-level statistical themes from the TUIK data portal.
#' Theme IDs are used with \code{\link{statistical_resources}},
#' \code{\link{statistical_tables}}, and \code{\link{statistical_databases}} to
#' access specific portal resources. For SDMX-backed datasets, use
#' \code{\link{statistical_tables}} or \code{\link{statistical_resources}} to discover
#' \code{dataflow_id} values, then pass those identifiers to
#' \code{\link{statistical_data}}.
#'
#' @param lang Character string. Portal language code. Default \code{"en"} for
#'   English. Use \code{"tr"} for Turkish.
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
#' @seealso
#' \code{\link{statistical_tables}}, \code{\link{statistical_resources}},
#' \code{\link{statistical_databases}}, \code{\link{statistical_data}}
#'
#' @export
statistical_themes <- function(lang = "en") {
  theme_list <- fetch_theme_tree(lang)
  return(tibble::tibble(
    theme_name = purrr::map_chr(theme_list, "name"),
    theme_id   = purrr::map_chr(theme_list, ~ as.character(.x[["id"]]))
  ))
}
