test_that("statistical docs describe the rewritten JSON and SDMX interface", {
  readme_rmd_path <- testthat::test_path("../../README.Rmd")
  readme_md_path <- testthat::test_path("../../README.md")
  getting_started_path <- testthat::test_path("../../vignettes/getting-started.Rmd")
  known_issues_path <- testthat::test_path("../../vignettes/known-issues.Rmd")
  resources_r_path <- testthat::test_path("../../R/statistical-resources.R")
  tables_r_path <- testthat::test_path("../../R/statistical-tables.R")
  databases_r_path <- testthat::test_path("../../R/statistical-databases.R")
  themes_r_path <- testthat::test_path("../../R/statistical-themes.R")
  resources_rd_path <- testthat::test_path("../../man/statistical_resources.Rd")
  tables_rd_path <- testthat::test_path("../../man/statistical_tables.Rd")
  databases_rd_path <- testthat::test_path("../../man/statistical_databases.Rd")
  themes_rd_path <- testthat::test_path("../../man/statistical_themes.Rd")

  testthat::skip_if_not(
    all(file.exists(
      readme_rmd_path,
      readme_md_path,
      getting_started_path,
      known_issues_path,
      resources_r_path,
      tables_r_path,
      databases_r_path,
      themes_r_path,
      resources_rd_path,
      tables_rd_path,
      databases_rd_path,
      themes_rd_path
    )),
    "Source documentation files are not available in installed-package tests."
  )

  readme_rmd_lines <- readLines(readme_rmd_path, warn = FALSE)
  readme_md_lines <- readLines(readme_md_path, warn = FALSE)
  getting_started_lines <- readLines(getting_started_path, warn = FALSE)
  known_issues_lines <- readLines(known_issues_path, warn = FALSE)
  resources_r_lines <- readLines(resources_r_path, warn = FALSE)
  tables_r_lines <- readLines(tables_r_path, warn = FALSE)
  databases_r_lines <- readLines(databases_r_path, warn = FALSE)
  themes_r_lines <- readLines(themes_r_path, warn = FALSE)
  resources_rd_lines <- readLines(resources_rd_path, warn = FALSE)
  tables_rd_lines <- readLines(tables_rd_path, warn = FALSE)
  databases_rd_lines <- readLines(databases_rd_path, warn = FALSE)
  themes_rd_lines <- readLines(themes_rd_path, warn = FALSE)

  expect_true(any(grepl("node_type", readme_rmd_lines, fixed = TRUE)))
  expect_true(any(grepl("table_url", readme_rmd_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_resources(", readme_rmd_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data(", readme_rmd_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data_structure(", readme_rmd_lines, fixed = TRUE)))
  expect_false(any(grepl("datafile_url", readme_rmd_lines, fixed = TRUE)))
  expect_false(any(grepl("statistical_tables\\(110\\)", readme_rmd_lines)))
  expect_false(any(grepl("nsiws.tuik.gov.tr/rest/data", readme_rmd_lines, fixed = TRUE)))
  expect_false(any(grepl("databrowser2.tuik.gov.tr/api/core/nodes", readme_rmd_lines, fixed = TRUE)))

  expect_true(any(grepl("node_type", readme_md_lines, fixed = TRUE)))
  expect_true(any(grepl("table_url", readme_md_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_resources(", readme_md_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data(", readme_md_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data_structure(", readme_md_lines, fixed = TRUE)))
  expect_false(any(grepl("data_name", readme_md_lines, fixed = TRUE)))
  expect_false(any(grepl("datafile_url", readme_md_lines, fixed = TRUE)))
  expect_false(any(grepl("nsiws.tuik.gov.tr/rest/data", readme_md_lines, fixed = TRUE)))
  expect_false(any(grepl("databrowser2.tuik.gov.tr/api/core/nodes", readme_md_lines, fixed = TRUE)))

  first_tables_line <- which(grepl("statistical_tables(", getting_started_lines, fixed = TRUE))[1]
  first_resources_line <- which(grepl("statistical_resources(", getting_started_lines, fixed = TRUE))[1]
  first_data_line <- which(grepl("justice_data <- statistical_data(", getting_started_lines, fixed = TRUE))[1]
  first_structure_line <- which(grepl("justice_structure <- statistical_data_structure(", getting_started_lines, fixed = TRUE))[1]

  expect_false(is.na(first_tables_line))
  expect_false(is.na(first_resources_line))
  expect_false(is.na(first_data_line))
  expect_false(is.na(first_structure_line))
  expect_true(first_tables_line < first_resources_line)
  expect_true(first_resources_line < first_structure_line)
  expect_true(first_structure_line < first_data_line)
  expect_false(any(grepl("databrowser2.tuik.gov.tr/api/core/nodes", getting_started_lines, fixed = TRUE)))

  expect_true(any(grepl("SDMX Key Complexity", known_issues_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_resources()", known_issues_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data_structure(", known_issues_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data(", known_issues_lines, fixed = TRUE)))

  expect_true(any(grepl("resource_type", resources_r_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data", resources_r_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data(", tables_r_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data_structure(", tables_r_lines, fixed = TRUE)))
  expect_true(any(grepl("dataflow_id", tables_r_lines, fixed = TRUE)))
  expect_false(any(grepl("databrowser2.tuik.gov.tr/api/core/nodes", tables_r_lines, fixed = TRUE)))

  expect_true(any(grepl("statistical_data", databases_r_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_data_structure", databases_r_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_resources", databases_r_lines, fixed = TRUE)))
  expect_true(any(grepl("dataflow_id", themes_r_lines, fixed = TRUE)))
  expect_true(any(grepl("statistical_resources", themes_r_lines, fixed = TRUE)))

  expect_true(any(grepl('statistical_resources\\(theme, type = NULL, lang = "tr"\\)', resources_rd_lines)))
  expect_true(any(grepl("\\\\item\\{resource_type\\}", resources_rd_lines)))
  expect_true(any(grepl("\\\\item\\{resource_url\\}", resources_rd_lines)))

  expect_true(any(grepl('statistical_tables(theme, lang = "tr")', tables_rd_lines, fixed = TRUE)))
  expect_true(any(grepl("\\\\item\\{node_type\\}", tables_rd_lines)))
  expect_true(any(grepl("\\\\item\\{table_url\\}", tables_rd_lines)))
  expect_false(any(grepl("\\\\item\\{data_name\\}", tables_rd_lines)))

  expect_true(any(grepl('statistical_databases(theme, lang = "tr")', databases_rd_lines, fixed = TRUE)))
  expect_true(any(grepl("\\\\item\\{db_url\\}", databases_rd_lines)))

  expect_true(any(grepl('statistical_themes(lang = "tr")', themes_rd_lines, fixed = TRUE)))
})
