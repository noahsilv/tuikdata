#' TUIK SDMX authentication helpers
#'
#' The TUIK SDMX web service (`nsiws.tuik.gov.tr`) requires requests to carry
#' a short-lived Bearer token issued by the TUIK login service. Tokens are
#' obtained by exchanging a personal API key, which users generate on the
#' TUIK data portal after registering and verifying a phone number.
#'
#' @keywords internal
#' @name tuik-auth
NULL

tuik_token_url <- "https://giris.tuik.gov.tr/realms/web/protocol/openid-connect/token"
tuik_token_client_id <- "nsi-ws-consumer"
tuik_token_expiry_margin_seconds <- 30

tuik_auth_cache <- new.env(parent = emptyenv())

#' @noRd
#' @keywords internal
tuik_api_key <- function() {
  api_key <- Sys.getenv("TUIK_API_KEY")

  if (!nzchar(api_key)) {
    stop(
      paste(
        "TUIK SDMX requests require an API key set in the TUIK_API_KEY environment variable.",
        "Register at https://veriportali.tuik.gov.tr/, verify your phone number, and generate",
        "an API key under 'User Information'. Then run",
        "Sys.setenv(TUIK_API_KEY = \"<your key>\") or add TUIK_API_KEY to your ~/.Renviron.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  api_key
}

#' @noRd
#' @keywords internal
clear_tuik_token_cache <- function() {
  rm(
    list = ls(envir = tuik_auth_cache, all.names = TRUE),
    envir = tuik_auth_cache
  )
  invisible(NULL)
}

#' Exchange a TUIK API key for a short-lived SDMX access token.
#'
#' Posts the API key to the TUIK login service (Keycloak) and returns the
#' Bearer token together with its lifetime in seconds.
#'
#' @param api_key Character string. Personal API key from the TUIK data portal.
#'
#' @return List with `access_token` (character) and `expires_in` (numeric seconds).
#'
#' @noRd
#' @keywords internal
fetch_tuik_access_token <- function(api_key) {
  token_client <- crul::HttpClient$new(url = tuik_token_url)
  token_response <- token_client$post(
    body = list(
      grant_type = "password",
      client_id = tuik_token_client_id,
      api_key = api_key
    ),
    encode = "form"
  )

  if (token_response$status_code >= 400) {
    stop(
      paste(
        "TUIK login service rejected the API key (HTTP ",
        token_response$status_code,
        "). Check that TUIK_API_KEY holds a valid key generated at",
        " https://veriportali.tuik.gov.tr/ under 'User Information'.",
        sep = ""
      ),
      call. = FALSE
    )
  }

  parsed_token <- jsonlite::fromJSON(
    token_response$parse("UTF-8"),
    simplifyVector = TRUE
  )

  access_token <- parsed_token$access_token
  if (is.null(access_token) || !nzchar(access_token)) {
    stop(
      "TUIK login service response did not include an access token.",
      call. = FALSE
    )
  }

  expires_in <- suppressWarnings(as.numeric(parsed_token$expires_in))
  if (length(expires_in) != 1 || is.na(expires_in) || expires_in <= 0) {
    expires_in <- 300
  }

  list(access_token = access_token, expires_in = expires_in)
}

#' Return a valid TUIK SDMX Bearer token, refreshing the cache when needed.
#'
#' Tokens are cached in the package environment and refreshed shortly before
#' they expire (default lifetime is around 300 seconds).
#'
#' @return Character string. A currently valid access token.
#'
#' @noRd
#' @keywords internal
tuik_sdmx_token <- function() {
  cached_token <- tuik_auth_cache$access_token
  cached_expiry <- tuik_auth_cache$expires_at

  if (!is.null(cached_token) && !is.null(cached_expiry) && Sys.time() < cached_expiry) {
    return(cached_token)
  }

  token_info <- fetch_tuik_access_token(tuik_api_key())
  token_lifetime <- max(
    token_info$expires_in - tuik_token_expiry_margin_seconds,
    tuik_token_expiry_margin_seconds
  )

  tuik_auth_cache$access_token <- token_info$access_token
  tuik_auth_cache$expires_at <- Sys.time() + token_lifetime

  token_info$access_token
}

#' @noRd
#' @keywords internal
build_sdmx_auth_headers <- function() {
  list(Authorization = paste("Bearer", tuik_sdmx_token()))
}
