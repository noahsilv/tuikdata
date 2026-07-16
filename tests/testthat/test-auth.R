with_tuik_api_key <- function(value, code) {
  old_key <- Sys.getenv("TUIK_API_KEY", unset = NA)
  on.exit(
    {
      if (is.na(old_key)) {
        Sys.unsetenv("TUIK_API_KEY")
      } else {
        Sys.setenv(TUIK_API_KEY = old_key)
      }
    },
    add = TRUE
  )

  if (is.null(value)) {
    Sys.unsetenv("TUIK_API_KEY")
  } else {
    Sys.setenv(TUIK_API_KEY = value)
  }

  force(code)
}

test_that("tuik_api_key errors with setup guidance when TUIK_API_KEY is unset", {
  with_tuik_api_key(NULL, {
    expect_error(
      tuikr:::tuik_api_key(),
      "TUIK SDMX requests require an API key"
    )
    expect_error(
      tuikr:::tuik_api_key(),
      "TUIK_API_KEY"
    )
  })
})

test_that("tuik_api_key returns the configured key", {
  with_tuik_api_key("test-key-123", {
    expect_equal(tuikr:::tuik_api_key(), "test-key-123")
  })
})

test_that("tuik_sdmx_token returns a cached token without refetching", {
  tuikr:::clear_tuik_token_cache()
  on.exit(tuikr:::clear_tuik_token_cache(), add = TRUE)

  cache_env <- tuikr:::tuik_auth_cache
  cache_env$access_token <- "cached-token"
  cache_env$expires_at <- Sys.time() + 120

  testthat::local_mocked_bindings(
    fetch_tuik_access_token = function(api_key) {
      stop("token endpoint must not be called while the cache is valid")
    },
    .package = "tuikr"
  )

  expect_equal(tuikr:::tuik_sdmx_token(), "cached-token")
})

test_that("tuik_sdmx_token refreshes an expired token", {
  tuikr:::clear_tuik_token_cache()
  on.exit(tuikr:::clear_tuik_token_cache(), add = TRUE)

  cache_env <- tuikr:::tuik_auth_cache
  cache_env$access_token <- "stale-token"
  cache_env$expires_at <- Sys.time() - 1

  testthat::local_mocked_bindings(
    fetch_tuik_access_token = function(api_key) {
      list(access_token = "fresh-token", expires_in = 300)
    },
    .package = "tuikr"
  )

  with_tuik_api_key("test-key-123", {
    expect_equal(tuikr:::tuik_sdmx_token(), "fresh-token")
  })
  expect_equal(cache_env$access_token, "fresh-token")
  expect_true(cache_env$expires_at > Sys.time())
})

test_that("tuik_sdmx_token requires an API key before fetching", {
  tuikr:::clear_tuik_token_cache()
  on.exit(tuikr:::clear_tuik_token_cache(), add = TRUE)

  with_tuik_api_key(NULL, {
    expect_error(
      tuikr:::tuik_sdmx_token(),
      "TUIK SDMX requests require an API key"
    )
  })
})

test_that("build_sdmx_auth_headers formats the Bearer authorization header", {
  testthat::local_mocked_bindings(
    tuik_sdmx_token = function() "token-abc",
    .package = "tuikr"
  )

  auth_headers <- tuikr:::build_sdmx_auth_headers()

  expect_equal(auth_headers, list(Authorization = "Bearer token-abc"))
})

test_that("fetch_tuik_access_token exchanges a real API key for a token", {
  skip_if_not(
    identical(Sys.getenv("RUN_NETWORK_TESTS"), "true"),
    "Set RUN_NETWORK_TESTS=true to run network integration tests."
  )
  skip_if_not(
    nzchar(Sys.getenv("TUIK_API_KEY")),
    "Set TUIK_API_KEY to run authenticated TUIK SDMX tests."
  )
  skip_if_offline()

  token_info <- tuikr:::fetch_tuik_access_token(Sys.getenv("TUIK_API_KEY"))

  expect_true(nzchar(token_info$access_token))
  expect_true(token_info$expires_in > 0)
})
