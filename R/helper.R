#' Helper functions
#'
#' @keywords internal
#' @name helpers
NULL

#' @noRd
#' @keywords internal
validate_string_single <- function(value, arg_name, allowed_values = NULL) {
  if (!is.character(value) || length(value) != 1 || is.na(value)) {
    stop(arg_name, " must be a single non-NA character string.", call. = FALSE)
  }
  if (!is.null(allowed_values) && !(value %in% allowed_values)) {
    stop(
      arg_name, " must be one of: ", paste(allowed_values, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  return(value)
}

#' @noRd
#' @keywords internal
validate_dataflow_id <- function(dataflow_id) {
  validated_dataflow_id <- validate_string_single(dataflow_id, "dataflow_id")

  dataflow_parts <- strsplit(validated_dataflow_id, ",", fixed = TRUE)[[1]]
  if (length(dataflow_parts) != 3 || any(nchar(dataflow_parts) == 0)) {
    stop(
      paste(
        "dataflow_id must be a single SDMX identifier with three",
        "comma-separated parts like 'TR,DF_UHTI_COGRAFI,1.0'."
      ),
      call. = FALSE
    )
  }

  return(validated_dataflow_id)
}

#' @noRd
#' @keywords internal
validate_statistical_lang <- function(lang) {
  return(validate_string_single(lang, "lang", allowed_values = c("tr", "en")))
}

#' @noRd
#' @keywords internal
format_valid_theme_choices <- function(theme_tree) {
  valid_theme_table <- tibble::tibble(
    theme_name = purrr::map_chr(theme_tree, "name"),
    theme_id = purrr::map_chr(theme_tree, ~ as.character(.x[["id"]]))
  )

  formatted_choices <- paste0(
    valid_theme_table$theme_id,
    " = ",
    valid_theme_table$theme_name
  )

  return(paste(formatted_choices, collapse = "\n"))
}

#' @noRd
#' @keywords internal
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

#' @noRd
#' @keywords internal
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

#' @noRd
#' @keywords internal
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

#' @noRd
#' @keywords internal
read_sdmx_document <- function(file) {
  sdmx_document <- rsdmx::readSDMX(
    file = file,
    isURL = TRUE,
    validate = FALSE,
    verbose = FALSE
  )

  return(sdmx_document)
}

#' Normalize SDMX data to tibble format with trimmed columns.
#'
#' Converts raw rsdmx document output to a cleaned tibble with all
#' character columns trimmed of leading and trailing whitespace.
#'
#' @param sdmx_document SDMX object from \code{rsdmx::readSDMX()}.
#'
#' @return A tibble with character columns trimmed.
#'
#' @noRd
#' @keywords internal
normalize_sdmx_data <- function(sdmx_document) {
  sdmx_data_frame <- as.data.frame(sdmx_document, stringsAsFactors = FALSE)
  sdmx_tibble <- tibble::as_tibble(sdmx_data_frame)

  normalized_tibble <- dplyr::mutate(
    sdmx_tibble,
    dplyr::across(dplyr::where(is.character), stringr::str_trim)
  )

  return(normalized_tibble)
}

#' Clean SDMX long-form data by removing invariant dimensions and adding labels.
#'
#' Removes dimensions that have only a single unique value across all observations
#' (invariant dimensions). For dimensions with available label maps, adds adjacent
#' \code{*_label} columns with human-readable labels when they differ from the
#' original codes.
#'
#' @param sdmx_data Tibble of SDMX observations with dimension and observation columns.
#' @param label_maps List where keys are dimension names and values are named character
#'   vectors mapping codes to labels. Default empty list.
#'
#' @return Tibble with invariant dimensions removed, protected columns (obsTime,
#'   obsValue) repositioned to the end, and \code{*_label} columns added where
#'   labels differ from original codes.
#'
#' @noRd
#' @keywords internal
clean_statistical_long_data <- function(sdmx_data, label_maps = list()) {
  protected_cols <- c("obsTime", "obsValue")
  candidate_cols <- setdiff(names(sdmx_data), protected_cols)
  keep_cols <- purrr::map_lgl(candidate_cols, function(column_name) {
    column_values <- sdmx_data[[column_name]]
    unique_values <- unique(column_values[!is.na(column_values)])
    return(length(unique_values) > 1)
  })

  kept_candidate_cols <- candidate_cols[keep_cols]
  kept_cols <- c(kept_candidate_cols, protected_cols)
  cleaned_long_data <- dplyr::select(sdmx_data, dplyr::all_of(kept_cols))

  if (length(kept_candidate_cols) == 0) {
    return(cleaned_long_data)
  }

  col_pairs <- purrr::map(kept_candidate_cols, function(column_name) {
    base_pair <- stats::setNames(
      list(cleaned_long_data[[column_name]]),
      column_name
    )
    label_map <- label_maps[[column_name]]
    if (is.null(label_map)) {
      return(base_pair)
    }
    label_values <- apply_dimension_label_map(
      cleaned_long_data[[column_name]], column_name, label_maps
    )
    if (!identical(as.character(label_values), as.character(cleaned_long_data[[column_name]]))) {
      label_pair <- stats::setNames(
        list(label_values),
        paste0(column_name, "_label")
      )
      return(c(base_pair, label_pair))
    }
    return(base_pair)
  })

  protected_pairs <- purrr::keep(
    stats::setNames(as.list(protected_cols), protected_cols),
    ~ .x %in% names(cleaned_long_data)
  ) |>
    purrr::imap(~ cleaned_long_data[[.y]])

  return(tibble::as_tibble(c(purrr::list_flatten(col_pairs), protected_pairs)))
}

#' Lookup localized label value from rsdmx language list.
#'
#' Prefer the requested language, then the first available label.
#'
#' @param value List from rsdmx structure (language-keyed).
#' @param lang Language code ("tr" or "en").
#'
#' @return Character string of the label, or NA_character_ if unavailable.
#'
#' @noRd
#' @keywords internal
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

#' Extract dimension code-to-label mappings from SDMX structure.
#'
#' Extract human-readable labels for coded SDMX dimensions.
#'
#' @param raw_sdmx SDMX structure object from \code{rsdmx::readSDMX()}.
#' @param lang Language code for label extraction ("tr" or "en").
#'
#' @return List where keys are dimension concept references and values are
#'   named character vectors mapping codes to labels.
#'
#' @noRd
#' @keywords internal
extract_sdmx_dimension_label_maps <- function(raw_sdmx, lang = "tr") {
  validated_lang <- validate_statistical_lang(lang)
  sdmx_dimensions <- raw_sdmx@datastructures@datastructures[[1]]@Components@Dimensions
  sdmx_codelists <- raw_sdmx@codelists@codelists
  codelist_ids <- purrr::map_chr(sdmx_codelists, ~ .x@id)

  dimension_label_maps <- purrr::map(sdmx_dimensions, function(sdmx_dimension) {
    codelist_id <- sdmx_dimension@codelist
    if (is.na(codelist_id) || !nzchar(codelist_id)) {
      return(NULL)
    }
    codelist_index <- which(codelist_ids == codelist_id)
    if (length(codelist_index) == 0) {
      return(NULL)
    }
    code_entries <- sdmx_codelists[[codelist_index[[1]]]]@Code
    code_ids <- purrr::map_chr(code_entries, ~ .x@id)
    code_labels <- purrr::map_chr(code_entries, function(x) {
      code_label <- lookup_first_localized_value(x@name, validated_lang)
      if (is.na(code_label) || !nzchar(code_label)) {
        code_label <- lookup_first_localized_value(x@label, validated_lang)
      }
      if (is.na(code_label) || !nzchar(code_label)) {
        code_label <- x@id
      }
      return(code_label)
    })
    return(stats::setNames(code_labels, code_ids))
  }) |>
    purrr::set_names(purrr::map_chr(sdmx_dimensions, ~ .x@conceptRef)) |>
    purrr::compact()

  return(dimension_label_maps)
}

#' Apply dimension label mapping to observation values.
#'
#' Maps coded dimension values to human-readable labels using a label map,
#' preserving unmapped values as strings.
#'
#' @param values Character vector of dimension codes.
#' @param dimension_name Character string. Dimension name to look up in label_maps.
#' @param label_maps List of label maps (from \code{extract_sdmx_dimension_label_maps()}).
#'
#' @return Character vector with mapped labels where available, original values otherwise.
#'
#' @noRd
#' @keywords internal
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

#' @noRd
#' @keywords internal
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

#' Fetch theme tree from TUIK statistical portal API.
#'
#' Makes authenticated request to the TUIK veriportali API to retrieve
#' the full hierarchical theme structure. Uses cookie-based session handling
#' to access portal resources.
#'
#' @param lang Language code ("tr" or "en").
#'
#' @return List representing the JSON theme tree structure.
#'
#' @noRd
#' @keywords internal
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

#' Recursively collect theme nodes by icon type.
#'
#' Traverses a hierarchical theme tree structure to find all nodes matching
#' one of the target icon types. Used to extract resource nodes from the
#' TUIK theme tree.
#'
#' @param node_list List of nodes from theme tree, each with optional \code{icon}
#'   and \code{children} fields.
#' @param target_icons Character vector of icon types to match (e.g.,
#'   \code{c("dataflow", "database")}).
#'
#' @return List of nodes matching the target icons (flattened from tree structure).
#'
#' @noRd
#' @keywords internal
collect_nodes_by_icon <- function(node_list, target_icons) {
  purrr::map(node_list, function(node) {
    matched <- if (isTRUE(node[["icon"]] %in% target_icons)) list(node) else list()
    child_list <- node[["children"]]
    children_matched <- if (!is.null(child_list) && length(child_list) > 0) {
      collect_nodes_by_icon(child_list, target_icons)
    } else {
      list()
    }
    return(c(matched, children_matched))
  }) |>
    purrr::list_flatten()
}

#' Normalize portal URLs to absolute form.
#'
#' Prepends the TUIK portal base URL to relative paths, passes through
#' absolute URLs unchanged.
#'
#' @param raw_url Character string. URL from portal JSON (may be relative).
#'
#' @return Character string. Absolute TUIK portal URL.
#'
#' @noRd
#' @keywords internal
normalize_statistical_url <- function(raw_url) {
  if (grepl("^https?://", raw_url)) {
    return(raw_url)
  }

  return(paste0("https://veriportali.tuik.gov.tr", raw_url))
}

#' Extract SDMX dataflow ID from databrowser URL.
#'
#' Extracts the dataflow identifier (last path component) from a
#' TUIK databrowser URL.
#'
#' @param raw_url Character string. TUIK databrowser URL.
#'
#' @return Character string. SDMX dataflow ID (e.g., "TR,DF_CRIME,1.0").
#'
#' @noRd
#' @keywords internal
extract_dataflow_id <- function(raw_url) {
  return(stringr::str_extract(raw_url, "[^/]+$"))
}

#' @noRd
#' @keywords internal
validate_statistical_sdmx_text <- function(value, argument_name) {
  return(validate_string_single(value, argument_name))
}

#' @noRd
#' @keywords internal
validate_statistical_sdmx_key <- function(key) {
  validated_key <- validate_statistical_sdmx_text(key, "key")
  if (!nzchar(validated_key)) {
    stop("key must not be empty.", call. = FALSE)
  }
  return(validated_key)
}

#' @noRd
#' @keywords internal
validate_statistical_sdmx_optional_text <- function(value, argument_name) {
  if (is.null(value)) {
    return(value)
  }
  return(validate_statistical_sdmx_text(value, argument_name))
}

#' @noRd
#' @keywords internal
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

#' Build resource tibble from theme node.
#'
#' Extracts all resource nodes (dataflows, databases, files, press releases,
#' reports) from a theme tree node and returns a structured tibble mapping
#' resource metadata.
#'
#' @param theme_node List from theme tree with \code{id}, \code{name}, and
#'   \code{children} fields.
#'
#' @return Tibble with 6 columns: theme_name, theme_id, resource_name,
#'   resource_type, dataflow_id (for dataflow resources), resource_url.
#'
#' @noRd
#' @keywords internal
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
    dataflow_id = dplyr::if_else(
      resource_type_vec == "dataflow",
      purrr::map_chr(raw_urls, extract_dataflow_id),
      NA_character_
    ),
    resource_url = purrr::map_chr(raw_urls, normalize_statistical_url)
  )

  return(resource_rows)
}

#' Validate and extract theme node from theme tree.
#'
#' Checks that the theme argument is a single valid ID and returns the
#' corresponding theme node. Displays available themes if validation fails.
#'
#' @param theme Numeric or character. Theme ID to validate.
#' @param theme_tree List from \code{fetch_theme_tree()}.
#'
#' @return List representing the theme node.
#'
#' @noRd
#' @keywords internal
validate_theme <- function(theme, theme_tree) {
  if (length(theme) != 1 || is.na(theme)) {
    stop("theme must be a single theme ID.", call. = FALSE)
  }

  theme_id_chr <- as.character(theme)
  top_level_ids <- purrr::map_chr(theme_tree, ~ as.character(.x[["id"]]))

  if (!(theme_id_chr %in% top_level_ids)) {
    stop(
      paste(
        "theme must be one of the available theme IDs:",
        format_valid_theme_choices(theme_tree),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  theme_idx <- which(top_level_ids == theme_id_chr)
  return(theme_tree[[theme_idx]])
}
