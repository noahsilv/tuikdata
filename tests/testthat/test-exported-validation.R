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
