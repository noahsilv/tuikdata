#' Get Geographic Maps from TUIK
#'
#' Downloads spatial boundary data from the TUIK geographic portal at different
#' administrative levels. Returns simple features (sf) objects with geometries
#' in WGS 84 coordinate reference system (EPSG:4326).
#'
#' @param level Numeric. Administrative level to retrieve:
#' \describe{
#'   \item{2}{NUTS-2 (İstatistiki Bölge Birimleri Sınıflaması - Level 2)}
#'   \item{3}{NUTS-3 / Provincial level (İl)}
#'   \item{4}{LAU-1 / District level (İlçe)}
#'   \item{9}{Settlement points (Yerleşim yerleri) - returns POINT geometries}
#' }
#'
#' @param dataframe Logical. If TRUE, returns a regular tibble without geometry.
#'   If FALSE (default), returns an sf object with spatial data.
#'
#' @return An sf object (or tibble if dataframe = TRUE) with different columns
#'   depending on the level:
#'
#' **Levels 2, 3, 4** return MULTIPOLYGON geometries with columns:
#' \describe{
#'   \item{code}{Character. Unique geographic code (renamed from \code{duzeyKodu})}
#'   \item{bolgeKodu}{Character. NUTS region code}
#'   \item{nutsKodu}{Character. NUTS classification code}
#'   \item{ad}{Character. Geographic unit name in Turkish}
#'   \item{geometry}{sfc_MULTIPOLYGON. Spatial boundaries (WGS 84)}
#' }
#'
#' **Level 9** returns POINT geometries with columns:
#' \describe{
#'   \item{ad}{Character. Settlement name in Turkish}
#'   \item{tp}{Integer. Settlement type code}
#'   \item{bs}{Integer. Classification code}
#'   \item{bm}{Integer. Additional classification}
#'   \item{geometry}{sfc_POINT. Point coordinates (WGS 84)}
#' }
#'
#' @examples
#' \dontrun{
#' # Download NUTS-3 boundaries as sf object
#' nuts3_sf <- geo_map(level = 3)
#'
#' # Drop geometry — return plain tibble for joins
#' nuts3_tbl <- geo_map(level = 3, dataframe = TRUE)
#'
#' # Settlement points (POINT geometry)
#' settlements <- geo_map(level = 9)
#' }
#'
#' @seealso
#' \code{\link{geo_data}} for geographic statistical data
#'
#' @export
geo_map <- function(level = 2, dataframe = FALSE) {
  if (length(level) != 1 || is.na(level) || !(level %in% c(2, 3, 4, 9))) {
    stop("level must be a single value of 2, 3, 4, or 9.", call. = FALSE)
  }

  urls <- c(
    "2" = "https://cip.tuik.gov.tr/assets/geometri/nuts2.json",
    "3" = "https://cip.tuik.gov.tr/assets/geometri/nuts3.json",
    "4" = "https://cip.tuik.gov.tr/assets/geometri/nuts4.json",
    "9" = "https://cip.tuik.gov.tr/assets/geometri/yerlesim_noktalari.json"
  )

  query_url <- urls[as.character(level)]

  map_json_data <- tryCatch(
    jsonlite::fromJSON(query_url),
    error = function(e) {
      stop("Map data not available at level ", level)
    }
  )

  # The TUIK API returns `"type":["FeatureCollection"]` (array-wrapped) instead
  # of `"type":"FeatureCollection"`, which is invalid GeoJSON. sf::read_sf()
  # rejects it. The replacement below fixes the upstream defect before parsing.
  dt_sf <- map_json_data |>
    jsonlite::toJSON() |>
    stringr::str_replace_all('\\[\"FeatureCollection\"\\]', '\"FeatureCollection\"') |>
    sf::read_sf()

  dt_sf$name <- NULL

  dt_sf <- dt_sf |>
    dplyr::mutate(
      dplyr::across(dplyr::where(is.character), stringr::str_trim)
    )

  if (level != 9) {
    dt_sf <- dt_sf |>
      dplyr::rename(code = "duzeyKodu") |>
      dplyr::mutate(code = as.character(.data$code))
  }

  if (!dataframe) {
    return(dt_sf)
  }

  sf::st_drop_geometry(dt_sf)
}
