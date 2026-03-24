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
