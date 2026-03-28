#' Download SDMX Data from TUIK
#'
#' Downloads a TUIK SDMX dataset identified by `dataflow_id` and returns a
#' cleaned tibble ready for analysis. Observations are returned in long form
#' with trimmed character columns, invariant dimensions dropped, and
#' human-readable `*_label` columns appended for coded dimensions when SDMX
#' codelists are available.
#'
#' @param dataflow_id Character string. SDMX dataflow identifier in
#'   `"AGENCY,FLOW_ID,VERSION"` format (e.g., `"TR,DF_UHTI_COGRAFI,1.0"`).
#'   Obtain valid identifiers from \code{\link{statistical_tables}}.
#' @param key Character string. SDMX key filter. Default \code{"ALL"} returns
#'   all series. Use dot-notation to filter dimensions, e.g.,
#'   \code{"TR....../ALL"} restricts \code{REF_AREA} to Turkey. Refer to the
#'   SDMX REST API specification for full key syntax.
#' @param start Character string or \code{NULL}. Optional start period in
#'   ISO 8601 format (e.g., \code{"2015"}, \code{"2015-Q1"},
#'   \code{"2015-01"}). Default \code{NULL} returns all available periods.
#' @param end Character string or \code{NULL}. Optional end period in the same
#'   format as \code{start}. Default \code{NULL} returns all available periods.
#' @param detail Character string. Controls how much data the SDMX endpoint
#'   returns. \code{"full"} (default) includes all attributes and observations.
#'   Other valid values are \code{"dataonly"}, \code{"serieskeysonly"}, and
#'   \code{"nodata"}.
#' @param dimension_at_observation Character string. SDMX
#'   \code{dimensionAtObservation} parameter. Default \code{"TIME_PERIOD"}
#'   returns data in time-series orientation. Use \code{"AllDimensions"} for
#'   flat/cross-sectional layout.
#' @param lang Character string. Language code for human-readable label columns
#'   derived from SDMX codelists. Default \code{"tr"} returns Turkish labels
#'   where available. Use \code{"en"} for English.
#'
#' @return A tibble in long form. Columns depend on the dataflow's dimension
#'   structure; invariant dimensions (single unique value) are dropped. For
#'   each coded dimension with a matching codelist, a companion
#'   \code{<dim>_label} column is appended immediately after the code column.
#'   The final two columns are always \code{obsTime} (character, ISO period)
#'   and \code{obsValue} (character, numeric observation value as returned by
#'   SDMX).
#'
#' @examples
#' \dontrun{
#' # All series for the International Services Trade by Country Group dataflow
#' statistical_data(dataflow_id = "TR,DF_UHTI_COGRAFI,1.0")
#'
#' # Restrict to Turkey, with date range
#' statistical_data(
#'   dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
#'   key         = "TR....../ALL",
#'   start       = "2015",
#'   end         = "2022"
#' )
#'
#' # English labels
#' statistical_data(
#'   dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
#'   lang        = "en"
#' )
#' }
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
