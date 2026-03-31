test_that("network-heavy vignettes are disabled outside pkgdown builds", {
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(
    file.exists(file.path(root, "vignettes/getting-started.Rmd")),
    "Source vignette files are not available in installed-package tests."
  )
  getting_started <- readLines(file.path(root, "vignettes/getting-started.Rmd"), warn = FALSE)
  geographic_mapping <- readLines(file.path(root, "vignettes/geographic-mapping.Rmd"), warn = FALSE)

  expect_true(any(grepl('Sys.getenv\\("IN_PKGDOWN"\\)', getting_started)))
  expect_true(any(grepl('Sys.getenv\\("IN_PKGDOWN"\\)', geographic_mapping)))
  expect_false(any(grepl("pkgdown::in_pkgdown\\(\\)", getting_started)))
  expect_false(any(grepl("pkgdown::in_pkgdown\\(\\)", geographic_mapping)))

  pkgdown_workflow_path <- file.path(root, ".github/workflows/pkgdown.yaml")
  if (file.exists(pkgdown_workflow_path)) {
    pkgdown_workflow <- readLines(pkgdown_workflow_path, warn = FALSE)
    expect_true(any(grepl("IN_PKGDOWN: true", pkgdown_workflow, fixed = TRUE)))
  }
})

test_that("geographic mapping vignette provides alt text for the map figure", {
  root <- testthat::test_path("..", "..")
  vignette_path <- file.path(root, "vignettes/geographic-mapping.Rmd")

  testthat::skip_if_not(
    file.exists(vignette_path),
    "Source vignette files are not available in installed-package tests."
  )

  geographic_mapping <- readLines(vignette_path, warn = FALSE)
  geo_plot_line <- grep("^```\\{r geo-plot", geographic_mapping)

  expect_length(geo_plot_line, 1L)
  expect_match(geographic_mapping[[geo_plot_line]], "fig\\.alt\\s*=")
})
