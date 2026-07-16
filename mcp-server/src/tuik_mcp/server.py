"""FastMCP server exposing Turkish Statistical Institute (TUIK) data.

Tools mirror the public API of the ``tuikr`` R package:

Statistical Data Portal (veriportali.tuik.gov.tr)
    - ``statistical_themes``
    - ``statistical_resources``
    - ``statistical_tables``
    - ``statistical_databases``

SDMX web service (nsiws.tuik.gov.tr)
    - ``statistical_data_structure``
    - ``statistical_data``

Geographic Portal (cip.tuik.gov.tr)
    - ``geo_variables``
    - ``geo_data``
    - ``geo_map``

Run with ``tuik-mcp`` (stdio) or ``fastmcp run tuik_mcp/server.py:mcp``.
"""

from __future__ import annotations

from typing import Annotated, Any, Literal

from fastmcp import FastMCP
from fastmcp.exceptions import ToolError
from pydantic import Field

from . import geo, portal, sdmx

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
    """Run a client call, converting validation/HTTP failures to ToolError."""
    try:
        return fn(*args, **kwargs)
    except ToolError:
        raise
    except (ValueError, RuntimeError) as error:
        raise ToolError(str(error)) from error
    except Exception as error:  # noqa: BLE001 — surface network errors readably
        raise ToolError(f"TUIK request failed: {error}") from error


# ---------------------------------------------------------------------------
# Statistical Data Portal
# ---------------------------------------------------------------------------


@mcp.tool
def statistical_themes(lang: LangParam = "en") -> list[dict[str, Any]]:
    """List all top-level statistical themes from the TUIK data portal.

    Theme IDs are used with statistical_tables, statistical_databases, and
    statistical_resources to discover datasets.
    """
    return _tool_guard(portal.list_themes, lang=lang)


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
    return _tool_guard(portal.theme_resources, theme, types=type, lang=lang)


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
    rows = _tool_guard(
        portal.theme_resources, theme, types=["dataflow", "istab"], lang=lang
    )
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
    rows = _tool_guard(portal.theme_resources, theme, types=["database"], lang=lang)
    return [
        {
            "theme_name": row["theme_name"],
            "theme_id": row["theme_id"],
            "db_name": row["resource_name"],
            "db_url": row["resource_url"],
        }
        for row in rows
    ]


# ---------------------------------------------------------------------------
# SDMX
# ---------------------------------------------------------------------------


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
    structure = _tool_guard(sdmx.fetch_structure, dataflow_id)
    label_maps = sdmx.build_label_maps(structure, lang=lang)

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
        "name": sdmx.pick_label(structure.name, lang),
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
    records = _tool_guard(sdmx.fetch_data, dataflow_id, key=key, start=start, end=end)
    structure = _tool_guard(sdmx.fetch_structure, dataflow_id)
    label_maps = sdmx.build_label_maps(structure, lang=lang)
    cleaned = sdmx.clean_records(records, label_maps=label_maps)

    total_rows = len(cleaned)
    page = cleaned[offset : offset + max_rows]
    columns = list(page[0].keys()) if page else []

    return {
        "dataflow_id": dataflow_id,
        "name": sdmx.pick_label(structure.name, lang),
        "total_rows": total_rows,
        "returned_rows": len(page),
        "offset": offset,
        "truncated": offset + len(page) < total_rows,
        "columns": columns,
        "rows": page,
    }


# ---------------------------------------------------------------------------
# Geographic Portal
# ---------------------------------------------------------------------------


@mcp.tool
def geo_variables(lang: LangParam = "en") -> list[dict[str, Any]]:
    """List all geographic indicator series from the TUIK geographic portal.

    Each record has var_name, var_num (pass to geo_data), var_levels
    (available NUTS levels: 2=NUTS-2 regions, 3=provinces, 4=districts), and
    var_period ('yillik' yearly or 'aylik' monthly).
    """
    return _tool_guard(geo.list_variables, lang=lang)


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
    return _tool_guard(geo.fetch_variable_data, var_num, var_level=var_level, lang=lang)


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
    return _tool_guard(geo.fetch_map, level, include_geometry=include_geometry)


def main() -> None:
    """Console entry point: run the server over stdio."""
    mcp.run()


if __name__ == "__main__":
    main()
