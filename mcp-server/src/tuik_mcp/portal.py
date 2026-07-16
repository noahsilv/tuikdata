"""TUIK Statistical Data Portal client (veriportali.tuik.gov.tr).

Mirrors the theme-tree access pattern of the ``tuikr`` R package:
a browser-like landing-page request establishes session cookies, then the
JSON API returns the hierarchical theme tree from which themes, tables,
databases, and other portal resources are extracted.
"""

from __future__ import annotations

from typing import Any

import httpx

from .http_client import DEFAULT_TIMEOUT, TTLCache, browser_headers, get_with_retries

PORTAL_BASE_URL = "https://veriportali.tuik.gov.tr"

RESOURCE_TYPES = ("press", "database", "istab", "dataflow", "report")

_theme_tree_cache = TTLCache(ttl_seconds=900.0)


def validate_lang(lang: str) -> str:
    if lang not in ("tr", "en"):
        raise ValueError("lang must be 'tr' or 'en'.")
    return lang


def _portal_urls(lang: str) -> tuple[str, str]:
    page_url = f"{PORTAL_BASE_URL}/{lang}/statistical-themes"
    api_url = f"{PORTAL_BASE_URL}/api/{lang}/data/statistical-themes"
    return page_url, api_url


def _fetch_theme_tree_uncached(lang: str) -> list[dict[str, Any]]:
    page_url, api_url = _portal_urls(lang)
    headers = browser_headers(lang)

    with httpx.Client(timeout=DEFAULT_TIMEOUT, follow_redirects=True) as client:
        # Landing-page request establishes the session cookies the API needs.
        get_with_retries(page_url, headers=headers, client=client)

        api_headers = {
            **headers,
            "Referer": page_url,
            "Origin": PORTAL_BASE_URL,
            "X-Requested-With": "XMLHttpRequest",
        }
        response = get_with_retries(api_url, headers=api_headers, client=client)

    payload = response.json()
    if isinstance(payload, dict) and payload.get("isError"):
        raise RuntimeError(f"TUIK API returned an error: {payload.get('message')}")

    data = payload.get("data") if isinstance(payload, dict) else payload
    if not isinstance(data, list):
        raise RuntimeError("Unexpected theme tree payload from TUIK portal API.")
    return data


def fetch_theme_tree(lang: str = "en") -> list[dict[str, Any]]:
    """Fetch (and cache) the full hierarchical theme tree."""
    validated_lang = validate_lang(lang)
    return _theme_tree_cache.get_or_fetch(
        ("theme_tree", validated_lang),
        lambda: _fetch_theme_tree_uncached(validated_lang),
    )


def list_themes(lang: str = "en") -> list[dict[str, str]]:
    """Top-level statistical themes as ``{theme_name, theme_id}`` records."""
    return [
        {"theme_name": node.get("name"), "theme_id": str(node.get("id"))}
        for node in fetch_theme_tree(lang)
    ]


def format_valid_theme_choices(theme_tree: list[dict[str, Any]]) -> str:
    return "\n".join(
        f"{node.get('id')} = {node.get('name')}" for node in theme_tree
    )


def find_theme_node(theme: str | int, theme_tree: list[dict[str, Any]]) -> dict[str, Any]:
    """Validate a single theme ID and return its node from the tree."""
    theme_id = str(theme).strip()
    for node in theme_tree:
        if str(node.get("id")) == theme_id:
            return node
    raise ValueError(
        "theme must be one of the available theme IDs:\n"
        + format_valid_theme_choices(theme_tree)
    )


def collect_nodes_by_icon(
    node_list: list[dict[str, Any]] | None, target_icons: tuple[str, ...]
) -> list[dict[str, Any]]:
    """Recursively collect nodes whose ``icon`` matches one of the targets."""
    matched: list[dict[str, Any]] = []
    for node in node_list or []:
        if node.get("icon") in target_icons:
            matched.append(node)
        children = node.get("children")
        if children:
            matched.extend(collect_nodes_by_icon(children, target_icons))
    return matched


def normalize_portal_url(raw_url: str) -> str:
    if raw_url.startswith(("http://", "https://")):
        return raw_url
    return f"{PORTAL_BASE_URL}{raw_url}"


def extract_dataflow_id(raw_url: str) -> str:
    """SDMX dataflow identifier is the last path component of a databrowser URL."""
    return raw_url.rstrip("/").rsplit("/", 1)[-1]


def validate_resource_types(types: list[str] | None) -> list[str] | None:
    if types is None:
        return None
    invalid = [t for t in types if t not in RESOURCE_TYPES]
    if invalid or not types:
        raise ValueError(
            "type must be one or more of: " + ", ".join(RESOURCE_TYPES) + "."
        )
    return list(dict.fromkeys(types))


def theme_resources(
    theme: str | int,
    types: list[str] | None = None,
    lang: str = "en",
) -> list[dict[str, Any]]:
    """All supported resource nodes for a theme, optionally filtered by type."""
    validated_types = validate_resource_types(types)
    theme_tree = fetch_theme_tree(lang)
    theme_node = find_theme_node(theme, theme_tree)

    resource_nodes = collect_nodes_by_icon(theme_node.get("children"), RESOURCE_TYPES)

    rows = []
    for node in resource_nodes:
        resource_type = node.get("icon")
        raw_url = node.get("url") or ""
        rows.append(
            {
                "theme_name": theme_node.get("name"),
                "theme_id": str(theme_node.get("id")),
                "resource_name": node.get("name"),
                "resource_type": resource_type,
                "dataflow_id": (
                    extract_dataflow_id(raw_url) if resource_type == "dataflow" else None
                ),
                "resource_url": normalize_portal_url(raw_url),
            }
        )

    if validated_types is not None:
        rows = [row for row in rows if row["resource_type"] in validated_types]
    return rows


def clear_cache() -> None:
    _theme_tree_cache.clear()
