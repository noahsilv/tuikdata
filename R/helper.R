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

validate_statistical_lang <- function(lang) {
  if (!is.character(lang) || length(lang) != 1 || !(lang %in% c("tr", "en"))) {
    stop("lang must be one of 'tr' or 'en'.", call. = FALSE)
  }

  return(lang)
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

clean_statistical_long_data <- function(sdmx_data) {
  protected_cols <- c("obsTime", "obsValue")
  candidate_cols <- setdiff(names(sdmx_data), protected_cols)
  keep_cols <- vapply(
    candidate_cols,
    function(column_name) {
      column_values <- sdmx_data[[column_name]]
      unique_values <- unique(column_values[!is.na(column_values)])

      return(length(unique_values) > 1)
    },
    logical(1)
  )

  kept_candidate_cols <- candidate_cols[keep_cols]
  kept_cols <- names(sdmx_data)[names(sdmx_data) %in% c(kept_candidate_cols, protected_cols)]

  return(dplyr::select(sdmx_data, dplyr::all_of(kept_cols)))
}

build_databrowser_structure_url <- function(dataflow_id, lang = "tr") {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  validated_lang <- validate_statistical_lang(lang)

  return(paste0(
    "https://databrowser2.tuik.gov.tr/api/core/nodes/1/datasets/",
    validated_dataflow_id,
    "/structure?locale=",
    validated_lang
  ))
}

fetch_databrowser_structure <- function(dataflow_id, lang = "tr") {
  structure_url <- build_databrowser_structure_url(dataflow_id, lang)
  http_response <- crul::HttpClient$new(
    url = structure_url,
    headers = list(
      Accept = "application/json, text/plain, */*"
    )
  )$get()
  http_response$raise_for_status()

  return(jsonlite::fromJSON(
    http_response$parse("UTF-8"),
    simplifyVector = FALSE
  ))
}

extract_databrowser_table_layout <- function(structure_payload) {
  layout_payload <- structure_payload$template$layouts
  parsed_layout <- jsonlite::fromJSON(layout_payload, simplifyVector = FALSE)
  table_layout <- parsed_layout$tableLayout
  table_filters <- table_layout$filters
  table_filter_values <- table_layout$filtersValue

  if (is.null(table_filters)) {
    table_filters <- character(0)
  }
  if (is.null(table_filter_values)) {
    table_filter_values <- list()
  }

  table_filters <- unname(unlist(table_filters, use.names = FALSE))
  if (is.null(table_filters)) {
    table_filters <- character(0)
  }

  return(list(
    rows = unname(unlist(table_layout$rows, use.names = FALSE)),
    cols = unname(unlist(table_layout$cols, use.names = FALSE)),
    filters = table_filters,
    filters_value = unname(table_filter_values)
  ))
}

lookup_first_localized_value <- function(value, lang) {
  if (!is.list(value) || length(value) == 0) {
    return(NA_character_)
  }

  if (!is.null(value[[lang]]) && length(value[[lang]]) == 1 && !is.na(value[[lang]])) {
    return(as.character(value[[lang]]))
  }

  flattened_values <- unlist(value, use.names = FALSE)
  flattened_values <- flattened_values[!is.na(flattened_values)]
  if (length(flattened_values) == 0) {
    return(NA_character_)
  }

  return(as.character(flattened_values[[1]]))
}

extract_sdmx_dimension_label_maps <- function(raw_sdmx, lang = "tr") {
  validated_lang <- validate_statistical_lang(lang)
  sdmx_dimensions <- raw_sdmx@datastructures@datastructures[[1]]@Components@Dimensions
  sdmx_codelists <- raw_sdmx@codelists@codelists
  codelist_ids <- vapply(sdmx_codelists, function(x) x@id, character(1))
  label_maps <- list()

  for (sdmx_dimension in sdmx_dimensions) {
    codelist_id <- sdmx_dimension@codelist
    if (is.na(codelist_id) || !nzchar(codelist_id)) {
      next
    }

    codelist_index <- which(codelist_ids == codelist_id)
    if (length(codelist_index) == 0) {
      next
    }

    code_entries <- sdmx_codelists[[codelist_index[[1]]]]@Code
    code_ids <- vapply(code_entries, function(x) x@id, character(1))
    code_labels <- vapply(
      code_entries,
      function(x) {
        code_label <- lookup_first_localized_value(x@name, validated_lang)
        if (is.na(code_label) || !nzchar(code_label)) {
          code_label <- lookup_first_localized_value(x@label, validated_lang)
        }
        if (is.na(code_label) || !nzchar(code_label)) {
          code_label <- x@id
        }
        return(code_label)
      },
      character(1)
    )

    label_maps[[sdmx_dimension@conceptRef]] <- stats::setNames(code_labels, code_ids)
  }

  return(label_maps)
}

normalize_layout_dimension_name <- function(dimension_name, data_names) {
  if (dimension_name == "TIME_PERIOD" && "obsTime" %in% data_names) {
    return("obsTime")
  }

  return(dimension_name)
}

apply_dimension_label_map <- function(values, dimension_name, label_maps) {
  label_map <- label_maps[[dimension_name]]
  if (is.null(label_map)) {
    return(values)
  }

  mapped_values <- unname(label_map[as.character(values)])
  missing_labels <- is.na(mapped_values)
  mapped_values[missing_labels] <- as.character(values[missing_labels])

  return(mapped_values)
}

build_statistical_data_table <- function(sdmx_data, table_layout, label_maps = list()) {
  data_names <- names(sdmx_data)
  row_dims_actual <- unname(vapply(
    table_layout$rows,
    normalize_layout_dimension_name,
    character(1),
    data_names = data_names
  ))
  col_dims_actual <- unname(vapply(
    table_layout$cols,
    normalize_layout_dimension_name,
    character(1),
    data_names = data_names
  ))
  filter_dims_actual <- unname(vapply(
    names(table_layout$filters_value),
    normalize_layout_dimension_name,
    character(1),
    data_names = data_names
  ))

  filtered_data <- sdmx_data
  if (length(filter_dims_actual) > 0) {
    for (i in seq_along(filter_dims_actual)) {
      filter_dim <- filter_dims_actual[[i]]
      filter_value <- table_layout$filters_value[[i]]
      if (filter_dim %in% names(filtered_data)) {
        filtered_data <- dplyr::filter(
          filtered_data,
          .data[[filter_dim]] == filter_value
        )
      }
    }
  }

  used_dims_actual <- unique(c(row_dims_actual, col_dims_actual, filter_dims_actual))
  candidate_dimension_cols <- setdiff(
    names(filtered_data),
    c("obsValue", "CONF_STATUS", "UNIT_MEASURE")
  )
  extra_dimension_cols <- setdiff(candidate_dimension_cols, used_dims_actual)
  varying_extra_cols <- extra_dimension_cols[vapply(
    filtered_data[extra_dimension_cols],
    function(x) length(unique(x[!is.na(x)])) > 1,
    logical(1)
  )]

  if (length(varying_extra_cols) > 0) {
    stop(
      "Cannot construct a table layout because multiple unconstrained dimensions remain: ",
      paste(varying_extra_cols, collapse = ", "),
      ". Supply a narrower SDMX key or use layout = 'long'.",
      call. = FALSE
    )
  }

  labeled_data <- filtered_data
  for (dimension_name in unique(c(row_dims_actual, col_dims_actual))) {
    if (dimension_name %in% names(labeled_data)) {
      source_dimension_name <- if (dimension_name == "obsTime") {
        "TIME_PERIOD"
      } else {
        dimension_name
      }
      labeled_data[[dimension_name]] <- apply_dimension_label_map(
        labeled_data[[dimension_name]],
        source_dimension_name,
        label_maps
      )
    }
  }

  if (length(col_dims_actual) == 0) {
    return(dplyr::select(labeled_data, dplyr::all_of(c(row_dims_actual, "obsValue"))))
  }

  wide_table <- tidyr::pivot_wider(
    labeled_data,
    id_cols = dplyr::all_of(row_dims_actual),
    names_from = dplyr::all_of(col_dims_actual),
    values_from = "obsValue",
    names_sep = " | "
  )

  rename_map <- stats::setNames(
    row_dims_actual,
    table_layout$rows
  )
  rename_map <- rename_map[unname(rename_map) %in% names(wide_table)]

  if (length(rename_map) > 0) {
    wide_table <- dplyr::rename(wide_table, !!!rename_map)
  }

  return(wide_table)
}

build_statistical_portal_request <- function(lang = "tr") {
  validated_lang <- validate_statistical_lang(lang)

  accept_language <- switch(
    validated_lang,
    tr = "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    en = "en-US,en;q=0.9,tr-TR;q=0.8,tr;q=0.7"
  )

  request_info <- list(
    page_url = paste0(
      "https://veriportali.tuik.gov.tr/", validated_lang, "/statistical-themes"
    ),
    api_url = paste0(
      "https://veriportali.tuik.gov.tr/api/", validated_lang, "/data/statistical-themes"
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

validate_statistical_resource_types <- function(type) {
  valid_types <- c("press", "database", "istab", "dataflow", "report")

  if (is.null(type)) {
    return(type)
  }

  if (!is.character(type) || length(type) == 0 || any(is.na(type))) {
    stop(
      "type must be NULL or a character vector of supported resource types.",
      call. = FALSE
    )
  }

  if (!all(type %in% valid_types)) {
    stop(
      "type must be one or more of: press, database, istab, dataflow, report.",
      call. = FALSE
    )
  }

  return(unique(type))
}

build_statistical_resource_tibble <- function(theme_node) {
  resource_nodes <- collect_nodes_by_icon(
    theme_node[["children"]],
    c("press", "database", "istab", "dataflow", "report")
  )

  if (length(resource_nodes) == 0) {
    return(tibble::tibble(
      theme_name = character(0),
      theme_id = character(0),
      resource_name = character(0),
      resource_type = character(0),
      dataflow_id = character(0),
      resource_url = character(0)
    ))
  }

  resource_type_vec <- purrr::map_chr(resource_nodes, "icon")
  raw_urls <- purrr::map_chr(resource_nodes, "url")

  resource_rows <- tibble::tibble(
    theme_name = theme_node[["name"]],
    theme_id = as.character(theme_node[["id"]]),
    resource_name = purrr::map_chr(resource_nodes, "name"),
    resource_type = resource_type_vec,
    dataflow_id = unname(ifelse(
      resource_type_vec == "dataflow",
      vapply(raw_urls, extract_dataflow_id, character(1)),
      NA_character_
    )),
    resource_url = unname(vapply(raw_urls, normalize_statistical_url, character(1)))
  )

  return(resource_rows)
}

build_statistical_table_tibble <- function(theme_node) {
  resource_rows <- build_statistical_resource_tibble(theme_node)
  table_rows <- dplyr::filter(
    resource_rows,
    .data$resource_type %in% c("dataflow", "istab")
  )

  return(dplyr::transmute(
    table_rows,
    theme_name = .data$theme_name,
    theme_id = .data$theme_id,
    table_name = .data$resource_name,
    node_type = .data$resource_type,
    dataflow_id = .data$dataflow_id,
    table_url = .data$resource_url
  ))
}

build_statistical_database_tibble <- function(theme_node) {
  resource_rows <- build_statistical_resource_tibble(theme_node)
  database_rows <- dplyr::filter(
    resource_rows,
    .data$resource_type == "database"
  )

  return(dplyr::transmute(
    database_rows,
    theme_name = .data$theme_name,
    theme_id = .data$theme_id,
    db_name = .data$resource_name,
    db_url = .data$resource_url
  ))
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
