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

  dataflow_parts <- strsplit(dataflow_id, ",", fixed = TRUE)[[1]]
  if (length(dataflow_parts) != 3 || any(nchar(dataflow_parts) == 0)) {
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

  if (!nzchar(key)) {
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

split_dataflow_id <- function(dataflow_id) {
  validated_dataflow_id <- validate_dataflow_id(dataflow_id)
  dataflow_parts <- strsplit(validated_dataflow_id, ",", fixed = TRUE)[[1]]

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
    paste(query_parts, collapse = "&")
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
  sdmx_tibble <- tibble::as_tibble(
    as.data.frame(sdmx_document, stringsAsFactors = FALSE)
  )

  dplyr::mutate(
    sdmx_tibble,
    dplyr::across(dplyr::where(is.character), stringr::str_trim)
  )
}

clean_statistical_long_data <- function(sdmx_data, label_maps = list()) {
  protected_cols <- c("obsTime", "obsValue")
  candidate_cols <- setdiff(names(sdmx_data), protected_cols)

  keep_cols <- purrr::map_lgl(
    candidate_cols,
    ~ length(unique(sdmx_data[[.x]][!is.na(sdmx_data[[.x]])])) > 1
  )

  kept_candidate_cols <- candidate_cols[keep_cols]
  kept_cols <- c(kept_candidate_cols, intersect(protected_cols, names(sdmx_data)))
  cleaned_long_data <- dplyr::select(sdmx_data, dplyr::all_of(kept_cols))

  if (length(kept_candidate_cols) == 0) {
    return(cleaned_long_data)
  }

  # Compute optional _label columns for coded dimensions.
  # A label column is added only when the label map exists and produces values
  # that differ from the raw codes (i.e., there is something to decode).
  label_additions <- purrr::imap(
    cleaned_long_data[kept_candidate_cols],
    function(col_values, col_name) {
      if (is.null(label_maps[[col_name]])) return(NULL)
      label_values <- apply_dimension_label_map(col_values, col_name, label_maps)
      if (identical(as.character(label_values), as.character(col_values))) return(NULL)
      label_values
    }
  ) |>
    purrr::compact()

  names(label_additions) <- paste0(names(label_additions), "_label")

  # Interleave each code column with its label counterpart (if any), then
  # append the protected observation columns.
  output_cols <- purrr::map(kept_candidate_cols, function(col_name) {
    col_list <- stats::setNames(list(cleaned_long_data[[col_name]]), col_name)
    label_col_name <- paste0(col_name, "_label")
    if (label_col_name %in% names(label_additions)) {
      col_list[[label_col_name]] <- label_additions[[label_col_name]]
    }
    col_list
  }) |>
    purrr::flatten()

  protected_out <- purrr::set_names(
    purrr::map(
      intersect(protected_cols, names(cleaned_long_data)),
      ~ cleaned_long_data[[.x]]
    ),
    intersect(protected_cols, names(cleaned_long_data))
  )

  tibble::as_tibble(c(output_cols, protected_out))
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
  codelist_ids <- purrr::map_chr(sdmx_codelists, ~ .x@id)

  resolve_code_label <- function(x) {
    code_label <- lookup_first_localized_value(x@name, validated_lang)
    if (is.na(code_label) || !nzchar(code_label)) {
      code_label <- lookup_first_localized_value(x@label, validated_lang)
    }
    if (is.na(code_label) || !nzchar(code_label)) {
      code_label <- x@id
    }
    code_label
  }

  label_maps <- purrr::map(sdmx_dimensions, function(dim) {
    codelist_id <- dim@codelist
    if (is.na(codelist_id) || !nzchar(codelist_id)) return(NULL)

    codelist_index <- which(codelist_ids == codelist_id)
    if (length(codelist_index) == 0) return(NULL)

    code_entries <- sdmx_codelists[[codelist_index[[1]]]]@Code
    code_ids <- purrr::map_chr(code_entries, ~ .x@id)
    code_labels <- purrr::map_chr(code_entries, resolve_code_label)

    stats::setNames(code_labels, code_ids)
  }) |>
    purrr::set_names(purrr::map_chr(sdmx_dimensions, ~ .x@conceptRef)) |>
    purrr::compact()

  label_maps
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

  tibble::tibble(
    theme_name = theme_node[["name"]],
    theme_id = as.character(theme_node[["id"]]),
    resource_name = purrr::map_chr(resource_nodes, "name"),
    resource_type = resource_type_vec,
    dataflow_id = ifelse(
      resource_type_vec == "dataflow",
      purrr::map_chr(raw_urls, extract_dataflow_id),
      NA_character_
    ),
    resource_url = purrr::map_chr(raw_urls, normalize_statistical_url)
  )
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
