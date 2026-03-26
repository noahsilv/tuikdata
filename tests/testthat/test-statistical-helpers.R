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
    c("dataflow", "istab")
  )

  expect_length(collected_nodes, 2)
  expect_equal(vapply(collected_nodes, `[[`, character(1), "icon"), c("dataflow", "istab"))
})

test_that("build_statistical_table_tibble maps dataflow and file nodes", {
  table_rows <- tuikr:::build_statistical_table_tibble(theme_tree_fixture[[1]])

  expect_s3_class(table_rows, "tbl_df")
  expect_named(
    table_rows,
    c("theme_name", "theme_id", "table_name", "node_type", "dataflow_id", "table_url")
  )
  expect_equal(table_rows$theme_id, c("1", "1"))
  expect_equal(table_rows$node_type, c("dataflow", "istab"))
  expect_equal(table_rows$dataflow_id, c("TR,DF_CRIME,1.0", NA_character_))
  expect_equal(
    table_rows$table_url,
    c(
      "https://databrowser2.tuik.gov.tr/dataflow/TR,DF_CRIME,1.0",
      "https://veriportali.tuik.gov.tr/Download/abc123/table.xls"
    )
  )
})

test_that("build_statistical_database_tibble returns database nodes only", {
  database_rows <- tuikr:::build_statistical_database_tibble(theme_tree_fixture[[1]])

  expect_s3_class(database_rows, "tbl_df")
  expect_named(database_rows, c("theme_name", "theme_id", "db_name", "db_url"))
  expect_equal(database_rows$db_name, "Court Database")
  expect_equal(
    database_rows$db_url,
    "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr"
  )
})
