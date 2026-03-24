test_that("geo_data returns metadata without parameters", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()
  
  dt <- geo_data()
  
  expect_s3_class(dt, "tbl_df")
  expect_true("var_name" %in% names(dt))
  expect_true("var_num" %in% names(dt))
  expect_true(nrow(dt) > 0)
})

test_that("geo_data validates NUTS level", {
  expect_error(
    geo_data(
      variable_no = "SNM-GK160951-O33303",
      variable_level = 5,
      variable_source = "medas",
      variable_period = "yillik",
      variable_recnum = 5
    ),
    "variable_level must be 2, 3, or 4"
  )
})
