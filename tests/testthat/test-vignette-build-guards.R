test_that("network-heavy vignettes are disabled outside pkgdown builds", {
  root <- testthat::test_path("..", "..")
  getting_started <- readLines(file.path(root, "vignettes/getting-started.Rmd"), warn = FALSE)
  geographic_mapping <- readLines(file.path(root, "vignettes/geographic-mapping.Rmd"), warn = FALSE)
  pkgdown_workflow <- readLines(file.path(root, ".github/workflows/pkgdown.yaml"), warn = FALSE)

  expect_true(any(grepl('Sys.getenv\\("IN_PKGDOWN"\\)', getting_started)))
  expect_true(any(grepl('Sys.getenv\\("IN_PKGDOWN"\\)', geographic_mapping)))
  expect_true(any(grepl("IN_PKGDOWN: true", pkgdown_workflow, fixed = TRUE)))
  expect_false(any(grepl("pkgdown::in_pkgdown\\(\\)", getting_started)))
  expect_false(any(grepl("pkgdown::in_pkgdown\\(\\)", geographic_mapping)))
})
