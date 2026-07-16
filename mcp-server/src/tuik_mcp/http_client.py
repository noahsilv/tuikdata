"""Shared HTTP plumbing: browser-like headers, retries, and a small TTL cache."""

from __future__ import annotations

import threading
import time
from typing import Any, Callable

import httpx

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/122.0.0.0 Safari/537.36"
)

DEFAULT_TIMEOUT = httpx.Timeout(60.0, connect=20.0)


def browser_headers(lang: str = "en") -> dict[str, str]:
    """Headers matching what the TUIK portal expects from a browser session."""
    accept_language = (
        "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7"
        if lang == "tr"
        else "en-US,en;q=0.9,tr-TR;q=0.8,tr;q=0.7"
    )
    return {
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": accept_language,
        "User-Agent": USER_AGENT,
    }


class TTLCache:
    """Minimal thread-safe TTL cache for portal/SDMX metadata responses."""

    def __init__(self, ttl_seconds: float = 900.0, max_entries: int = 64) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max_entries
        self._lock = threading.Lock()
        self._entries: dict[Any, tuple[float, Any]] = {}

    def get_or_fetch(self, key: Any, fetch: Callable[[], Any]) -> Any:
        now = time.monotonic()
        with self._lock:
            hit = self._entries.get(key)
            if hit is not None and now - hit[0] < self._ttl:
                return hit[1]

        value = fetch()

        with self._lock:
            if len(self._entries) >= self._max_entries:
                oldest = min(self._entries, key=lambda k: self._entries[k][0])
                self._entries.pop(oldest, None)
            self._entries[key] = (time.monotonic(), value)
        return value

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()


def get_with_retries(
    url: str,
    *,
    headers: dict[str, str] | None = None,
    client: httpx.Client | None = None,
    retries: int = 2,
    backoff_seconds: float = 1.5,
) -> httpx.Response:
    """GET a URL, retrying transient network errors and 5xx responses."""
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            if client is not None:
                response = client.get(url, headers=headers)
            else:
                with httpx.Client(
                    timeout=DEFAULT_TIMEOUT, follow_redirects=True
                ) as one_shot:
                    response = one_shot.get(url, headers=headers)
            if response.status_code >= 500 and attempt < retries:
                last_error = httpx.HTTPStatusError(
                    f"server error {response.status_code}",
                    request=response.request,
                    response=response,
                )
                time.sleep(backoff_seconds * (2**attempt))
                continue
            response.raise_for_status()
            return response
        except (httpx.TransportError, httpx.HTTPStatusError) as error:
            last_error = error
            if attempt < retries and not (
                isinstance(error, httpx.HTTPStatusError)
                and error.response.status_code < 500
            ):
                time.sleep(backoff_seconds * (2**attempt))
                continue
            raise
    raise last_error if last_error else RuntimeError(f"failed to fetch {url}")
