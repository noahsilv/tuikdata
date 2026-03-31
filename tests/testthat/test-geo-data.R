test_that("geo_data returns metadata without parameters", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_offline()
  
  dt <- geo_data()
  
  expect_s3_class(dt, "tbl_df")
  expect_named(dt, c("var_name", "var_num", "var_levels", "var_period"))
  expect_true("var_name" %in% names(dt))
  expect_true("var_num" %in% names(dt))
  expect_true(nrow(dt) > 0)
})

test_that("geo_data metadata hides request plumbing columns", {
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

  variable_catalog <- geo_data()

  expect_named(
    variable_catalog,
    c("var_name", "var_num", "var_levels", "var_period")
  )
  expect_false("var_source" %in% names(variable_catalog))
  expect_false("var_recordnum" %in% names(variable_catalog))
})

test_that("geo_data validates NUTS level", {
  expect_error(
    geo_data(
      var_num = "SNM-GK160951-O33303",
      var_level = 5
    ),
    "var_level must be a single level value of 2, 3, or 4"
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

test_that("geo_data defaults to English metadata names", {
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

  default_metadata <- geo_data()

  expect_equal(default_metadata$var_name, "Female Population")
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
    lang = "en"
  )

  expect_true("female_population" %in% names(english_data))
  expect_false("kadin_nufusu" %in% names(english_data))
})

test_that("geo_data derives request parameters from metadata", {
  side_menu_payload <- list(
    menu = list(
      list(
        subMenu = list(
          list(
            gostergeNo = "SERIES-1",
            gostergeAdi = "Toplam Nufus",
            gostergeAdiEn = "Total Population",
            duzeyler = list(3),
            period = "yillik",
            kaynak = "medas",
            kayitSayisi = 5
          )
        )
      )
    )
  )

  observed_urls <- character(0)

  geo_data_payload <- list(
    gostergeNo = "SERIES-1",
    gosterge_ad = "Toplam Nufus",
    gosterge_ad_ing = "Total Population",
    period = "yillik",
    ondalikHassasiyet = "0",
    metaVeriURL = "https://example.com/meta",
    tarihler = c("2025"),
    veriler = tibble::tibble(
      duzeyKodu = "06",
      veri = list(c("100"))
    )
  )

  testthat::local_mocked_bindings(
    fromJSON = function(txt, simplifyDataFrame = FALSE, ...) {
      observed_urls <<- c(observed_urls, txt)
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

  downloaded_data <- geo_data(var_num = "SERIES-1")

  expect_true(any(grepl("kaynak=medas", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("kayitSayisi=5", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("period=yillik", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("duzey=3", observed_urls, fixed = TRUE)))
  expect_true("total_population" %in% names(downloaded_data))
})

test_that("geo_data selects metadata by the requested var_num", {
  side_menu_payload <- list(
    menu = list(
      list(
        subMenu = list(
          list(
            gostergeNo = "SERIES-1",
            gostergeAdi = "Toplam Nufus",
            gostergeAdiEn = "Total Population",
            duzeyler = list(3),
            period = "yillik",
            kaynak = "medas",
            kayitSayisi = 5
          ),
          list(
            gostergeNo = "SERIES-2",
            gostergeAdi = "Konut Satislari",
            gostergeAdiEn = "House Sales",
            duzeyler = list(3),
            period = "yillik",
            kaynak = "ilGostergeleri",
            kayitSayisi = 7
          )
        )
      )
    )
  )

  observed_urls <- character(0)

  geo_data_payload <- list(
    gostergeNo = "SERIES-2",
    gosterge_ad = "Konut Satislari",
    gosterge_ad_ing = "House Sales",
    period = "yillik",
    ondalikHassasiyet = "0",
    metaVeriURL = "https://example.com/meta",
    tarihler = c("2025"),
    veriler = tibble::tibble(
      duzeyKodu = "06",
      veri = list(c("100"))
    )
  )

  testthat::local_mocked_bindings(
    fromJSON = function(txt, simplifyDataFrame = FALSE, ...) {
      observed_urls <<- c(observed_urls, txt)
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

  downloaded_data <- geo_data(var_num = "SERIES-2")

  expect_true(any(grepl("gostergeNo=SERIES-2", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("kaynak=ilGostergeleri", observed_urls, fixed = TRUE)))
  expect_true(any(grepl("kayitSayisi=7", observed_urls, fixed = TRUE)))
  expect_true("house_sales" %in% names(downloaded_data))
})

test_that("geo_data requires var_level when metadata exposes multiple levels", {
  side_menu_payload <- list(
    menu = list(
      list(
        subMenu = list(
          list(
            gostergeNo = "SERIES-1",
            gostergeAdi = "Toplam Nufus",
            gostergeAdiEn = "Total Population",
            duzeyler = list(2, 3, 4),
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
    "var_level is required for SERIES-1. Valid levels: 2, 3, 4"
  )
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

test_that("geo_data rejects non-scalar var_level inputs", {
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
    geo_data(var_num = "SERIES-1", var_level = c(2, 3)),
    "var_level must be a single level value of 2, 3, or 4"
  )
  expect_error(
    geo_data(var_num = "SERIES-1", var_level = integer()),
    "var_level must be a single level value of 2, 3, or 4"
  )
})

test_that("geo_map rejects non-scalar level inputs", {
  expect_error(
    geo_map(level = c(2, 3)),
    "level must be a single value of 2, 3, 4, or 9"
  )
  expect_error(
    geo_map(level = integer()),
    "level must be a single value of 2, 3, 4, or 9"
  )
})
