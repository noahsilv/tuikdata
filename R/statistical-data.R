#' Download SDMX Data from TUIK
#'
#' Download a TUIK SDMX dataset identified by `dataflow_id`.
#'
#' @param dataflow_id Character string. SDMX dataflow identifier from
#'   \code{\link{statistical_tables}}.
#' @param key Character string. SDMX key path. Default \code{"ALL"}.
#' @param start Character string or \code{NULL}. Optional start period.
#' @param end Character string or \code{NULL}. Optional end period.
#' @param detail Character string. Default \code{"full"}.
#' @param dimension_at_observation Character string. Default
#'   \code{"TIME_PERIOD"}.
#' @param lang Character string. Language for human-readable label columns
#'   derived from SDMX metadata. Default \code{"tr"}. Use \code{"en"} for
#'   English labels when available.
#'
#' @return A tibble with trimmed character columns, invariant dimensions
#'   removed, and \code{*_label} columns added for coded dimensions when
#'   labels are available.
#'
#' @examples
#' \dontrun{
#' # Download all observations from a dataflow
#' statistical_data("TR,DF_ADNKS_T26,1.0")
#'
#' # Download with period filter
#' statistical_data(
#'   "TR,DF_ADNKS_T26,1.0",
#'   start = "2020",
#'   end = "2023"
#' )
#'
#' # Download with specific SDMX key path
#' statistical_data(
#'   "TR,DF_UHTI_COGRAFI,1.0",
#'   key = "TR....../ALL"
#' )
#'
#' # Download English labels for dimensions (if available)
#' statistical_data("TR,DF_ADNKS_T26,1.0", lang = "en")
#' }
#'
#' @seealso
#' \code{\link{statistical_tables}} to discover \code{dataflow_id} values,
#' \code{\link{statistical_resources}} for the portal catalog
#'
#' @export
statistical_data <- function(dataflow_id,
                             key = "ALL",
                             start = NULL,
                             end = NULL,
                             detail = "full",
                             dimension_at_observation = "TIME_PERIOD",
                             lang = "tr") {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  validate_statistical_sdmx_key(key)
  validate_statistical_sdmx_optional_text(start, "start")
  validate_statistical_sdmx_optional_text(end, "end")
  validate_statistical_sdmx_text(detail, "detail")
  validate_statistical_sdmx_text(dimension_at_observation, "dimension_at_observation")
  validated_lang <- validate_statistical_lang(lang)

  data_url <- build_sdmx_data_url(
    dataflow_id = validated_dataflow_id,
    key = key,
    start = start,
    end = end,
    detail = detail,
    dimension_at_observation = dimension_at_observation
  )

  sdmx_document <- read_sdmx_document(data_url)
  sdmx_data <- normalize_sdmx_data(sdmx_document)
  structure_info <- statistical_data_structure(validated_dataflow_id)
  label_maps <- extract_sdmx_dimension_label_maps(
    structure_info$raw_sdmx,
    lang = validated_lang
  )

  return(clean_statistical_long_data(sdmx_data, label_maps = label_maps))
}

# Internal SDMX structure helper used for metadata-aware workflows.
# Keeps the raw rsdmx object available without exposing it as public API.
statistical_data_structure <- function(dataflow_id,
                                       detail = "Full",
                                       references = "Descendants") {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  validate_statistical_sdmx_text(detail, "detail")
  validate_statistical_sdmx_text(references, "references")

  structure_url <- build_sdmx_structure_url(
    dataflow_id = validated_dataflow_id,
    detail = detail,
    references = references
  )

  raw_sdmx <- read_sdmx_document(structure_url)

  structure_info <- list(
    dataflow_id = validated_dataflow_id,
    structure_url = structure_url,
    raw_sdmx = raw_sdmx
  )

  return(structure_info)
}
