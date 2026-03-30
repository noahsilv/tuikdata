#' Get Geographic Data from TUIK
#'
#' Retrieve geographic metadata or indicator values from the TUIK geographic portal.
#'
#' @param var_num Character. Data Series Number (e.g., "SNM-GK160951-O33303").
#'   Obtain from metadata mode. Required for data download.
#' @param var_level Numeric or \code{NULL}. NUTS level for the download.
#'   Optional when the selected series is available at only one level.
#' @param lang Character. Language code. Use `"en"` for English or `"tr"` for
#'   Turkish.
#'
#' @return Returns different structures depending on usage mode:
#'
#' **Metadata mode** (no parameters): A tibble with 4 columns:
#' \describe{
#'   \item{var_name}{Character. Variable name in the selected language}
#'   \item{var_num}{Character. Variable number/code for queries}
#'   \item{var_levels}{List. Available NUTS levels for this variable}
#'   \item{var_period}{Character. Time period type ("yillik" or "aylik")}
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
#' # Get metadata in Turkish
#' geo_data(lang = "tr")
#'
#' # Get data for a specific variable
#' geo_data(
#'   var_num = "SNM-GK160951-O33303",
#'   var_level = 2,
#'   lang = "tr"
#' )
#' }
#'
#' @seealso
#' \code{\link{geo_map}} for boundary geometries
#'
#' @export
geo_data <- function(var_num = NULL,
                     var_level = NULL,
                     lang = "en") {
  data_mode <- !is.null(var_num) || !is.null(var_level)
  validated_lang <- validate_geo_lang(lang)
  selected_var_num <- if (is.null(var_num)) NULL else validate_string_single(var_num, "var_num")

  if (!is.null(var_level)) {
    if (length(var_level) != 1 || is.na(var_level) || !(var_level %in% c(2, 3, 4))) {
      stop(
        "var_level must be a single level value of 2, 3, or 4 (NUTS-2, NUTS-3, or LAU-1).",
        call. = FALSE
      )
    }
  }

  if (data_mode) {
    if (is.null(selected_var_num)) {
      stop("var_num is required for data download.", call. = FALSE)
    }
  }

  doc <- jsonlite::fromJSON(
    "https://cip.tuik.gov.tr/assets/sideMenu.json?v=2.000",
    simplifyDataFrame = FALSE
  )

  variable_metadata <- build_geo_variable_metadata(doc, validated_lang)

  if (is.null(selected_var_num)) {
    return(
      variable_metadata |>
        dplyr::select(
          "var_name",
          "var_num",
          "var_levels",
          "var_period"
        )
    )
  }

  if (!(selected_var_num %in% variable_metadata$var_num)) {
    stop("var_num must match one of the values returned by geo_data().", call. = FALSE)
  }

  series_metadata <- variable_metadata |>
    dplyr::filter(.data$var_num == .env$selected_var_num) |>
    dplyr::slice_head(n = 1)

  available_levels <- sort(unique(unlist(series_metadata$var_levels[[1]])))

  if (is.null(var_level)) {
    if (length(available_levels) == 1) {
      var_level <- available_levels[[1]]
    } else {
      stop(
        paste0(
          "var_level is required for ", selected_var_num,
          ". Valid levels: ",
          paste(available_levels, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }

  if (!(var_level %in% available_levels)) {
    stop(
      paste0(
        "var_level must be one of the available levels for ", selected_var_num,
        ": ",
        paste(available_levels, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  query_url <- build_geo_data_query_url(series_metadata, var_level)

  geo_json_data <- tryCatch(
    jsonlite::fromJSON(query_url),
    error = function(e) {
      stop("Data '", selected_var_num, "' is not available at NUTS level ", var_level)
    }
  )

  vals_name <- pick_geo_label(geo_json_data$gosterge_ad, geo_json_data$gosterge_ad_ing, validated_lang)

  dates <- normalize_geo_dates(geo_json_data$tarihler)

  formatted_data <- geo_json_data$veriler |>
    tidyr::unnest_wider(col = "veri", names_sep = ", ") |>
    purrr::set_names(c("code", dates)) |>
    tidyr::pivot_longer(
      cols = -dplyr::all_of("code"),
      names_to = "date",
      values_to = vals_name
    ) |>
    janitor::clean_names() |>
    dplyr::mutate(code = as.character(.data$code))

  formatted_data
}

#' @noRd
#' @keywords internal
build_geo_variable_metadata <- function(side_menu_document, lang) {
  submenu_items <- side_menu_document$menu |>
    purrr::map(~ .x$subMenu) |>
    purrr::flatten()

  tibble::tibble(
    var_name = submenu_items |>
      purrr::map_chr(~ pick_geo_label(.x$gostergeAdi, .x$gostergeAdiEn, lang)),
    var_num = submenu_items |> purrr::map_chr(~ .x$gostergeNo),
    var_levels = submenu_items |> purrr::map(~ .x$duzeyler),
    var_period = submenu_items |> purrr::map_chr(~ .x$period),
    var_source = submenu_items |> purrr::map_chr(~ .x$kaynak),
    var_recordnum = submenu_items |> purrr::map_int(~ .x$kayitSayisi)
  )
}

#' @noRd
#' @keywords internal
build_geo_data_query_url <- function(series_metadata, var_level) {
  paste0(
    "https://cip.tuik.gov.tr/Home/GetMapData?kaynak=", series_metadata$var_source[[1]],
    "&duzey=", var_level,
    "&gostergeNo=", series_metadata$var_num[[1]],
    "&kayitSayisi=", series_metadata$var_recordnum[[1]],
    "&period=", series_metadata$var_period[[1]]
  )
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

  stringr::str_c(
    stringr::str_sub(raw_dates, 1L, 4L),
    stringr::str_sub(raw_dates, 5L, 6L),
    sep = "-"
  )
}

#' @noRd
#' @keywords internal
validate_geo_lang <- function(lang) {
  validate_string_single(lang, "lang", allowed_values = c("tr", "en"))
}

#' @noRd
#' @keywords internal
pick_geo_label <- function(label_tr, label_en, lang) {
  validated_lang <- validate_geo_lang(lang)

  if (validated_lang == "en" && !is.null(label_en) && !is.na(label_en) && nzchar(label_en)) {
    return(label_en)
  }

  label_tr
}
