test_that("statistical_data validates dataflow_id before any network call", {
  expect_error(
    tuikr:::statistical_data("bad-id"),
    "dataflow_id must"
  )
})

test_that("statistical_data_structure validates dataflow_id before any network call", {
  expect_error(
    tuikr:::statistical_data_structure("bad-id"),
    "dataflow_id must"
  )
})

test_that("statistical_data downloads a TUIK SDMX dataset", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()

  uhti_data <- tuikr:::statistical_data(
    dataflow_id = "TR,DF_UHTI_COGRAFI,1.0",
    key = "TR....../ALL"
  )

  expect_s3_class(uhti_data, "tbl_df")
  expect_true(nrow(uhti_data) > 0)
  expect_true(all(c("obsTime", "obsValue") %in% names(uhti_data)))
})

test_that("statistical_data_structure downloads TUIK SDMX metadata", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()

  structure_info <- tuikr:::statistical_data_structure("TR,DF_UHTI_COGRAFI,1.0")

  expect_type(structure_info, "list")
  expect_true(all(c("dataflow_id", "structure_url", "raw_sdmx") %in% names(structure_info)))
  expect_true(inherits(structure_info$raw_sdmx, "SDMXDataStructureDefinition"))
})
