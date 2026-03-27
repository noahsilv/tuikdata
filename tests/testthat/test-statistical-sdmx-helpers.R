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

databrowser_structure_fixture <- list(
  template = list(
    layouts = '{"tableLayout":{"rows":["TIME_PERIOD"],"cols":["REF_AREA","ANNE_YAS_GRUP"],"filters":[],"filtersValue":{}}}'
  )
)

test_that("validate_dataflow_id rejects malformed values", {
  expect_error(
    tuikr:::validate_dataflow_id(1),
    "dataflow_id must be a single SDMX identifier"
  )
  expect_error(
    tuikr:::validate_dataflow_id("bad-id"),
    "dataflow_id must be a single SDMX identifier"
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

test_that("build_databrowser_structure_url returns the databrowser structure endpoint", {
  structure_url <- tuikr:::build_databrowser_structure_url(
    "TR,DF_DOGUM_IL_YASA_OZEL_DOGHIZ,1.0",
    lang = "en"
  )

  expect_equal(
    structure_url,
    paste0(
      "https://databrowser2.tuik.gov.tr/api/core/nodes/1/datasets/",
      "TR,DF_DOGUM_IL_YASA_OZEL_DOGHIZ,1.0/structure?locale=en"
    )
  )
})

test_that("extract_databrowser_table_layout parses the stored layout template", {
  table_layout <- tuikr:::extract_databrowser_table_layout(databrowser_structure_fixture)

  expect_equal(table_layout$rows, "TIME_PERIOD")
  expect_equal(table_layout$cols, c("REF_AREA", "ANNE_YAS_GRUP"))
  expect_equal(table_layout$filters, character(0))
  expect_equal(table_layout$filters_value, list())
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

test_that("build_statistical_data_table pivots long SDMX data into the browser layout", {
  long_data <- tibble::tibble(
    REF_AREA = c("TR", "TR", "TR", "TR", "34", "34", "34", "34"),
    ANNE_YAS_GRUP = c("Y15T19", "Y15T19", "Y20T24", "Y20T24", "Y15T19", "Y15T19", "Y20T24", "Y20T24"),
    obsTime = c("2009", "2010", "2009", "2010", "2009", "2010", "2009", "2010"),
    obsValue = c(36.97, 33.76, 117.45, 112.84, 24.49, 21.84, 97.47, 93.33)
  )
  table_layout <- list(
    rows = "TIME_PERIOD",
    cols = c("REF_AREA", "ANNE_YAS_GRUP"),
    filters = character(0),
    filters_value = list()
  )
  label_maps <- list(
    REF_AREA = c(TR = "Turkey", `34` = "Istanbul"),
    ANNE_YAS_GRUP = c(Y15T19 = "15-19", Y20T24 = "20-24")
  )

  wide_table <- tuikr:::build_statistical_data_table(
    long_data,
    table_layout = table_layout,
    label_maps = label_maps
  )

  expect_s3_class(wide_table, "tbl_df")
  expect_named(
    wide_table,
    c("TIME_PERIOD", "Turkey | 15-19", "Turkey | 20-24", "Istanbul | 15-19", "Istanbul | 20-24")
  )
  expect_equal(wide_table$TIME_PERIOD, c("2009", "2010"))
  expect_equal(wide_table[["Turkey | 15-19"]], c(36.97, 33.76))
})

test_that("build_statistical_data_table errors when extra varying dimensions remain", {
  long_data <- tibble::tibble(
    REF_AREA = c("TR", "TR"),
    SEX = c("M", "F"),
    obsTime = c("2020", "2020"),
    obsValue = c(1, 2)
  )
  table_layout <- list(
    rows = "TIME_PERIOD",
    cols = "REF_AREA",
    filters = character(0),
    filters_value = list()
  )

  expect_error(
    tuikr:::build_statistical_data_table(long_data, table_layout = table_layout),
    "multiple unconstrained dimensions remain: SEX"
  )
})

test_that("normalize_sdmx_data handles a live rsdmx document", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()

  data_url <- tuikr:::build_sdmx_data_url(
    "TR,DF_UHTI_COGRAFI,1.0",
    key = "TR....../ALL"
  )
  sdmx_document <- tuikr:::read_sdmx_document(data_url)
  normalized_data <- tuikr:::normalize_sdmx_data(sdmx_document)

  expect_s3_class(normalized_data, "tbl_df")
  expect_true(all(c("REF_AREA", "obsTime", "obsValue") %in% names(normalized_data)))
  expect_true(nrow(normalized_data) > 0)
})

test_that("build helpers derive rows from the theme tree", {
  table_rows <- tuikr:::build_statistical_table_tibble(theme_tree_fixture[[1]])
  database_rows <- tuikr:::build_statistical_database_tibble(theme_tree_fixture[[1]])

  expect_equal(table_rows$theme_id, "17")
  expect_equal(table_rows$node_type, "dataflow")
  expect_true(grepl("^https://databrowser2\\.tuik\\.gov\\.tr/#/tr/tuik/categories/", table_rows$table_url))
  expect_equal(database_rows$db_url, "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr")
})
