"""TUIK SDMX authentication: exchange an API key for short-lived Bearer tokens.

TUIK protects its SDMX web service (nsiws.tuik.gov.tr) behind Bearer tokens
issued by the TUIK login service (Keycloak). Users generate a personal API
key on the data portal (register at https://veriportali.tuik.gov.tr/, verify
a phone number, then 'User Information' -> API key) and supply it via the
``TUIK_API_KEY`` environment variable. This module exchanges that key for
access tokens (default lifetime ~300s) and caches them until shortly before
they expire.
"""

from __future__ import annotations

import os
import threading
import time

import httpx

from .http_client import DEFAULT_TIMEOUT

TOKEN_URL = "https://giris.tuik.gov.tr/realms/web/protocol/openid-connect/token"
TOKEN_CLIENT_ID = "nsi-ws-consumer"
TOKEN_EXPIRY_MARGIN_SECONDS = 30.0
API_KEY_ENV_VAR = "TUIK_API_KEY"

MISSING_KEY_MESSAGE = (
    "TUIK SDMX requests require an API key in the TUIK_API_KEY environment "
    "variable. Register at https://veriportali.tuik.gov.tr/, verify your "
    "phone number, and generate an API key under 'User Information'."
)


class TuikAuthError(RuntimeError):
    """Raised when a TUIK SDMX access token cannot be obtained."""


def _fetch_access_token(api_key: str) -> tuple[str, float]:
    """POST the API key to the TUIK login service and return (token, lifetime)."""
    response = httpx.post(
        TOKEN_URL,
        data={
            "grant_type": "password",
            "client_id": TOKEN_CLIENT_ID,
            "api_key": api_key,
        },
        timeout=DEFAULT_TIMEOUT,
    )
    if response.status_code >= 400:
        raise TuikAuthError(
            f"TUIK login service rejected the API key (HTTP {response.status_code}). "
            "Check that TUIK_API_KEY holds a valid key generated at "
            "https://veriportali.tuik.gov.tr/ under 'User Information'."
        )

    payload = response.json()
    token = payload.get("access_token")
    if not token:
        raise TuikAuthError(
            "TUIK login service response did not include an access token."
        )

    try:
        expires_in = float(payload.get("expires_in") or 300.0)
    except (TypeError, ValueError):
        expires_in = 300.0
    if expires_in <= 0:
        expires_in = 300.0

    return token, expires_in


class TokenManager:
    """Thread-safe cache for a single TUIK SDMX access token."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._token: str | None = None
        self._expires_at = 0.0

    def token(self) -> str:
        with self._lock:
            if self._token and time.monotonic() < self._expires_at:
                return self._token

            api_key = os.environ.get(API_KEY_ENV_VAR, "").strip()
            if not api_key:
                raise TuikAuthError(MISSING_KEY_MESSAGE)

            token, expires_in = _fetch_access_token(api_key)
            self._token = token
            self._expires_at = time.monotonic() + max(
                expires_in - TOKEN_EXPIRY_MARGIN_SECONDS,
                TOKEN_EXPIRY_MARGIN_SECONDS,
            )
            return token

    def clear(self) -> None:
        with self._lock:
            self._token = None
            self._expires_at = 0.0


_token_manager = TokenManager()


def sdmx_auth_headers() -> dict[str, str]:
    """Authorization header for TUIK SDMX requests, refreshing the token as needed."""
    return {"Authorization": f"Bearer {_token_manager.token()}"}


def clear_token_cache() -> None:
    _token_manager.clear()
