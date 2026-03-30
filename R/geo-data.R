#' Get Geographic Data from TUIK
#'
#' Retrieve geographic metadata or indicator values from the TUIK geographic portal.
#'
#' @param var_num Character. Data Series Number (e.g., "SNM-GK160951-O33303").
#'   Obtain from metadata mode. Required for data download.
#' @param var_level Numeric. NUTS Level (2, 3, or 4 for NUTS-2, NUTS-3, or LAU-1).
#'   Required for data download.
#' @param var_source Character. Data Series Source. Either "medas" or
#'   "ilGostergeleri". Required for data download.
#' @param var_period Character. Data Series Period. Either "yillik" (yearly)
#'   or "aylik" (monthly). Required for data download.
#' @param var_recordnum Numeric. Data Series Record Number (3, 5, or 24).
#'   Number of time periods to retrieve. Required for data download.
#' @param lang Character. Language code. Use `"tr"` for Turkish or `"en"` for
#'   English.
#'
#' @return Returns different structures depending on usage mode:
#'
#' **Metadata mode** (no parameters): A tibble with 6 columns:
#' \describe{
#'   \item{var_name}{Character. Variable name in the selected language}
#'   \item{var_num}{Character. Variable number/code for queries}
#'   \item{var_levels}{List. Available NUTS levels for this variable}
#'   \item{var_period}{Character. Time period type ("yillik" or "aylik")}
#'   \item{var_source}{Character. Data source ("medas" or "ilGostergeleri")}
#'   \item{var_recordnum}{Numeric. Number of available time periods}
#' }
#'
#' **Data mode** (all parameters): A tibble with 3+ columns:
#' \describe{
#'   \item{code}{Character. Geographic unit code (NUTS-2, NUTS-3, or LAU-1)}
#'   \item{date}{Character. Time period (YYYY or YYYY-MM format)}
#'   \item{variable_name}{Numeric/Character. Values for the requested variable.
#'     The column name uses the selected language when available.}
#' }
#'
#' @examples
#' \dontrun{
#' # Get metadata for all available variables
#' geo_data()
#'
#' # Get metadata in English
#' geo_data(lang = "en")
#'
#' # Get data for a specific variable at NUTS-2 level
#' geo_data(
#'   var_level = 2,
#'   var_num = "SNM-GK160951-O33303",
#'   var_source = "medas",
#'   var_period = "yillik",
#'   var_recordnum = 5,
#'   lang = "en"
#' )
#' }
#'
#' @seealso
#' \code{\link{geo_map}} for boundary geometries
#'
#' @export
geo_data <- function(var_num = NULL,
                     var_level = NULL,
                     var_source = NULL,
                     var_period = NULL,
                     var_recordnum = NULL,
                     lang = "tr") {
  data_params <- list(var_num, var_level, var_source, var_period, var_recordnum)
  params_are_null <- purrr::map_lgl(data_params, is.null)
  data_mode <- !all(params_are_null)
  validated_lang <- validate_geo_lang(lang)

  if (data_mode) {
    if (any(params_are_null)) {
      stop("All parameters (var_num, var_level, var_source, var_period, var_recordnum) must be provided together for data download.")
    }
    if (!(var_level %in% c(2, 3, 4))) {
      stop("var_level must be 2, 3, or 4 (NUTS-2, NUTS-3, or LAU-1)")
    }
  }

  doc <- jsonlite::fromJSON(
    "https://cip.tuik.gov.tr/assets/sideMenu.json?v=2.000",
    simplifyDataFrame = FALSE
  )

  submenu_items <- doc$menu |>
    purrr::map(~ .x$subMenu) |>
    purrr::flatten()

  variable_dt <- tibble::tibble(
    var_name = submenu_items |>
      purrr::map_chr(~ pick_geo_label(.x$gostergeAdi, .x$gostergeAdiEn, validated_lang)),
    var_num = submenu_items |> purrr::map_chr(~ .x$gostergeNo),
    var_levels = submenu_items |> purrr::map(~ .x$duzeyler),
    var_period = submenu_items |> purrr::map_chr(~ .x$period),
    var_source = submenu_items |> purrr::map_chr(~ .x$kaynak),
    var_recordnum = submenu_items |> purrr::map_int(~ .x$kayitSayisi)
  )

  if (is.null(var_num)) {
    return(variable_dt)
  }

  if (!(var_num %in% variable_dt$var_num)) {
    stop("var_num must match one of the values returned by geo_data().", call. = FALSE)
  }

  query_url <- paste0(
    "https://cip.tuik.gov.tr/Home/GetMapData?kaynak=", var_source,
    "&duzey=", var_level,
    "&gostergeNo=", var_num,
    "&kayitSayisi=", var_recordnum,
    "&period=", var_period
  )

  geo_json_data <- tryCatch(
    jsonlite::fromJSON(query_url),
    error = function(e) {
      stop("Data '", var_num, "' is not available at NUTS level ", var_level)
    }
  )

  vals_name <- pick_geo_label(
    geo_json_data$gosterge_ad,
    geo_json_data$gosterge_ad_ing,
    validated_lang
  )

  dates <- normalize_geo_dates(geo_json_data$tarihler)

  formatted_data <- geo_json_data$veriler |>
    tidyr::unnest_wider(col = "veri", names_sep = ", ") |>
    purrr::set_names(c("code", dates)) |>
    tidyr::pivot_longer(
      cols = -code,
      names_to = "date",
      values_to = vals_name
    ) |>
    janitor::clean_names() |>
    dplyr::mutate(code = as.character(.data$code))

  return(formatted_data)
}

#' @noRd
#' @keywords internal
normalize_geo_dates <- function(raw_dates) {
  if (length(raw_dates) == 0) {
    return(raw_dates)
  }

  if (stringr::str_length(raw_dates[[1]]) != 6L) {
    return(raw_dates)
  }

  normalized_dates <- stringr::str_c(
    stringr::str_sub(raw_dates, 1L, 4L),
    stringr::str_sub(raw_dates, 5L, 6L),
    sep = "-"
  )

  return(normalized_dates)
}

#' @noRd
#' @keywords internal
validate_geo_lang <- function(lang) {
  return(validate_string_single(lang, "lang", allowed_values = c("tr", "en")))
}

#' @noRd
#' @keywords internal
pick_geo_label <- function(label_tr, label_en, lang) {
  validated_lang <- validate_geo_lang(lang)

  if (validated_lang == "en" && !is.null(label_en) && !is.na(label_en) && nzchar(label_en)) {
    return(label_en)
  }

  return(label_tr)
}
