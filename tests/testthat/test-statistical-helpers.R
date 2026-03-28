theme_tree_fixture <- list(
  list(
    id = 1,
    name = "Justice and Elections",
    children = list(
      list(
        id = 10,
        name = "Courts",
        icon = "folder",
        children = list(
          list(
            id = 100,
            name = "Crime Statistics",
            icon = "dataflow",
            url = "https://databrowser2.tuik.gov.tr/dataflow/TR,DF_CRIME,1.0"
          ),
          list(
            id = 101,
            name = "Court Database",
            icon = "database",
            url = "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr"
          ),
          list(
            id = 102,
            name = "Archived XLS",
            icon = "istab",
            url = "/Download/abc123/table.xls"
          ),
          list(
            id = 103,
            name = "Justice Press Release",
            icon = "press",
            url = "/PressRelease/Details/123"
          ),
          list(
            id = 104,
            name = "Justice Annual Report",
            icon = "report",
            url = "/Report/Details/456"
          )
        )
      )
    )
  ),
  list(
    id = 2,
    name = "Population and Demography",
    children = list()
  )
)

test_that("build_statistical_portal_request derives URLs and language headers", {
  request_info <- tuikr:::build_statistical_portal_request("en")

  expect_equal(
    request_info$page_url,
    "https://veriportali.tuik.gov.tr/en/statistical-themes"
  )
  expect_equal(
    request_info$api_url,
    "https://veriportali.tuik.gov.tr/api/en/data/statistical-themes"
  )
  expect_equal(
    request_info$headers[["Accept-Language"]],
    "en-US,en;q=0.9,tr-TR;q=0.8,tr;q=0.7"
  )
})

test_that("build_statistical_portal_request rejects unsupported languages", {
  expect_error(
    tuikr:::build_statistical_portal_request("de"),
    "lang must be one of"
  )
})

test_that("collect_nodes_by_icon recurses through nested children", {
  collected_nodes <- tuikr:::collect_nodes_by_icon(
    theme_tree_fixture[[1]]$children,
    c("dataflow", "istab", "press", "report")
  )

  expect_length(collected_nodes, 4)
  expect_equal(
    vapply(collected_nodes, `[[`, character(1), "icon"),
    c("dataflow", "istab", "press", "report")
  )
})

test_that("build_statistical_resource_tibble maps supported portal resources", {
  resource_rows <- tuikr:::build_statistical_resource_tibble(theme_tree_fixture[[1]])

  expect_s3_class(resource_rows, "tbl_df")
  expect_named(
    resource_rows,
    c("theme_name", "theme_id", "resource_name", "resource_type", "dataflow_id", "resource_url")
  )
  expect_equal(resource_rows$theme_id, rep("1", 5))
  expect_equal(
    resource_rows$resource_type,
    c("dataflow", "database", "istab", "press", "report")
  )
  expect_equal(
    resource_rows$dataflow_id,
    c("TR,DF_CRIME,1.0", NA_character_, NA_character_, NA_character_, NA_character_)
  )
  expect_equal(
    resource_rows$resource_url,
    c(
      "https://databrowser2.tuik.gov.tr/dataflow/TR,DF_CRIME,1.0",
      "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr",
      "https://veriportali.tuik.gov.tr/Download/abc123/table.xls",
      "https://veriportali.tuik.gov.tr/PressRelease/Details/123",
      "https://veriportali.tuik.gov.tr/Report/Details/456"
    )
  )
})

test_that("statistical_themes stops when fetch_theme_tree errors", {
  testthat::local_mocked_bindings(
    fetch_theme_tree = function(lang = "tr") {
      stop("TUIK API returned an error: Service unavailable", call. = FALSE)
    },
    .package = "tuikr"
  )

  expect_error(
    statistical_themes(),
    "TUIK API returned an error"
  )
})
