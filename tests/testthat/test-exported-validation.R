validation_env <- new.env(parent = globalenv())
root <- testthat::test_path("..", "..")
sys.source(file.path(root, "R/geo-data.R"), envir = validation_env)
sys.source(file.path(root, "R/geo-map.R"), envir = validation_env)

test_that("geo_data requires all download parameters together", {
  expect_error(
    validation_env$geo_data(variable_no = "SNM-GK160951-O33303"),
    "must be provided together"
  )
})

test_that("geo_map validates the level argument", {
  expect_error(
    validation_env$geo_map(level = 5),
    "level must be 2, 3, 4, or 9"
  )
})
