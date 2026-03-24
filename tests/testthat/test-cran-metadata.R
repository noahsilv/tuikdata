test_that("CRAN metadata files contain no placeholders", {
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(
    file.exists(file.path(root, "DESCRIPTION")),
    "Source metadata files are not available in installed-package tests."
  )
  description_lines <- readLines(file.path(root, "DESCRIPTION"), warn = FALSE)
  cran_comment_lines <- readLines(file.path(root, "cran-comments.md"), warn = FALSE)
  citation_lines <- readLines(file.path(root, "CITATION.cff"), warn = FALSE)

  expect_false(any(grepl("X\\.Y\\.Z|placeholder|replace the placeholders", cran_comment_lines, ignore.case = TRUE)))
  expect_true(any(grepl("^Title: .*URLs", description_lines)))
  expect_true(any(grepl("^BugReports: https://github.com/emraher/tuikr/issues$", description_lines)))
  expect_true(any(grepl('^title: "tuikr: .*URLs.*"$', citation_lines)))
})
