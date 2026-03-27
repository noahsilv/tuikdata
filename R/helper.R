#' Helper functions
#'
#' @keywords internal
#' @name helpers
NULL

validate_dataflow_id <- function(dataflow_id) {
  if (!is.character(dataflow_id) || length(dataflow_id) != 1 || is.na(dataflow_id)) {
    stop(
      paste(
        "dataflow_id must be a single SDMX identifier like",
        "'TR,DF_UHTI_COGRAFI,1.0'."
      ),
      call. = FALSE
    )
  }

  dataflow_parts <- base::strsplit(dataflow_id, ",", fixed = TRUE)[[1]]
  if (length(dataflow_parts) != 3 || any(base::nchar(dataflow_parts) == 0)) {
    stop(
      paste(
        "dataflow_id must be a single SDMX identifier with three",
        "comma-separated parts like 'TR,DF_UHTI_COGRAFI,1.0'."
      ),
      call. = FALSE
    )
  }

  return(dataflow_id)
}

split_dataflow_id <- function(dataflow_id) {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  dataflow_parts <- base::strsplit(validated_dataflow_id, ",", fixed = TRUE)[[1]]

  dataflow_components <- list(
    agency_id = dataflow_parts[[1]],
    flow_id = dataflow_parts[[2]],
    version = dataflow_parts[[3]]
  )

  return(dataflow_components)
}

build_sdmx_structure_url <- function(dataflow_id,
                                     detail = "Full",
                                     references = "Descendants") {
  dataflow_parts <- split_dataflow_id(dataflow_id)

  structure_url <- paste0(
    "https://nsiws.tuik.gov.tr/rest/dataflow/",
    dataflow_parts$agency_id, "/",
    dataflow_parts$flow_id, "/",
    dataflow_parts$version,
    "?detail=", detail,
    "&references=", references
  )

  return(structure_url)
}

build_sdmx_data_url <- function(dataflow_id,
                                key = "ALL",
                                start = NULL,
                                end = NULL,
                                detail = "full",
                                dimension_at_observation = "TIME_PERIOD") {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  query_parts <- c(
    paste0("detail=", detail),
    paste0("dimensionAtObservation=", dimension_at_observation)
  )

  if (!is.null(start)) {
    query_parts <- c(query_parts, paste0("startPeriod=", start))
  }
  if (!is.null(end)) {
    query_parts <- c(query_parts, paste0("endPeriod=", end))
  }

  data_url <- paste0(
    "https://nsiws.tuik.gov.tr/rest/data/",
    validated_dataflow_id, "/",
    key,
    "/?",
    base::paste(query_parts, collapse = "&")
  )

  return(data_url)
}

read_sdmx_document <- function(file) {
  sdmx_document <- rsdmx::readSDMX(
    file = file,
    isURL = TRUE,
    validate = FALSE,
    verbose = FALSE
  )

  return(sdmx_document)
}

normalize_sdmx_data <- function(sdmx_document) {
  sdmx_data_frame <- base::as.data.frame(sdmx_document, stringsAsFactors = FALSE)
  sdmx_tibble <- tibble::as_tibble(sdmx_data_frame)

  normalized_tibble <- dplyr::mutate(
    sdmx_tibble,
    dplyr::across(dplyr::where(base::is.character), stringr::str_trim)
  )

  return(normalized_tibble)
}

build_statistical_portal_request <- function(lang = "tr") {
  if (!is.character(lang) || length(lang) != 1 || !(lang %in% c("tr", "en"))) {
    stop("lang must be one of 'tr' or 'en'.", call. = FALSE)
  }

  accept_language <- switch(
    lang,
    tr = "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    en = "en-US,en;q=0.9,tr-TR;q=0.8,tr;q=0.7"
  )

  request_info <- list(
    page_url = paste0(
      "https://veriportali.tuik.gov.tr/", lang, "/statistical-themes"
    ),
    api_url = paste0(
      "https://veriportali.tuik.gov.tr/api/", lang, "/data/statistical-themes"
    ),
    headers = list(
      Accept = "application/json, text/plain, */*",
      `Accept-Language` = accept_language,
      `User-Agent` = paste(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "AppleWebKit/537.36 (KHTML, like Gecko)",
        "Chrome/122.0.0.0 Safari/537.36"
      )
    )
  )

  return(request_info)
}

fetch_theme_tree <- function(lang = "tr") {
  request_info <- build_statistical_portal_request(lang)

  cookie_file <- tempfile(fileext = ".txt")
  common_opts <- list(
    cookiefile = cookie_file,
    cookiejar = cookie_file
  )

  landing_cli <- crul::HttpClient$new(
    url = request_info$page_url,
    headers = request_info$headers,
    opts = common_opts
  )
  landing_resp <- landing_cli$get()
  landing_resp$raise_for_status()

  api_cli <- crul::HttpClient$new(
    url = request_info$api_url,
    headers = c(
      request_info$headers,
      list(
        Referer = request_info$page_url,
        Origin = "https://veriportali.tuik.gov.tr",
        `X-Requested-With` = "XMLHttpRequest"
      )
    ),
    opts = common_opts
  )

  http_response <- api_cli$get()
  http_response$raise_for_status()

  parsed_json <- jsonlite::fromJSON(
    http_response$parse("UTF-8"),
    simplifyVector = FALSE
  )

  if (isTRUE(parsed_json$isError)) {
    stop("TUIK API returned an error: ", parsed_json$message, call. = FALSE)
  }

  return(parsed_json$data)
}

collect_nodes_by_icon <- function(node_list, target_icons) {
  collected_nodes <- list()
  for (node in node_list) {
    if (isTRUE(node[["icon"]] %in% target_icons)) {
      collected_nodes <- c(collected_nodes, list(node))
    }
    child_list <- node[["children"]]
    if (!is.null(child_list) && length(child_list) > 0) {
      collected_nodes <- c(
        collected_nodes,
        collect_nodes_by_icon(child_list, target_icons)
      )
    }
  }
  return(collected_nodes)
}

normalize_statistical_url <- function(raw_url) {
  if (grepl("^https?://", raw_url)) {
    return(raw_url)
  }

  return(paste0("https://veriportali.tuik.gov.tr", raw_url))
}

extract_dataflow_id <- function(raw_url) {
  return(stringr::str_extract(raw_url, "[^/]+$"))
}

build_statistical_table_tibble <- function(theme_node) {
  table_nodes <- collect_nodes_by_icon(
    theme_node[["children"]],
    c("istab", "dataflow")
  )

  if (length(table_nodes) == 0) {
    return(tibble::tibble(
      theme_name = character(0),
      theme_id = character(0),
      table_name = character(0),
      node_type = character(0),
      dataflow_id = character(0),
      table_url = character(0)
    ))
  }

  node_type_vec <- purrr::map_chr(table_nodes, "icon")
  raw_urls <- purrr::map_chr(table_nodes, "url")

  table_rows <- tibble::tibble(
    theme_name = theme_node[["name"]],
    theme_id = as.character(theme_node[["id"]]),
    table_name = purrr::map_chr(table_nodes, "name"),
    node_type = node_type_vec,
    dataflow_id = unname(ifelse(
      node_type_vec == "dataflow",
      vapply(raw_urls, extract_dataflow_id, character(1)),
      NA_character_
    )),
    table_url = unname(vapply(raw_urls, normalize_statistical_url, character(1)))
  )

  return(table_rows)
}

build_statistical_database_tibble <- function(theme_node) {
  database_nodes <- collect_nodes_by_icon(
    theme_node[["children"]],
    "database"
  )

  if (length(database_nodes) == 0) {
    return(tibble::tibble(
      theme_name = character(0),
      theme_id = character(0),
      db_name = character(0),
      db_url = character(0)
    ))
  }

  database_rows <- tibble::tibble(
    theme_name = theme_node[["name"]],
    theme_id = as.character(theme_node[["id"]]),
    db_name = purrr::map_chr(database_nodes, "name"),
    db_url = purrr::map_chr(database_nodes, "url")
  )

  return(database_rows)
}

validate_theme <- function(theme, theme_tree) {
  theme_id_chr <- as.character(theme)
  top_level_ids <- purrr::map_chr(theme_tree, ~ as.character(.x[["id"]]))

  if (length(theme) != 1 || !(theme_id_chr %in% top_level_ids)) {
    sthemes_tbl <- tibble::tibble(
      theme_name = purrr::map_chr(theme_tree, "name"),
      theme_id   = top_level_ids
    )
    message(crayon::blue("Valid themes and IDs are:"))
    print(sthemes_tbl)
    if (length(theme) != 1) {
      stop(crayon::red("You can select only one theme!"))
    } else {
      stop(crayon::red("You should select a valid theme ID!"))
    }
  }

  theme_idx <- which(top_level_ids == theme_id_chr)
  return(theme_tree[[theme_idx]])
}
