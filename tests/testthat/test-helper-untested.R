source(testthat::test_path("fixtures/theme-tree.R"))

# Tests for lookup_first_localized_value
test_that("lookup_first_localized_value prefers target language", {
  value_list <- list(tr = "Türkçe", en = "English")
  expect_equal(tuikr:::lookup_first_localized_value(value_list, "tr"), "Türkçe")
  expect_equal(tuikr:::lookup_first_localized_value(value_list, "en"), "English")
})

test_that("lookup_first_localized_value falls back to first available value", {
  value_list <- list(fr = "Français", de = "Deutsch")
  result <- tuikr:::lookup_first_localized_value(value_list, "tr")
  expect_true(result %in% c("Français", "Deutsch"))
})

test_that("lookup_first_localized_value returns NA for empty list", {
  expect_equal(tuikr:::lookup_first_localized_value(list(), "tr"), NA_character_)
  expect_equal(tuikr:::lookup_first_localized_value(NULL, "tr"), NA_character_)
})

test_that("lookup_first_localized_value handles NA values", {
  value_list <- list(tr = NA_character_, en = "English")
  result <- tuikr:::lookup_first_localized_value(value_list, "tr")
  expect_equal(result, "English")
})

# Tests for normalize_statistical_url
test_that("normalize_statistical_url passes through absolute URLs", {
  absolute_url <- "https://example.com/path"
  expect_equal(tuikr:::normalize_statistical_url(absolute_url), absolute_url)

  absolute_url2 <- "http://veriportali.tuik.gov.tr/data"
  expect_equal(tuikr:::normalize_statistical_url(absolute_url2), absolute_url2)
})

test_that("normalize_statistical_url prepends base URL for relative paths", {
  relative_url <- "/Download/abc123/table.xls"
  expected <- "https://veriportali.tuik.gov.tr/Download/abc123/table.xls"
  expect_equal(tuikr:::normalize_statistical_url(relative_url), expected)
})

# Tests for extract_dataflow_id
test_that("extract_dataflow_id extracts ID from databrowser URL", {
  url <- "https://databrowser2.tuik.gov.tr/dataflow/TR,DF_CRIME,1.0"
  expect_equal(tuikr:::extract_dataflow_id(url), "TR,DF_CRIME,1.0")
})

test_that("extract_dataflow_id handles multiple slashes", {
  url <- "https://example.com/path/to/TR,DF_UHTI_COGRAFI,1.0"
  expect_equal(tuikr:::extract_dataflow_id(url), "TR,DF_UHTI_COGRAFI,1.0")
})

# Tests for apply_dimension_label_map
test_that("apply_dimension_label_map applies available mappings", {
  label_map <- c("A" = "Alpha", "B" = "Beta", "C" = "Gamma")
  values <- c("A", "B", "C")
  label_maps <- list(dimension1 = label_map)

  result <- tuikr:::apply_dimension_label_map(values, "dimension1", label_maps)
  expect_equal(result, c("Alpha", "Beta", "Gamma"))
})

test_that("apply_dimension_label_map preserves unmapped values", {
  label_map <- c("A" = "Alpha", "B" = "Beta")
  values <- c("A", "B", "D")
  label_maps <- list(dimension1 = label_map)

  result <- tuikr:::apply_dimension_label_map(values, "dimension1", label_maps)
  expect_equal(result, c("Alpha", "Beta", "D"))
})

test_that("apply_dimension_label_map returns values unchanged when no map exists", {
  values <- c("A", "B", "C")
  label_maps <- list()

  result <- tuikr:::apply_dimension_label_map(values, "nonexistent", label_maps)
  expect_equal(result, values)
})

# Tests for validate_string_single
test_that("validate_string_single accepts valid single string", {
  result <- tuikr:::validate_string_single("valid", "arg_name")
  expect_equal(result, "valid")
})

test_that("validate_string_single rejects NA values", {
  expect_error(
    tuikr:::validate_string_single(NA_character_, "arg_name"),
    "arg_name must be a single non-NA character string"
  )
})

test_that("validate_string_single rejects multiple values", {
  expect_error(
    tuikr:::validate_string_single(c("a", "b"), "arg_name"),
    "arg_name must be a single non-NA character string"
  )
})

test_that("validate_string_single rejects non-character values", {
  expect_error(
    tuikr:::validate_string_single(123, "arg_name"),
    "arg_name must be a single non-NA character string"
  )
})

test_that("validate_string_single enforces allowed_values when provided", {
  result <- tuikr:::validate_string_single("tr", "lang", allowed_values = c("tr", "en"))
  expect_equal(result, "tr")

  expect_error(
    tuikr:::validate_string_single("de", "lang", allowed_values = c("tr", "en")),
    "lang must be one of:"
  )
})
