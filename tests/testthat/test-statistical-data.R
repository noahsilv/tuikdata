test_that("statistical_data validates dataflow_id before any network call", {
  expect_error(
    statistical_data("bad-id"),
    "dataflow_id must be a single SDMX identifier"
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
  skip_if_offline()

  uhti_data <- statistical_data(
    dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
    key = "TR....../ALL"
  )

  expect_s3_class(uhti_data, "tbl_df")
  expect_true(nrow(uhti_data) > 0)
  expect_true(all(c("REF_AREA", "obsTime", "obsValue") %in% names(uhti_data)))
})

test_that("statistical_data can return the browser's default table layout", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()

  birth_table <- statistical_data(
    dataflow_id = "TR,DF_DOGUM_IL_YASA_OZEL_DOGHIZ,1.0",
    layout = "table",
    lang = "en"
  )

  expect_s3_class(birth_table, "tbl_df")
  expect_true("TIME_PERIOD" %in% names(birth_table))
  expect_true(any(grepl("Turkey \\| 15-19", names(birth_table))))
  expect_true(nrow(birth_table) > 0)
})

test_that("internal structure helper downloads TUIK SDMX metadata", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
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
    "lang must be one of 'tr' or 'en'"
  )
  expect_error(
    statistical_data("TR,DF_UHTI_COGRAFI,1.0", layout = "matrix"),
    "'arg' should be one of"
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
