"""TUIK Geographic Portal client (cip.tuik.gov.tr).

Mirrors ``geo_data()`` and ``geo_map()`` from the ``tuikr`` R package:
variable metadata comes from ``assets/sideMenu.json``, indicator values from
``Home/GetMapData``, and boundary geometries from ``assets/geometri/*.json``.
"""

from __future__ import annotations

import json
from typing import Any

from .http_client import TTLCache, USER_AGENT, get_with_retries

GEO_BASE_URL = "https://cip.tuik.gov.tr"
SIDE_MENU_URL = f"{GEO_BASE_URL}/assets/sideMenu.json?v=2.000"

MAP_URLS = {
    2: f"{GEO_BASE_URL}/assets/geometri/nuts2.json",
    3: f"{GEO_BASE_URL}/assets/geometri/nuts3.json",
    4: f"{GEO_BASE_URL}/assets/geometri/nuts4.json",
    9: f"{GEO_BASE_URL}/assets/geometri/yerlesim_noktalari.json",
}

DATA_LEVELS = (2, 3, 4)

_side_menu_cache = TTLCache(ttl_seconds=1800.0, max_entries=4)


def validate_lang(lang: str) -> str:
    if lang not in ("tr", "en"):
        raise ValueError("lang must be 'tr' or 'en'.")
    return lang


def _pick_geo_label(label_tr: Any, label_en: Any, lang: str) -> Any:
    if lang == "en" and isinstance(label_en, str) and label_en.strip():
        return label_en
    return label_tr


def _fetch_json(url: str) -> Any:
    response = get_with_retries(url, headers={"User-Agent": USER_AGENT})
    return json.loads(response.text)


def _fetch_side_menu() -> dict[str, Any]:
    return _side_menu_cache.get_or_fetch(
        "side_menu", lambda: _fetch_json(SIDE_MENU_URL)
    )


def _variable_metadata(lang: str) -> list[dict[str, Any]]:
    document = _fetch_side_menu()
    submenu_items: list[dict[str, Any]] = []
    for menu in document.get("menu", []):
        submenu_items.extend(menu.get("subMenu") or [])

    return [
        {
            "var_name": _pick_geo_label(
                item.get("gostergeAdi"), item.get("gostergeAdiEn"), lang
            ),
            "var_num": item.get("gostergeNo"),
            "var_levels": item.get("duzeyler"),
            "var_period": item.get("period"),
            "var_source": item.get("kaynak"),
            "var_recordnum": item.get("kayitSayisi"),
        }
        for item in submenu_items
    ]


def list_variables(lang: str = "en") -> list[dict[str, Any]]:
    """Metadata for all geographic indicator series (metadata mode)."""
    validated_lang = validate_lang(lang)
    return [
        {
            "var_name": row["var_name"],
            "var_num": row["var_num"],
            "var_levels": row["var_levels"],
            "var_period": row["var_period"],
        }
        for row in _variable_metadata(validated_lang)
    ]


def _normalize_dates(raw_dates: list[str]) -> list[str]:
    """Monthly periods arrive as YYYYMM; convert to YYYY-MM."""
    if not raw_dates or len(str(raw_dates[0])) != 6:
        return [str(date) for date in raw_dates]
    return [f"{str(date)[:4]}-{str(date)[4:6]}" for date in raw_dates]


def fetch_variable_data(
    var_num: str,
    var_level: int | None = None,
    lang: str = "en",
) -> dict[str, Any]:
    """Download one indicator series at a NUTS level as long-form records."""
    validated_lang = validate_lang(lang)
    if not isinstance(var_num, str) or not var_num.strip():
        raise ValueError("var_num must be a non-empty string.")

    metadata_rows = _variable_metadata(validated_lang)
    series = next(
        (row for row in metadata_rows if row["var_num"] == var_num), None
    )
    if series is None:
        raise ValueError(
            "var_num must match one of the values returned by geo_variables()."
        )

    available_levels = sorted({int(level) for level in (series["var_levels"] or [])})

    if var_level is None:
        if len(available_levels) == 1:
            var_level = available_levels[0]
        else:
            raise ValueError(
                f"var_level is required for {var_num}. "
                f"Valid levels: {', '.join(map(str, available_levels))}"
            )

    if var_level not in DATA_LEVELS:
        raise ValueError(
            "var_level must be 2, 3, or 4 (NUTS-2, NUTS-3, or LAU-1)."
        )
    if var_level not in available_levels:
        raise ValueError(
            f"var_level must be one of the available levels for {var_num}: "
            f"{', '.join(map(str, available_levels))}"
        )

    query_url = (
        f"{GEO_BASE_URL}/Home/GetMapData?kaynak={series['var_source']}"
        f"&duzey={var_level}"
        f"&gostergeNo={series['var_num']}"
        f"&kayitSayisi={series['var_recordnum']}"
        f"&period={series['var_period']}"
    )

    try:
        payload = _fetch_json(query_url)
    except Exception as error:  # noqa: BLE001 — match R package behavior
        raise RuntimeError(
            f"Data '{var_num}' is not available at NUTS level {var_level}."
        ) from error

    variable_label = _pick_geo_label(
        payload.get("gosterge_ad"), payload.get("gosterge_ad_ing"), validated_lang
    )
    dates = _normalize_dates(payload.get("tarihler") or [])

    rows: list[dict[str, Any]] = []
    for entry in payload.get("veriler") or []:
        # The code field name varies; like the R package, take the first
        # non-"veri" field positionally as the geographic unit code.
        code_keys = [key for key in entry if key != "veri"]
        code = str(entry[code_keys[0]]) if code_keys else ""
        values = entry.get("veri") or []
        for date, value in zip(dates, values):
            rows.append({"code": code, "date": date, "value": value})

    return {
        "var_num": var_num,
        "var_name": variable_label,
        "var_level": var_level,
        "rows": rows,
    }


def fetch_map(level: int, include_geometry: bool = False) -> dict[str, Any]:
    """Download boundary data for an administrative level.

    Returns GeoJSON when ``include_geometry`` is true, otherwise the
    attribute table only (equivalent to ``geo_map(dataframe = TRUE)`` in R).
    Fixes the upstream TUIK defect where ``"type"`` values arrive
    array-wrapped (``["FeatureCollection"]``), which is invalid GeoJSON.
    """
    if level not in MAP_URLS:
        raise ValueError("level must be a single value of 2, 3, 4, or 9.")

    try:
        payload = _fetch_json(MAP_URLS[level])
    except Exception as error:  # noqa: BLE001 — match R package behavior
        raise RuntimeError(f"Map data not available at level {level}.") from error

    payload = _unwrap_singleton_lists(payload)

    features = payload.get("features") or []
    attributes: list[dict[str, Any]] = []
    for feature in features:
        properties = dict(feature.get("properties") or {})
        properties.pop("name", None)
        properties = {
            key: value.strip() if isinstance(value, str) else value
            for key, value in properties.items()
        }
        if level != 9 and "duzeyKodu" in properties:
            properties["code"] = str(properties.pop("duzeyKodu"))
        feature["properties"] = properties
        attributes.append(properties)

    if include_geometry:
        return {"level": level, "geojson": payload, "feature_count": len(features)}
    return {"level": level, "attributes": attributes, "feature_count": len(features)}


def _unwrap_singleton_lists(value: Any) -> Any:
    """Fix TUIK's array-wrapped GeoJSON ``type`` fields recursively."""
    if isinstance(value, dict):
        return {
            key: (
                inner[0]
                if key == "type" and isinstance(inner := value[key], list) and len(inner) == 1
                else _unwrap_singleton_lists(value[key])
            )
            for key in value
        }
    if isinstance(value, list):
        return [_unwrap_singleton_lists(item) for item in value]
    return value


def clear_cache() -> None:
    _side_menu_cache.clear()
