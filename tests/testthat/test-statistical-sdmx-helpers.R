theme_tree_fixture <- list(
  list(
    id = 17,
    name = "International Services Trade",
    children = list(
      list(
        id = "DF_UHTI_COGRAFI",
        name = "International Services Trade by Country Group",
        icon = "dataflow",
        url = "https://databrowser2.tuik.gov.tr/#/tr/tuik/categories/17/17_1/17_1_1/TR,DF_UHTI_COGRAFI,1.0"
      ),
      list(
        id = "DB_UHTI_COGRAFI",
        name = "Legacy database",
        icon = "database",
        url = "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr"
      )
    )
  )
)

test_that("validate_dataflow_id rejects malformed values", {
  expect_error(
    tuikr:::validate_dataflow_id(1),
    "dataflow_id must be a single character string"
  )
  expect_error(
    tuikr:::validate_dataflow_id("bad-id"),
    "dataflow_id must have three comma-separated parts"
  )
})

test_that("split_dataflow_id parses the agency, flow, and version", {
  dataflow_parts <- tuikr:::split_dataflow_id("TR,DF_UHTI_COGRAFI,1.0")

  expect_equal(
    dataflow_parts,
    list(
      agency_id = "TR",
      flow_id = "DF_UHTI_COGRAFI",
      version = "1.0"
    )
  )
})

test_that("build_sdmx_structure_url returns the TUIK structure endpoint", {
  structure_url <- tuikr:::build_sdmx_structure_url("TR,DF_UHTI_COGRAFI,1.0")

  expect_equal(
    structure_url,
    "https://nsiws.tuik.gov.tr/rest/dataflow/TR/DF_UHTI_COGRAFI/1.0?detail=Full&references=Descendants"
  )
})

test_that("build_sdmx_data_url returns the TUIK data endpoint", {
  data_url <- tuikr:::build_sdmx_data_url(
    "TR,DF_UHTI_COGRAFI,1.0",
    key = "TR....../ALL"
  )

  expect_true(grepl("^https://nsiws\\.tuik\\.gov\\.tr/rest/data/TR,DF_UHTI_COGRAFI,1\\.0/", data_url))
  expect_true(grepl("/TR\\.\\.+/ALL/\\?", data_url))
  expect_true(grepl("detail=full", data_url, fixed = TRUE))
  expect_true(grepl("dimensionAtObservation=TIME_PERIOD", data_url, fixed = TRUE))
})

test_that("normalize_sdmx_data trims character columns from tabular inputs", {
  tabular_input <- data.frame(
    REF_AREA = c(" TR ", " TR "),
    obsTime = c(" 2016 ", " 2017 "),
    obsValue = c(" 174.4 ", " 170.1 "),
    stringsAsFactors = FALSE
  )

  normalized_data <- tuikr:::normalize_sdmx_data(tabular_input)

  expect_s3_class(normalized_data, "tbl_df")
  expect_equal(normalized_data$REF_AREA, c("TR", "TR"))
  expect_equal(normalized_data$obsTime, c("2016", "2017"))
  expect_equal(normalized_data$obsValue, c("174.4", "170.1"))
})

test_that("build helpers derive rows from the theme tree", {
  table_rows <- tuikr:::build_statistical_table_tibble(theme_tree_fixture[[1]])
  database_rows <- tuikr:::build_statistical_database_tibble(theme_tree_fixture[[1]])

  expect_equal(table_rows$theme_id, "17")
  expect_equal(table_rows$node_type, "dataflow")
  expect_true(grepl("^https://databrowser2\\.tuik\\.gov\\.tr/#/tr/tuik/categories/", table_rows$table_url))
  expect_equal(database_rows$db_url, "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr")
})
