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
#' @param layout Character string. Default \code{"long"} returns the flat SDMX
#'   observations. Use \code{"table"} to pivot the result using the default
#'   row and column layout from the TUIK data browser.
#' @param lang Character string. Language for browser-derived table labels.
#'   Default \code{"tr"}. Use \code{"en"} for English labels in
#'   \code{layout = "table"} mode.
#'
#' @return A tibble. By default, returns long-form SDMX observations with
#'   trimmed character columns. In \code{layout = "table"} mode, returns a
#'   wide table using the browser's default layout.
#'
#' @examples
#' \dontrun{
#' statistical_data(
#'   dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
#'   key = "TR....../ALL"
#' )
#'
#' statistical_data(
#'   dataflow_id = "TR,DF_DOGUM_IL_YASA_OZEL_DOGHIZ,1.0",
#'   layout = "table",
#'   lang = "en"
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
                             layout = "long",
                             lang = "tr") {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  validate_statistical_sdmx_key(key)
  validate_statistical_sdmx_optional_text(start, "start")
  validate_statistical_sdmx_optional_text(end, "end")
  validate_statistical_sdmx_text(detail, "detail")
  validate_statistical_sdmx_text(dimension_at_observation, "dimension_at_observation")
  validated_layout <- match.arg(layout, c("long", "table"))
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

  if (validated_layout == "table") {
    structure_payload <- fetch_databrowser_structure(
      validated_dataflow_id,
      lang = validated_lang
    )
    table_layout <- extract_databrowser_table_layout(structure_payload)
    structure_info <- statistical_data_structure(validated_dataflow_id)
    label_maps <- extract_sdmx_dimension_label_maps(
      structure_info$raw_sdmx,
      lang = validated_lang
    )

    return(build_statistical_data_table(
      sdmx_data,
      table_layout = table_layout,
      label_maps = label_maps
    ))
  }

  return(sdmx_data)
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
