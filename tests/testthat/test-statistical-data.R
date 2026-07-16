test_that("statistical_data validates dataflow_id before any network call", {
  expect_error(
    statistical_data("bad-id"),
    "dataflow_id must be a single SDMX identifier"
  )
})

test_that("statistical_data adds label columns for coded dimensions", {
  testthat::local_mocked_bindings(
    read_sdmx_document = function(file) {
      return(file)
    },
    normalize_sdmx_data = function(sdmx_document) {
      return(tibble::tibble(
        ADNKS_GOSTERGE = c("COCUK_BAG_ORAN", "TOP_YAS_BAG_ORAN", "YASLI_BAG_ORAN"),
        obsTime = c("2023", "2023", "2023"),
        obsValue = c(31.39, 46.34, 14.95)
      ))
    },
    statistical_data_structure = function(dataflow_id,
                                          detail = "Full",
                                          references = "Descendants") {
      return(list(raw_sdmx = list()))
    },
    extract_sdmx_dimension_label_maps = function(raw_sdmx, lang = "en") {
      return(list(
        ADNKS_GOSTERGE = c(
          COCUK_BAG_ORAN = "Child dependency ratio % (0-14 years)",
          TOP_YAS_BAG_ORAN = "Total age dependency ratio (%)",
          YASLI_BAG_ORAN = "Elderly dependency ratio % (65+ years)"
        )
      ))
    },
    .package = "tuikr"
  )

  long_data <- statistical_data("TR,DF_ADNKS_ORAN,1.0")

  expect_named(
    long_data,
    c("ADNKS_GOSTERGE", "ADNKS_GOSTERGE_label", "obsTime", "obsValue")
  )
  expect_equal(
    long_data$ADNKS_GOSTERGE_label,
    c(
      "Child dependency ratio % (0-14 years)",
      "Total age dependency ratio (%)",
      "Elderly dependency ratio % (65+ years)"
    )
  )
})

test_that("internal structure helper validates dataflow_id before any network call", {
  expect_error(
    tuikr:::statistical_data_structure("bad-id"),
    "dataflow_id must be a single SDMX identifier"
  )
})

test_that("statistical_data downloads a TUIK SDMX dataset", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_not(
    nzchar(Sys.getenv("TUIK_API_KEY")),
    "Set TUIK_API_KEY to run authenticated TUIK SDMX tests."
  )
  skip_if_offline()

  uhti_data <- statistical_data(
    dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
    key = "TR....../ALL"
  )

  expect_s3_class(uhti_data, "tbl_df")
  expect_true(nrow(uhti_data) > 0)
  expect_true(all(c("obsTime", "obsValue") %in% names(uhti_data)))
  expect_true(length(setdiff(names(uhti_data), c("obsTime", "obsValue"))) >= 1)
})

test_that("internal structure helper downloads TUIK SDMX metadata", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_not(
    nzchar(Sys.getenv("TUIK_API_KEY")),
    "Set TUIK_API_KEY to run authenticated TUIK SDMX tests."
  )
  skip_if_offline()

  structure_info <- tuikr:::statistical_data_structure("TR,DF_UHTI_COGRAFI,1.0")

  expect_type(structure_info, "list")
  expect_true(all(c("dataflow_id", "structure_url", "raw_sdmx") %in% names(structure_info)))
})

test_that("statistical_data validates SDMX arguments before URL construction", {
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", key = c("TR", "ALL")),
    "key must be a single non-NA character string"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", key = NA_character_),
    "key must be a single non-NA character string"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", key = ""),
    "key must not be empty"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", detail = c("full", "all")),
    "detail must be a single non-NA character string"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", dimension_at_observation = NA_character_),
    "dimension_at_observation must be a single non-NA character string"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", start = c("2020", "2021")),
    "start must be a single non-NA character string"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", end = NA_character_),
    "end must be a single non-NA character string"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", lang = "de"),
    "lang must be one of:"
  )
})

test_that("internal structure helper validates SDMX arguments before URL construction", {
  expect_error(
    tuikr:::statistical_data_structure("TR,DF_UHTI_COGRAFI,1.0", detail = c("Full", "Full")),
    "detail must be a single non-NA character string"
  )
  expect_error(
    tuikr:::statistical_data_structure("TR,DF_UHTI_COGRAFI,1.0", references = NA_character_),
    "references must be a single non-NA character string"
  )
})
