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
      var_num = "SNM-GK160951-O33303",
      var_level = 5,
      var_source = "medas",
      var_period = "yillik",
      var_recordnum = 5
    ),
    "var_level must be 2, 3, or 4"
  )
})

test_that("geo_data returns English metadata names when lang = 'en'", {
  side_menu_payload <- list(
    menu = list(
      list(
        subMenu = list(
          list(
            gostergeNo = "SERIES-1",
            gostergeAdi = "Kadin Nufusu",
            gostergeAdiEn = "Female Population",
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

  english_metadata <- geo_data(lang = "en")

  expect_equal(english_metadata$var_name, "Female Population")
})

test_that("geo_data uses English series labels when lang = 'en' in data mode", {
  side_menu_payload <- list(
    menu = list(
      list(
        subMenu = list(
          list(
            gostergeNo = "SERIES-1",
            gostergeAdi = "Kadin Nufusu",
            gostergeAdiEn = "Female Population",
            duzeyler = list(3),
            period = "yillik",
            kaynak = "medas",
            kayitSayisi = 5
          )
        )
      )
    )
  )

  geo_data_payload <- list(
    gostergeNo = "SERIES-1",
    gosterge_ad = "Kadin Nufusu",
    gosterge_ad_ing = "Female Population",
    period = "yillik",
    ondalikHassasiyet = "0",
    metaVeriURL = "https://example.com/meta",
    tarihler = c("2025", "2024"),
    veriler = tibble::tibble(
      duzeyKodu = "06",
      veri = list(c("100", "90"))
    )
  )

  testthat::local_mocked_bindings(
    fromJSON = function(txt, simplifyDataFrame = FALSE, ...) {
      if (grepl("sideMenu.json", txt, fixed = TRUE)) {
        return(side_menu_payload)
      }
      if (grepl("GetMapData", txt, fixed = TRUE)) {
        return(geo_data_payload)
      }
      stop("Unexpected URL in test: ", txt)
    },
    .package = "jsonlite"
  )

  english_data <- geo_data(
    var_num = "SERIES-1",
    var_level = 3,
    var_source = "medas",
    var_period = "yillik",
    var_recordnum = 5,
    lang = "en"
  )

  expect_true("female_population" %in% names(english_data))
  expect_false("kadin_nufusu" %in% names(english_data))
})

test_that("geo_map dataframe = TRUE drops geometry column", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()

  nuts3_sf <- geo_map(level = 3)
  nuts3_tbl <- geo_map(level = 3, dataframe = TRUE)

  expect_s3_class(nuts3_sf, "sf")
  expect_true("geometry" %in% names(nuts3_sf))
  expect_s3_class(nuts3_tbl, "tbl_df")
  expect_false(inherits(nuts3_tbl, "sf"))
  expect_false("geometry" %in% names(nuts3_tbl))
  expect_true("code" %in% names(nuts3_tbl))
})
