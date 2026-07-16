"""TUIK Data — self-contained FastMCP server (single-file deployment build).

Exposes Turkish Statistical Institute (TUIK) data as MCP tools:

- Statistical Data Portal (veriportali.tuik.gov.tr): themes, tables,
  databases, portal resources
- SDMX web service (nsiws.tuik.gov.tr): dataflow structures and observations
- Geographic Portal (cip.tuik.gov.tr): indicator series and map boundaries

This file is intentionally standalone (no local package imports) so hosting
platforms can run it directly as ``server.py``. The installable package with
the same functionality and its test suite lives in ``mcp-server/``; keep the
two in sync when changing behavior.
"""

from __future__ import annotations

import json
import threading
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Annotated, Any, Callable, Literal

import httpx
from fastmcp import FastMCP
from fastmcp.exceptions import ToolError
from pydantic import Field

# ---------------------------------------------------------------------------
# HTTP plumbing
# ---------------------------------------------------------------------------

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/122.0.0.0 Safari/537.36"
)

DEFAULT_TIMEOUT = httpx.Timeout(60.0, connect=20.0)


def browser_headers(lang: str = "en") -> dict[str, str]:
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


def validate_lang(lang: str) -> str:
    if lang not in ("tr", "en"):
        raise ValueError("lang must be 'tr' or 'en'.")
    return lang


# ---------------------------------------------------------------------------
# Statistical Data Portal (veriportali.tuik.gov.tr)
# ---------------------------------------------------------------------------

PORTAL_BASE_URL = "https://veriportali.tuik.gov.tr"

RESOURCE_TYPES = ("press", "database", "istab", "dataflow", "report")

_theme_tree_cache = TTLCache(ttl_seconds=900.0)


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
    validated_lang = validate_lang(lang)
    return _theme_tree_cache.get_or_fetch(
        ("theme_tree", validated_lang),
        lambda: _fetch_theme_tree_uncached(validated_lang),
    )


def list_themes(lang: str = "en") -> list[dict[str, str]]:
    return [
        {"theme_name": node.get("name"), "theme_id": str(node.get("id"))}
        for node in fetch_theme_tree(lang)
    ]


def format_valid_theme_choices(theme_tree: list[dict[str, Any]]) -> str:
    return "\n".join(f"{node.get('id')} = {node.get('name')}" for node in theme_tree)


def find_theme_node(theme: str | int, theme_tree: list[dict[str, Any]]) -> dict[str, Any]:
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


# ---------------------------------------------------------------------------
# SDMX web service (nsiws.tuik.gov.tr)
# ---------------------------------------------------------------------------

SDMX_BASE_URL = "https://nsiws.tuik.gov.tr/rest"

XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"

_structure_cache = TTLCache(ttl_seconds=1800.0, max_entries=32)


def split_dataflow_id(dataflow_id: str) -> tuple[str, str, str]:
    if not isinstance(dataflow_id, str):
        raise ValueError("dataflow_id must be a string.")
    parts = dataflow_id.split(",")
    if len(parts) != 3 or any(not part for part in parts):
        raise ValueError(
            "dataflow_id must be a single SDMX identifier with three "
            "comma-separated parts like 'TR,DF_UHTI_COGRAFI,1.0'."
        )
    return parts[0], parts[1], parts[2]


def build_structure_url(
    dataflow_id: str, detail: str = "Full", references: str = "Descendants"
) -> str:
    agency, flow, version = split_dataflow_id(dataflow_id)
    return (
        f"{SDMX_BASE_URL}/dataflow/{agency}/{flow}/{version}"
        f"?detail={detail}&references={references}"
    )


def build_data_url(
    dataflow_id: str,
    key: str = "ALL",
    start: str | None = None,
    end: str | None = None,
    detail: str = "full",
    dimension_at_observation: str = "TIME_PERIOD",
) -> str:
    split_dataflow_id(dataflow_id)  # validation only
    if not key:
        raise ValueError("key must not be empty.")
    query = [f"detail={detail}", f"dimensionAtObservation={dimension_at_observation}"]
    if start:
        query.append(f"startPeriod={start}")
    if end:
        query.append(f"endPeriod={end}")
    return f"{SDMX_BASE_URL}/data/{dataflow_id}/{key}/?" + "&".join(query)


@dataclass
class DataflowStructure:
    dataflow_id: str
    name: dict[str, str] = field(default_factory=dict)
    dimensions: list[dict[str, Any]] = field(default_factory=list)
    time_dimension: str | None = None
    primary_measure: str | None = None
    attributes: list[dict[str, Any]] = field(default_factory=list)
    codelists: dict[str, dict[str, dict[str, str]]] = field(default_factory=dict)


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _localized_names(element: ET.Element) -> dict[str, str]:
    names: dict[str, str] = {}
    for child in element:
        if _local_name(child.tag) == "Name" and child.text:
            names[child.get(XML_LANG, "")] = child.text.strip()
    return names


def pick_label(names: dict[str, str], lang: str) -> str | None:
    for candidate in (lang, "en", "tr"):
        if names.get(candidate):
            return names[candidate]
    for value in names.values():
        if value:
            return value
    return None


def _find_enumeration_codelist(component: ET.Element) -> str | None:
    for element in component.iter():
        if _local_name(element.tag) == "Enumeration":
            for ref in element:
                if _local_name(ref.tag) == "Ref":
                    return ref.get("id")
    return None


def _concept_id(component: ET.Element) -> str | None:
    for element in component.iter():
        if _local_name(element.tag) == "ConceptIdentity":
            for ref in element:
                if _local_name(ref.tag) == "Ref":
                    return ref.get("id")
    return component.get("id")


def parse_structure_xml(xml_text: str, dataflow_id: str) -> DataflowStructure:
    root = ET.fromstring(xml_text)
    structure = DataflowStructure(dataflow_id=dataflow_id)

    for element in root.iter():
        name = _local_name(element.tag)

        if name == "Dataflow" and not structure.name:
            structure.name = _localized_names(element)

        elif name == "Codelist":
            codelist_id = element.get("id")
            if not codelist_id:
                continue
            codes: dict[str, dict[str, str]] = {}
            for code in element:
                if _local_name(code.tag) == "Code" and code.get("id"):
                    codes[code.get("id")] = _localized_names(code)
            structure.codelists[codelist_id] = codes

        elif name == "Dimension":
            dimension_id = element.get("id") or _concept_id(element)
            structure.dimensions.append(
                {
                    "id": dimension_id,
                    "position": int(element.get("position") or 0),
                    "codelist_id": _find_enumeration_codelist(element),
                }
            )

        elif name == "TimeDimension":
            structure.time_dimension = element.get("id") or "TIME_PERIOD"

        elif name == "PrimaryMeasure":
            structure.primary_measure = element.get("id") or "OBS_VALUE"

        elif name == "Attribute":
            structure.attributes.append(
                {
                    "id": element.get("id") or _concept_id(element),
                    "codelist_id": _find_enumeration_codelist(element),
                }
            )

    structure.dimensions.sort(key=lambda d: d["position"])
    return structure


def _fetch_structure_uncached(dataflow_id: str) -> DataflowStructure:
    url = build_structure_url(dataflow_id)
    response = get_with_retries(
        url,
        headers={
            "Accept": "application/vnd.sdmx.structure+xml;version=2.1, application/xml",
            "User-Agent": USER_AGENT,
        },
    )
    return parse_structure_xml(response.text, dataflow_id)


def fetch_structure(dataflow_id: str) -> DataflowStructure:
    split_dataflow_id(dataflow_id)
    return _structure_cache.get_or_fetch(
        ("structure", dataflow_id),
        lambda: _fetch_structure_uncached(dataflow_id),
    )


def build_label_maps(
    structure: DataflowStructure, lang: str = "en"
) -> dict[str, dict[str, str]]:
    label_maps: dict[str, dict[str, str]] = {}
    for dimension in structure.dimensions:
        codelist_id = dimension.get("codelist_id")
        if not codelist_id or codelist_id not in structure.codelists:
            continue
        codes = structure.codelists[codelist_id]
        label_map = {}
        for code_id, names in codes.items():
            label_map[code_id] = pick_label(names, lang) or code_id
        if label_map:
            label_maps[dimension["id"]] = label_map
    return label_maps


def parse_data_xml(xml_text: str) -> list[dict[str, Any]]:
    """Parse SDMX-ML observations (generic or structure-specific format)."""
    root = ET.fromstring(xml_text)
    if "GenericData" in _local_name(root.tag) or _has_generic_series(root):
        return _parse_generic_data(root)
    return _parse_structure_specific_data(root)


def _has_generic_series(root: ET.Element) -> bool:
    for element in root.iter():
        if _local_name(element.tag) == "SeriesKey":
            return True
    return False


def _parse_generic_data(root: ET.Element) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for element in root.iter():
        if _local_name(element.tag) != "Series":
            continue
        series_key: dict[str, Any] = {}
        observations: list[dict[str, Any]] = []
        for child in element:
            child_name = _local_name(child.tag)
            if child_name in ("SeriesKey", "Attributes"):
                for value in child:
                    if _local_name(value.tag) == "Value" and value.get("id"):
                        series_key[value.get("id")] = value.get("value")
            elif child_name == "Obs":
                obs: dict[str, Any] = {}
                for obs_child in child:
                    obs_child_name = _local_name(obs_child.tag)
                    if obs_child_name == "ObsDimension":
                        obs["obsTime"] = obs_child.get("value")
                    elif obs_child_name == "ObsValue":
                        obs["obsValue"] = _coerce_number(obs_child.get("value"))
                    elif obs_child_name == "Attributes":
                        for value in obs_child:
                            if _local_name(value.tag) == "Value" and value.get("id"):
                                obs[value.get("id")] = value.get("value")
                observations.append(obs)
        for obs in observations:
            records.append({**series_key, **obs})
    return records


def _parse_structure_specific_data(root: ET.Element) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for dataset in root.iter():
        if _local_name(dataset.tag) != "DataSet":
            continue
        for series in dataset:
            series_name = _local_name(series.tag)
            if series_name == "Series":
                series_key = {
                    key: value
                    for key, value in series.attrib.items()
                    if not key.startswith("{")
                }
                for obs in series:
                    if _local_name(obs.tag) != "Obs":
                        continue
                    record = dict(series_key)
                    record.update(_structure_specific_obs(obs))
                    records.append(record)
            elif series_name == "Obs":
                records.append(_structure_specific_obs(series))
    return records


def _structure_specific_obs(obs: ET.Element) -> dict[str, Any]:
    record: dict[str, Any] = {}
    for key, value in obs.attrib.items():
        if key.startswith("{"):
            continue
        if key == "TIME_PERIOD":
            record["obsTime"] = value
        elif key == "OBS_VALUE":
            record["obsValue"] = _coerce_number(value)
        else:
            record[key] = value
    return record


def _coerce_number(value: str | None) -> Any:
    if value is None:
        return None
    stripped = value.strip()
    if not stripped:
        return None
    try:
        as_float = float(stripped)
    except ValueError:
        return stripped
    if as_float.is_integer() and "e" not in stripped.lower() and "." not in stripped:
        return int(as_float)
    return as_float


def _strip_strings(record: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value.strip() if isinstance(value, str) else value
        for key, value in record.items()
    }


def clean_records(
    records: list[dict[str, Any]],
    label_maps: dict[str, dict[str, str]] | None = None,
) -> list[dict[str, Any]]:
    """Drop invariant dimensions and append ``*_label`` columns."""
    if not records:
        return []
    label_maps = label_maps or {}
    records = [_strip_strings(record) for record in records]

    protected = ("obsTime", "obsValue")
    columns: list[str] = []
    for record in records:
        for key in record:
            if key not in columns:
                columns.append(key)
    candidate_columns = [column for column in columns if column not in protected]

    kept_columns = []
    for column in candidate_columns:
        values = {
            record.get(column)
            for record in records
            if record.get(column) is not None
        }
        if len(values) > 1:
            kept_columns.append(column)

    cleaned: list[dict[str, Any]] = []
    for record in records:
        row: dict[str, Any] = {}
        for column in kept_columns:
            value = record.get(column)
            row[column] = value
            label_map = label_maps.get(column)
            if label_map is not None:
                label = label_map.get(str(value), value)
                row[f"{column}_label"] = label
        for column in protected:
            if column in record:
                row[column] = record[column]
        cleaned.append(row)

    for column in kept_columns:
        label_column = f"{column}_label"
        if not cleaned or label_column not in cleaned[0]:
            continue
        if all(str(row.get(label_column)) == str(row.get(column)) for row in cleaned):
            for row in cleaned:
                row.pop(label_column, None)

    return cleaned


def fetch_data(
    dataflow_id: str,
    key: str = "ALL",
    start: str | None = None,
    end: str | None = None,
    detail: str = "full",
    dimension_at_observation: str = "TIME_PERIOD",
) -> list[dict[str, Any]]:
    url = build_data_url(
        dataflow_id,
        key=key,
        start=start,
        end=end,
        detail=detail,
        dimension_at_observation=dimension_at_observation,
    )
    response = get_with_retries(
        url,
        headers={
            "Accept": (
                "application/vnd.sdmx.genericdata+xml;version=2.1, "
                "application/vnd.sdmx.structurespecificdata+xml;version=2.1, "
                "application/xml"
            ),
            "User-Agent": USER_AGENT,
        },
    )
    return parse_data_xml(response.text)


# ---------------------------------------------------------------------------
# Geographic Portal (cip.tuik.gov.tr)
# ---------------------------------------------------------------------------

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


def _pick_geo_label(label_tr: Any, label_en: Any, lang: str) -> Any:
    if lang == "en" and isinstance(label_en, str) and label_en.strip():
        return label_en
    return label_tr


def _fetch_json(url: str) -> Any:
    response = get_with_retries(url, headers={"User-Agent": USER_AGENT})
    return json.loads(response.text)


def _fetch_side_menu() -> dict[str, Any]:
    return _side_menu_cache.get_or_fetch("side_menu", lambda: _fetch_json(SIDE_MENU_URL))


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
    if not raw_dates or len(str(raw_dates[0])) != 6:
        return [str(date) for date in raw_dates]
    return [f"{str(date)[:4]}-{str(date)[4:6]}" for date in raw_dates]


def fetch_variable_data(
    var_num: str,
    var_level: int | None = None,
    lang: str = "en",
) -> dict[str, Any]:
    validated_lang = validate_lang(lang)
    if not isinstance(var_num, str) or not var_num.strip():
        raise ValueError("var_num must be a non-empty string.")

    metadata_rows = _variable_metadata(validated_lang)
    series = next((row for row in metadata_rows if row["var_num"] == var_num), None)
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
        raise ValueError("var_level must be 2, 3, or 4 (NUTS-2, NUTS-3, or LAU-1).")
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
                if key == "type"
                and isinstance(inner := value[key], list)
                and len(inner) == 1
                else _unwrap_singleton_lists(value[key])
            )
            for key in value
        }
    if isinstance(value, list):
        return [_unwrap_singleton_lists(item) for item in value]
    return value


# ---------------------------------------------------------------------------
# MCP server and tools
# ---------------------------------------------------------------------------

mcp = FastMCP(
    name="TUIK Data",
    instructions=(
        "Access Turkish Statistical Institute (TUIK) data.\n\n"
        "Typical statistical workflow:\n"
        "1. statistical_themes() to list themes.\n"
        "2. statistical_tables(theme) or statistical_resources(theme) to find "
        "datasets; rows with node_type 'dataflow' carry an SDMX dataflow_id.\n"
        "3. statistical_data_structure(dataflow_id) to inspect dimensions and "
        "codes (needed to build a key that narrows a large download).\n"
        "4. statistical_data(dataflow_id, key=...) to download observations.\n\n"
        "Typical geographic workflow:\n"
        "1. geo_variables() to list indicator series.\n"
        "2. geo_data(var_num, var_level) to download values by region code.\n"
        "3. geo_map(level) for region codes/names; include_geometry=True "
        "returns GeoJSON boundaries for mapping."
    ),
)

LangParam = Annotated[
    Literal["en", "tr"],
    Field(description="Language for names and labels: 'en' (default) or 'tr'."),
]


def _tool_guard(fn, *args: Any, **kwargs: Any) -> Any:
    try:
        return fn(*args, **kwargs)
    except ToolError:
        raise
    except (ValueError, RuntimeError) as error:
        raise ToolError(str(error)) from error
    except Exception as error:  # noqa: BLE001 — surface network errors readably
        raise ToolError(f"TUIK request failed: {error}") from error


@mcp.tool
def statistical_themes(lang: LangParam = "en") -> list[dict[str, Any]]:
    """List all top-level statistical themes from the TUIK data portal.

    Theme IDs are used with statistical_tables, statistical_databases, and
    statistical_resources to discover datasets.
    """
    return _tool_guard(list_themes, lang=lang)


@mcp.tool
def statistical_resources(
    theme: Annotated[
        str,
        Field(description="A single theme ID from statistical_themes(), e.g. '11'."),
    ],
    type: Annotated[
        list[Literal["dataflow", "istab", "database", "press", "report"]] | None,
        Field(
            description=(
                "Optional resource types to keep. Omit for all resources. "
                "'dataflow' rows work with statistical_data; 'istab', 'press', "
                "and 'report' rows expose downloadable/browsable URLs; "
                "'database' rows point to the legacy interactive interface."
            )
        ),
    ] = None,
    lang: LangParam = "en",
) -> list[dict[str, Any]]:
    """List all portal resources for a theme (full catalog).

    Each record has theme_name, theme_id, resource_name, resource_type,
    dataflow_id (SDMX identifier, only for 'dataflow' rows), and resource_url.
    """
    return _tool_guard(theme_resources, theme, types=type, lang=lang)


@mcp.tool
def statistical_tables(
    theme: Annotated[
        str,
        Field(description="A single theme ID from statistical_themes(), e.g. '11'."),
    ],
    lang: LangParam = "en",
) -> list[dict[str, Any]]:
    """List statistical tables (SDMX dataflows and file downloads) for a theme.

    Rows with node_type 'dataflow' include a dataflow_id usable with
    statistical_data; 'istab' rows are direct file downloads (table_url).
    """
    rows = _tool_guard(theme_resources, theme, types=["dataflow", "istab"], lang=lang)
    return [
        {
            "theme_name": row["theme_name"],
            "theme_id": row["theme_id"],
            "table_name": row["resource_name"],
            "node_type": row["resource_type"],
            "dataflow_id": row["dataflow_id"],
            "table_url": row["resource_url"],
        }
        for row in rows
    ]


@mcp.tool
def statistical_databases(
    theme: Annotated[
        str,
        Field(description="A single theme ID from statistical_themes(), e.g. '11'."),
    ],
    lang: LangParam = "en",
) -> list[dict[str, Any]]:
    """List legacy interactive database URLs for a theme.

    These link to the biruni.tuik.gov.tr query interface, not direct
    downloads. Prefer SDMX dataflows (statistical_tables + statistical_data)
    for machine-readable data.
    """
    rows = _tool_guard(theme_resources, theme, types=["database"], lang=lang)
    return [
        {
            "theme_name": row["theme_name"],
            "theme_id": row["theme_id"],
            "db_name": row["resource_name"],
            "db_url": row["resource_url"],
        }
        for row in rows
    ]


@mcp.tool
def statistical_data_structure(
    dataflow_id: Annotated[
        str,
        Field(
            description=(
                "SDMX dataflow identifier with three comma-separated parts, "
                "e.g. 'TR,DF_ADNKS_T26,1.0'. Discover via statistical_tables."
            )
        ),
    ],
    lang: LangParam = "en",
    max_codes_per_dimension: Annotated[
        int,
        Field(
            description=(
                "Cap on codes listed per dimension (default 100). Dimensions "
                "with more codes are truncated; total_codes reports the real "
                "count."
            ),
            ge=1,
        ),
    ] = 100,
) -> dict[str, Any]:
    """Describe an SDMX dataflow: dimension order and available codes.

    Use this before statistical_data to build a key. The SDMX key is the
    dot-separated dimension codes in the order listed here (e.g. '1.2.TR'),
    with empty segments meaning 'all values' (e.g. '..TR'). 'ALL' selects
    everything.
    """
    structure = _tool_guard(fetch_structure, dataflow_id)
    label_maps = build_label_maps(structure, lang=lang)

    dimensions = []
    for position, dimension in enumerate(structure.dimensions, start=1):
        label_map = label_maps.get(dimension["id"], {})
        codes = [
            {"code": code, "label": label}
            for code, label in list(label_map.items())[:max_codes_per_dimension]
        ]
        dimensions.append(
            {
                "id": dimension["id"],
                "key_position": position,
                "codelist_id": dimension["codelist_id"],
                "total_codes": len(label_map),
                "codes_truncated": len(label_map) > max_codes_per_dimension,
                "codes": codes,
            }
        )

    return {
        "dataflow_id": dataflow_id,
        "name": pick_label(structure.name, lang),
        "time_dimension": structure.time_dimension or "TIME_PERIOD",
        "key_template": ".".join(d["id"] for d in structure.dimensions),
        "dimensions": dimensions,
    }


@mcp.tool
def statistical_data(
    dataflow_id: Annotated[
        str,
        Field(
            description=(
                "SDMX dataflow identifier with three comma-separated parts, "
                "e.g. 'TR,DF_ADNKS_T26,1.0'. Discover via statistical_tables."
            )
        ),
    ],
    key: Annotated[
        str,
        Field(
            description=(
                "SDMX key path constraining dimensions, dot-separated in "
                "dimension order (see statistical_data_structure). 'ALL' "
                "(default) downloads everything; empty segments mean all "
                "values for that dimension, e.g. '..TR'."
            )
        ),
    ] = "ALL",
    start: Annotated[
        str | None,
        Field(description="Optional start period, e.g. '2020'."),
    ] = None,
    end: Annotated[
        str | None,
        Field(description="Optional end period, e.g. '2023'."),
    ] = None,
    lang: LangParam = "en",
    max_rows: Annotated[
        int,
        Field(
            description=(
                "Cap on returned rows (default 2000). If truncated is true, "
                "narrow the key or period, or paginate with offset."
            ),
            ge=1,
        ),
    ] = 2000,
    offset: Annotated[
        int,
        Field(description="Rows to skip before returning (pagination).", ge=0),
    ] = 0,
) -> dict[str, Any]:
    """Download SDMX observations from TUIK as long-form records.

    Matches the tuikr R package output: dimensions that never vary are
    dropped, obsTime/obsValue hold the period and value, and coded
    dimensions gain '<dimension>_label' columns with human-readable labels.
    """
    records = _tool_guard(fetch_data, dataflow_id, key=key, start=start, end=end)
    structure = _tool_guard(fetch_structure, dataflow_id)
    label_maps = build_label_maps(structure, lang=lang)
    cleaned = clean_records(records, label_maps=label_maps)

    total_rows = len(cleaned)
    page = cleaned[offset : offset + max_rows]
    columns = list(page[0].keys()) if page else []

    return {
        "dataflow_id": dataflow_id,
        "name": pick_label(structure.name, lang),
        "total_rows": total_rows,
        "returned_rows": len(page),
        "offset": offset,
        "truncated": offset + len(page) < total_rows,
        "columns": columns,
        "rows": page,
    }


@mcp.tool
def geo_variables(lang: LangParam = "en") -> list[dict[str, Any]]:
    """List all geographic indicator series from the TUIK geographic portal.

    Each record has var_name, var_num (pass to geo_data), var_levels
    (available NUTS levels: 2=NUTS-2 regions, 3=provinces, 4=districts), and
    var_period ('yillik' yearly or 'aylik' monthly).
    """
    return _tool_guard(list_variables, lang=lang)


@mcp.tool
def geo_data(
    var_num: Annotated[
        str,
        Field(
            description=(
                "Data series number from geo_variables(), "
                "e.g. 'SNM-GK160951-O33303'."
            )
        ),
    ],
    var_level: Annotated[
        int | None,
        Field(
            description=(
                "NUTS level: 2 (NUTS-2 regions), 3 (provinces), or 4 "
                "(districts). Optional when the series has only one level."
            )
        ),
    ] = None,
    lang: LangParam = "en",
) -> dict[str, Any]:
    """Download values for a geographic indicator series.

    Returns long-form rows of {code, date, value} where code is the
    geographic unit code (join with geo_map codes) and date is YYYY or
    YYYY-MM.
    """
    return _tool_guard(fetch_variable_data, var_num, var_level=var_level, lang=lang)


@mcp.tool
def geo_map(
    level: Annotated[
        Literal[2, 3, 4, 9],
        Field(
            description=(
                "Administrative level: 2 = NUTS-2 regions (26), 3 = provinces "
                "(81), 4 = districts (973), 9 = settlement points (1003)."
            )
        ),
    ],
    include_geometry: Annotated[
        bool,
        Field(
            description=(
                "If true, return the full GeoJSON FeatureCollection (WGS 84) "
                "for mapping — large payloads at levels 4 and 9. Default "
                "false returns the attribute table only (codes and names)."
            )
        ),
    ] = False,
) -> dict[str, Any]:
    """Download TUIK boundary data for an administrative level.

    Without geometry: attribute records (code, NUTS codes, Turkish name) for
    joining with geo_data. With geometry: valid GeoJSON (TUIK's malformed
    array-wrapped 'type' fields are repaired).
    """
    return _tool_guard(fetch_map, level, include_geometry=include_geometry)


if __name__ == "__main__":
    mcp.run()
