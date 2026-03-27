#' Download SDMX Data from TUIK
#'
#' Downloads a TUIK SDMX dataset identified by `dataflow_id` and returns a
#' cleaned tibble for analysis.
#'
#' @param dataflow_id Character string. SDMX dataflow identifier from
#'   \code{\link{statistical_tables}}.
#' @param key Character string. SDMX key path. Default \code{"ALL"}.
#' @param start Character string or \code{NULL}. Optional start period.
#' @param end Character string or \code{NULL}. Optional end period.
#' @param detail Character string. Default \code{"full"}.
#' @param dimension_at_observation Character string. Default
#'   \code{"TIME_PERIOD"}.
#'
#' @return A tibble with SDMX observations and character columns trimmed.
#'
#' @examples
#' \dontrun{
#' statistical_data(
#'   dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
#'   key = "TR....../ALL"
#' )
#' }
#'
#' @export
statistical_data <- function(dataflow_id,
                             key = "ALL",
                             start = NULL,
                             end = NULL,
                             detail = "full",
                             dimension_at_observation = "TIME_PERIOD") {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  validate_statistical_sdmx_key(key)
  validate_statistical_sdmx_optional_text(start, "start")
  validate_statistical_sdmx_optional_text(end, "end")
  validate_statistical_sdmx_text(detail, "detail")
  validate_statistical_sdmx_text(dimension_at_observation, "dimension_at_observation")

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

  return(sdmx_data)
}

#' Download SDMX Structure Metadata from TUIK
#'
#' Downloads the SDMX structure metadata for a TUIK dataflow and returns a
#' small wrapper that keeps the raw `rsdmx` object available.
#'
#' @param dataflow_id Character string. SDMX dataflow identifier from
#'   \code{\link{statistical_tables}}.
#' @param detail Character string. Default \code{"Full"}.
#' @param references Character string. Default \code{"Descendants"}.
#'
#' @return A list with at least `dataflow_id`, `structure_url`, and `raw_sdmx`.
#'
#' @examples
#' \dontrun{
#' statistical_data_structure("TR,DF_UHTI_COGRAFI,1.0")
#' }
#'
#' @export
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

validate_statistical_sdmx_text <- function(value, argument_name) {
  if (!is.character(value) || length(value) != 1 || is.na(value)) {
    stop(
      argument_name, " must be a single non-NA character string.",
      call. = FALSE
    )
  }

  return(value)
}

validate_statistical_sdmx_key <- function(key) {
  validate_statistical_sdmx_text(key, "key")

  if (!base::nzchar(key)) {
    stop("key must not be empty.", call. = FALSE)
  }

  return(key)
}

validate_statistical_sdmx_optional_text <- function(value, argument_name) {
  if (is.null(value)) {
    return(value)
  }

  validate_statistical_sdmx_text(value, argument_name)
}
