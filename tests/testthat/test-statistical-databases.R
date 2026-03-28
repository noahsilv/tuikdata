local_theme_tree_fixture <- list(
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
  )
)

test_that("validate_statistical_lang rejects unsupported lang codes", {
  expect_error(
    tuikr:::validate_statistical_lang("xx"),
    "lang must be one of"
  )
})

test_that("build_statistical_resource_tibble returns correct db columns from fixture", {
  resource_rows <- tuikr:::build_statistical_resource_tibble(local_theme_tree_fixture[[1]])
  db_rows <- dplyr::filter(resource_rows, .data$resource_type == "database")

  expect_named(db_rows, c("theme_name", "theme_id", "resource_name",
                           "resource_type", "dataflow_id", "resource_url"))
  expect_equal(db_rows$resource_url,
               "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr")
  expect_true(is.na(db_rows$dataflow_id))
})

test_that("statistical_databases network test", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()

  databases <- statistical_databases(11)

  expect_s3_class(databases, "tbl_df")
  expect_named(databases, c("theme_name", "theme_id", "db_name", "db_url"))
  expect_type(databases$db_url, "character")
  expect_true(all(grepl("^https?://", databases$db_url)))
})
