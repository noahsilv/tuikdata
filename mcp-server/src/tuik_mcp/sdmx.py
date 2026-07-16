"""TUIK SDMX web service client (nsiws.tuik.gov.tr).

Implements SDMX 2.1 REST access without heavy SDMX dependencies:

- ``fetch_structure()`` parses a dataflow's data structure definition
  (dimension order, codelists, localized labels).
- ``fetch_data()`` parses observation data in either the *generic* or the
  *structure-specific* SDMX-ML flavor, whichever the service returns.
- ``clean_records()`` reproduces the ``tuikr`` R package post-processing:
  invariant dimensions are dropped and ``*_label`` columns are appended for
  coded dimensions whose labels differ from the codes.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Any

from .http_client import TTLCache, USER_AGENT, get_with_retries

SDMX_BASE_URL = "https://nsiws.tuik.gov.tr/rest"

XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"

_structure_cache = TTLCache(ttl_seconds=1800.0, max_entries=32)


# ---------------------------------------------------------------------------
# Identifiers and URLs
# ---------------------------------------------------------------------------


def split_dataflow_id(dataflow_id: str) -> tuple[str, str, str]:
    """Split ``'TR,DF_UHTI_COGRAFI,1.0'`` into (agency, flow, version)."""
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


# ---------------------------------------------------------------------------
# Structure (DSD + codelists)
# ---------------------------------------------------------------------------


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
    """Collect ``<Name xml:lang="..">`` children into a lang→text dict."""
    names: dict[str, str] = {}
    for child in element:
        if _local_name(child.tag) == "Name" and child.text:
            names[child.get(XML_LANG, "")] = child.text.strip()
    return names


def pick_label(names: dict[str, str], lang: str) -> str | None:
    """Prefer the requested language, then English, Turkish, or any label."""
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
    """Fetch (and cache) the data structure definition for a dataflow."""
    split_dataflow_id(dataflow_id)
    return _structure_cache.get_or_fetch(
        ("structure", dataflow_id),
        lambda: _fetch_structure_uncached(dataflow_id),
    )


def build_label_maps(
    structure: DataflowStructure, lang: str = "en"
) -> dict[str, dict[str, str]]:
    """Dimension id → {code → localized label} for coded dimensions."""
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


# ---------------------------------------------------------------------------
# Data (observations)
# ---------------------------------------------------------------------------


def parse_data_xml(xml_text: str) -> list[dict[str, Any]]:
    """Parse SDMX-ML observations into long-form records.

    Handles both the *generic* and *structure-specific* data formats.
    Records use ``obsTime``/``obsValue`` for the time period and observation
    value (matching the ``tuikr`` R package output), and dimension ids for
    every other column.
    """
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
                # Flat datasets: all dimensions live on the Obs element.
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
    """Drop invariant dimensions and append ``*_label`` columns.

    Reproduces ``clean_statistical_long_data()`` from the R package:
    columns other than ``obsTime``/``obsValue`` that hold a single unique
    non-null value are removed; coded columns with label maps gain an
    adjacent ``<dim>_label`` column when labels differ from the codes.
    """
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

    # Drop *_label columns that are identical to their source codes everywhere.
    for column in kept_columns:
        label_column = f"{column}_label"
        if not cleaned or label_column not in cleaned[0]:
            continue
        if all(
            str(row.get(label_column)) == str(row.get(column)) for row in cleaned
        ):
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
    """Download and parse SDMX observations for a dataflow."""
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


def clear_cache() -> None:
    _structure_cache.clear()
