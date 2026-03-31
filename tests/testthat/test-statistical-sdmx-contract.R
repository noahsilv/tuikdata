test_that("sdmx contract is documented in source files", {
  root_path <- testthat::test_path("..", "..")
  description_path <- file.path(root_path, "DESCRIPTION")
  readme_path <- file.path(root_path, "README.Rmd")

  testthat::skip_if_not(
    file.exists(description_path) && file.exists(readme_path),
    "Source files are not available in installed-package tests."
  )

  description_lines <- readLines(description_path, warn = FALSE)
  readme_lines <- readLines(readme_path, warn = FALSE)

  expect_true(
    any(grepl("^\\s*rsdmx,?$", description_lines)),
    info = "`DESCRIPTION` must import `rsdmx`."
  )
  expect_true(
    any(grepl("statistical_tables(", readme_lines, fixed = TRUE)),
    info = "`README.Rmd` should show the new discovery call."
  )
  expect_true(
    any(grepl("statistical_data(", readme_lines, fixed = TRUE)),
    info = "`README.Rmd` should introduce the SDMX data download function."
  )
  expect_true(
    any(grepl("dataflow_id", readme_lines, fixed = TRUE)),
    info = "`README.Rmd` should document `dataflow_id` as the SDMX identifier."
  )
})
