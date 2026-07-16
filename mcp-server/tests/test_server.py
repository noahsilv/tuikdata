"""End-to-end tests through the MCP protocol using the in-memory client."""

import asyncio

import pytest
from fastmcp import Client

from tuik_mcp import geo, portal, sdmx
from tuik_mcp.server import mcp

EXPECTED_TOOLS = {
    "statistical_themes",
    "statistical_resources",
    "statistical_tables",
    "statistical_databases",
    "statistical_data_structure",
    "statistical_data",
    "geo_variables",
    "geo_data",
    "geo_map",
}


def run(coro):
    return asyncio.run(coro)


async def _call(name, arguments=None):
    async with Client(mcp) as client:
        return await client.call_tool(name, arguments or {})


@pytest.fixture(autouse=True)
def stub_network(
    monkeypatch,
    theme_tree,
    structure_xml,
    data_generic_xml,
    side_menu,
    map_data,
    nuts2_geojson,
):
    monkeypatch.setattr(portal, "_fetch_theme_tree_uncached", lambda lang: theme_tree)
    monkeypatch.setattr(
        sdmx,
        "_fetch_structure_uncached",
        lambda dataflow_id: sdmx.parse_structure_xml(structure_xml, dataflow_id),
    )
    monkeypatch.setattr(
        sdmx,
        "fetch_data",
        lambda dataflow_id, key="ALL", start=None, end=None, **kwargs: (
            sdmx.parse_data_xml(data_generic_xml)
        ),
    )

    def fake_fetch_json(url):
        if "sideMenu" in url:
            return side_menu
        if "GetMapData" in url:
            return map_data
        if "nuts2" in url:
            return nuts2_geojson
        raise RuntimeError(f"unexpected url {url}")

    monkeypatch.setattr(geo, "_fetch_json", fake_fetch_json)


def test_tool_listing():
    async def check():
        async with Client(mcp) as client:
            tools = await client.list_tools()
        return {tool.name for tool in tools}

    assert run(check()) == EXPECTED_TOOLS


def test_statistical_themes_tool():
    result = run(_call("statistical_themes"))
    assert result.data[0]["theme_id"] == "110"


def test_statistical_tables_tool():
    result = run(_call("statistical_tables", {"theme": "110"}))
    rows = result.data
    dataflows = [row for row in rows if row["node_type"] == "dataflow"]
    assert dataflows[0]["dataflow_id"] == "TR,DF_ADNKS_T26,1.0"
    assert {row["node_type"] for row in rows} == {"dataflow", "istab"}


def test_statistical_databases_tool():
    result = run(_call("statistical_databases", {"theme": "110"}))
    assert result.data[0]["db_url"].startswith("https://biruni.tuik.gov.tr")


def test_statistical_resources_filter():
    result = run(_call("statistical_resources", {"theme": "110", "type": ["press"]}))
    assert len(result.data) == 1
    assert result.data[0]["resource_type"] == "press"


def test_statistical_data_structure_tool():
    result = run(
        _call("statistical_data_structure", {"dataflow_id": "TR,DF_ADNKS_T26,1.0"})
    )
    data = result.data
    assert data["name"] == "Population by province and sex"
    assert data["key_template"] == "GOSTERGE.IL.CINSIYET"
    il_dimension = data["dimensions"][1]
    assert il_dimension["key_position"] == 2
    assert {code["code"] for code in il_dimension["codes"]} == {"TR100", "TR510"}


def test_statistical_data_tool():
    result = run(_call("statistical_data", {"dataflow_id": "TR,DF_ADNKS_T26,1.0"}))
    data = result.data
    assert data["total_rows"] == 3
    assert data["truncated"] is False
    first = data["rows"][0]
    assert first["IL_label"] == "Istanbul"
    assert first["obsValue"] == 7900000
    assert "GOSTERGE" not in first


def test_statistical_data_pagination():
    result = run(
        _call(
            "statistical_data",
            {"dataflow_id": "TR,DF_ADNKS_T26,1.0", "max_rows": 2, "offset": 2},
        )
    )
    data = result.data
    assert data["returned_rows"] == 1
    assert data["offset"] == 2
    assert data["truncated"] is False


def test_statistical_data_invalid_dataflow_id():
    with pytest.raises(Exception, match="comma-separated"):
        run(_call("statistical_data", {"dataflow_id": "bogus"}))


def test_invalid_theme_error_lists_choices():
    with pytest.raises(Exception, match="Population and Demography"):
        run(_call("statistical_tables", {"theme": "999"}))


def test_geo_variables_tool():
    result = run(_call("geo_variables"))
    assert result.data[0]["var_num"] == "SNM-GK160951-O33303"


def test_geo_data_tool():
    result = run(
        _call("geo_data", {"var_num": "SNM-GK160951-O33303", "var_level": 2})
    )
    assert result.data["rows"][0]["code"] == "TR1"


def test_geo_map_tool():
    result = run(_call("geo_map", {"level": 2}))
    assert result.data["attributes"][0]["code"] == "TR1"

    with_geometry = run(_call("geo_map", {"level": 2, "include_geometry": True}))
    assert with_geometry.data["geojson"]["type"] == "FeatureCollection"
