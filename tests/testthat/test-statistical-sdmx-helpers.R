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
    "dataflow_id must be a single non-NA character string"
  )
  expect_error(
    tuikr:::validate_dataflow_id("bad-id"),
    "dataflow_id must be a single SDMX identifier with three"
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

test_that("clean_statistical_long_data adds label columns for coded dimensions", {
  long_data <- tibble::tibble(
    ADNKS_GOSTERGE = c("COCUK_BAG_ORAN", "TOP_YAS_BAG_ORAN", "YASLI_BAG_ORAN"),
    REF_AREA = c("TR", "TR", "TR"),
    obsTime = c("2023", "2023", "2023"),
    obsValue = c(31.39, 46.34, 14.95)
  )
  label_maps <- list(
    ADNKS_GOSTERGE = c(
      COCUK_BAG_ORAN = "Child dependency ratio % (0-14 years)",
      TOP_YAS_BAG_ORAN = "Total age dependency ratio (%)",
      YASLI_BAG_ORAN = "Elderly dependency ratio % (65+ years)"
    ),
    REF_AREA = c(TR = "Turkey")
  )

  cleaned_long_data <- tuikr:::clean_statistical_long_data(
    long_data,
    label_maps = label_maps
  )

  expect_named(
    cleaned_long_data,
    c("ADNKS_GOSTERGE", "ADNKS_GOSTERGE_label", "obsTime", "obsValue")
  )
  expect_equal(
    cleaned_long_data$ADNKS_GOSTERGE_label,
    c(
      "Child dependency ratio % (0-14 years)",
      "Total age dependency ratio (%)",
      "Elderly dependency ratio % (65+ years)"
    )
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

test_that("clean_statistical_long_data returns early when all candidate cols are invariant", {
  long_data <- tibble::tibble(
    REF_AREA = c("TR", "TR", "TR"),
    obsTime = c("2021", "2022", "2023"),
    obsValue = c(1.0, 2.0, 3.0)
  )

  cleaned_long_data <- tuikr:::clean_statistical_long_data(long_data, label_maps = list())

  expect_named(cleaned_long_data, c("obsTime", "obsValue"))
  expect_equal(nrow(cleaned_long_data), 3L)
})

test_that("clean_statistical_long_data adds no label cols when label_maps is empty", {
  long_data <- tibble::tibble(
    INDICATOR = c("A", "B", "C"),
    REF_AREA = c("TR", "DE", "US"),
    obsTime = c("2023", "2023", "2023"),
    obsValue = c(1.0, 2.0, 3.0)
  )

  cleaned_long_data <- tuikr:::clean_statistical_long_data(long_data, label_maps = list())

  expect_named(cleaned_long_data, c("INDICATOR", "REF_AREA", "obsTime", "obsValue"))
  expect_false(any(grepl("_label$", names(cleaned_long_data))))
})
