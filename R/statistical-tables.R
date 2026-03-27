#' Get Statistical Tables for a Theme from TUIK
#'
#' Retrieves SDMX dataflows and direct file downloads for a specific theme from
#' the TUIK data portal. Theme IDs can be obtained using
#' \code{\link{statistical_themes}}. This is a filtered convenience wrapper
#' around \code{\link{statistical_resources}} for \code{"dataflow"} and
#' \code{"istab"} resources.
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
#'   file downloads (\code{istab}). \code{dataflow_id} is the canonical
#'   machine identifier for SDMX-backed datasets. Use it with
#'   \code{\link{statistical_data}} to download observations and with
#'   \code{\link{statistical_data_structure}} to inspect structure metadata.
#'
#' @examples
#' \dontrun{
#' # Get all themes first
#' themes <- statistical_themes()
#'
#' # Get tables for Population and Demography (theme 11)
#' tables <- statistical_tables(11)
#'
#' # Get the broader resource catalog for the same theme
#' resources <- statistical_resources(11)
#'
#' # Filter to SDMX dataflows only
#' dataflows <- dplyr::filter(tables, node_type == "dataflow")
#'
#' # Inspect structure metadata for one dataflow
#' structure_info <- statistical_data_structure(dataflows$dataflow_id[1])
#'
#' # Download observations for one dataflow
#' sdmx_data <- statistical_data(
#'   dataflow_id = dataflows$dataflow_id[1]
#' )
#' }
#'
#' @export
statistical_tables <- function(theme, lang = "tr") {
  resource_rows <- statistical_resources(
    theme = theme,
    type = c("dataflow", "istab"),
    lang = lang
  )

  return(dplyr::transmute(
    resource_rows,
    theme_name = .data$theme_name,
    theme_id = .data$theme_id,
    table_name = .data$resource_name,
    node_type = .data$resource_type,
    dataflow_id = .data$dataflow_id,
    table_url = .data$resource_url
  ))
}
