test_that("geo_data requires all download parameters together", {
  expect_error(
    geo_data(var_num = "SNM-GK160951-O33303"),
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

test_that("statistical_resources reports valid theme IDs for unknown themes", {
  testthat::local_mocked_bindings(
    fetch_theme_tree = function(lang = "tr") {
      return(list(
        list(id = 1, name = "Justice and Elections", children = list()),
        list(id = 11, name = "Population and Demography", children = list())
      ))
    },
    .package = "tuikr"
  )

  expect_error(
    statistical_resources(theme = 99),
    "theme must be one of the available theme IDs:"
  )
  expect_error(
    statistical_resources(theme = 99),
    "11 = Population and Demography"
  )
})
