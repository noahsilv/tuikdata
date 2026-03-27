test_that("geo_data requires all download parameters together", {
  expect_error(
    geo_data(variable_no = "SNM-GK160951-O33303"),
    "must be provided together"
  )
})

test_that("geo_map validates the level argument", {
  expect_error(
    geo_map(level = 5),
    "level must be 2, 3, 4, or 9"
  )
})

test_that("statistical_resources validates supported resource types", {
  expect_error(
    statistical_resources(theme = 1, type = "video"),
    "type must be one or more of"
  )
})
