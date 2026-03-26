#' Get Statistical Tables for a Theme from TUIK
#'
#' Retrieves statistical tables and SDMX dataflows for a specific theme from
#' the TUIK data portal. Theme IDs can be obtained using
#' \code{\link{statistical_themes}}.
#'
#' @param theme Character or numeric. A single theme ID (e.g., \code{"11"} or
#'   \code{11}). Only one theme can be queried at a time. Invalid or multiple
#'   theme IDs return an error with a list of valid themes.
#' @param lang Character string. Portal language code. Default \code{"tr"} for
#'   Turkish. Use \code{"en"} for English.
#'
#' @return A tibble with 6 columns:
#' \describe{
#'   \item{theme_name}{Character. Name of the statistical theme.}
#'   \item{theme_id}{Character. Numeric ID of the theme.}
#'   \item{table_name}{Character. Name of the table or dataset.}
#'   \item{node_type}{Character. \code{"dataflow"} for SDMX interactive
#'     datasets; \code{"istab"} for direct file downloads.}
#'   \item{dataflow_id}{Character. SDMX dataflow identifier
#'     (e.g., \code{"TR,DF_ADNKS_T18,1.1"}). \code{NA} for \code{istab} nodes.}
#'   \item{table_url}{Character. For \code{dataflow} nodes: URL to the
#'     interactive data browser. For \code{istab} nodes: direct download URL.}
#' }
#'
#' @note The TUIK portal distinguishes between SDMX dataflows (interactive
#'   query interface via \url{https://databrowser2.tuik.gov.tr}) and static
#'   file downloads (\code{istab}). Use \code{dataflow_id} with the
#'   \code{databrowser2.tuik.gov.tr} API for programmatic SDMX data access.
#'
#' @examples
#' \dontrun{
#' # Get all themes first
#' themes <- statistical_themes()
#'
#' # Get tables for Population and Demography (theme 11)
#' tables <- statistical_tables(11)
#'
#' # Filter to SDMX dataflows only
#' dataflows <- dplyr::filter(tables, node_type == "dataflow")
#'
#' # Use dataflow_id with the SDMX API
#' sdmx_url <- paste0(
#'   "https://databrowser2.tuik.gov.tr/api/core/nodes/1/datasets/",
#'   dataflows$dataflow_id[1], "/data"
#' )
#' }
#'
#' @export
statistical_tables <- function(theme, lang = "tr") {
  theme_tree <- fetch_theme_tree(lang)
  theme_node <- validate_theme(theme, theme_tree)
  table_rows <- build_statistical_table_tibble(theme_node)
  return(table_rows)
}
