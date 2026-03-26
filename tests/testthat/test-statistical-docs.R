test_that("statistical docs describe the rewritten JSON and SDMX interface", {
  readme_rmd_path <- testthat::test_path("../../README.Rmd")
  readme_md_path <- testthat::test_path("../../README.md")
  tables_rd_path <- testthat::test_path("../../man/statistical_tables.Rd")
  databases_rd_path <- testthat::test_path("../../man/statistical_databases.Rd")
  themes_rd_path <- testthat::test_path("../../man/statistical_themes.Rd")

  testthat::skip_if_not(
    all(file.exists(
      readme_rmd_path,
      readme_md_path,
      tables_rd_path,
      databases_rd_path,
      themes_rd_path
    )),
    "Source documentation files are not available in installed-package tests."
  )

  readme_rmd_lines <- readLines(readme_rmd_path, warn = FALSE)
  readme_md_lines <- readLines(readme_md_path, warn = FALSE)
  tables_rd_lines <- readLines(tables_rd_path, warn = FALSE)
  databases_rd_lines <- readLines(databases_rd_path, warn = FALSE)
  themes_rd_lines <- readLines(themes_rd_path, warn = FALSE)

  expect_true(any(grepl("node_type", readme_rmd_lines, fixed = TRUE)))
  expect_true(any(grepl("table_url", readme_rmd_lines, fixed = TRUE)))
  expect_false(any(grepl("datafile_url", readme_rmd_lines, fixed = TRUE)))
  expect_false(any(grepl("statistical_tables\\(110\\)", readme_rmd_lines)))

  expect_true(any(grepl("node_type", readme_md_lines, fixed = TRUE)))
  expect_true(any(grepl("table_url", readme_md_lines, fixed = TRUE)))
  expect_false(any(grepl("data_name", readme_md_lines, fixed = TRUE)))
  expect_false(any(grepl("datafile_url", readme_md_lines, fixed = TRUE)))

  expect_true(any(grepl('statistical_tables(theme, lang = "tr")', tables_rd_lines, fixed = TRUE)))
  expect_true(any(grepl("\\\\item\\{node_type\\}", tables_rd_lines)))
  expect_true(any(grepl("\\\\item\\{table_url\\}", tables_rd_lines)))
  expect_false(any(grepl("\\\\item\\{data_name\\}", tables_rd_lines)))

  expect_true(any(grepl('statistical_databases(theme, lang = "tr")', databases_rd_lines, fixed = TRUE)))
  expect_true(any(grepl("\\\\item\\{db_url\\}", databases_rd_lines)))

  expect_true(any(grepl('statistical_themes(lang = "tr")', themes_rd_lines, fixed = TRUE)))
})
