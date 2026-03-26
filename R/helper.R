#' Helper functions
#'
#' @keywords internal
#' @name helpers
NULL

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
