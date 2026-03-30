test_that("geo_data requires var_level when a series supports multiple levels", {
  side_menu_payload <- list(
    menu = list(
      list(
        subMenu = list(
          list(
            gostergeNo = "SERIES-1",
            gostergeAdi = "Toplam Nufus",
            gostergeAdiEn = "Total Population",
            duzeyler = list(2, 3),
            period = "yillik",
            kaynak = "medas",
            kayitSayisi = 5
          )
        )
      )
    )
  )

  testthat::local_mocked_bindings(
    fromJSON = function(txt, simplifyDataFrame = FALSE, ...) {
      return(side_menu_payload)
    },
    .package = "jsonlite"
  )

  expect_error(
    geo_data(var_num = "SERIES-1"),
    "var_level is required"
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
    fetch_theme_tree = function(lang = "en") {
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
