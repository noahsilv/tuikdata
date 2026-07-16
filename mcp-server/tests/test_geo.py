import pytest

from tuik_mcp import geo


@pytest.fixture(autouse=True)
def stub_json(monkeypatch, side_menu, map_data, nuts2_geojson):
    def fake_fetch(url):
        if "sideMenu" in url:
            return side_menu
        if "GetMapData" in url:
            return map_data
        if "nuts2" in url:
            return nuts2_geojson
        raise RuntimeError(f"unexpected url {url}")

    monkeypatch.setattr(geo, "_fetch_json", fake_fetch)


def test_list_variables_en():
    variables = geo.list_variables()
    assert variables[0]["var_name"] == "Total population"
    assert variables[0]["var_num"] == "SNM-GK160951-O33303"
    assert variables[0]["var_levels"] == [2, 3, 4]


def test_list_variables_tr():
    variables = geo.list_variables(lang="tr")
    assert variables[0]["var_name"] == "Toplam nüfus"


def test_fetch_variable_data():
    result = geo.fetch_variable_data("SNM-GK160951-O33303", var_level=2)
    assert result["var_name"] == "Total population"
    assert result["rows"][0] == {"code": "TR1", "date": "2022", "value": 15900000}
    assert len(result["rows"]) == 4


def test_fetch_variable_data_single_level_inferred():
    result = geo.fetch_variable_data("SNM-KONUT-01")
    assert result["var_level"] == 3


def test_fetch_variable_data_level_required():
    with pytest.raises(ValueError, match="var_level is required"):
        geo.fetch_variable_data("SNM-GK160951-O33303")


def test_fetch_variable_data_unknown_var():
    with pytest.raises(ValueError, match="var_num"):
        geo.fetch_variable_data("NOPE")


def test_fetch_variable_data_invalid_level():
    with pytest.raises(ValueError):
        geo.fetch_variable_data("SNM-GK160951-O33303", var_level=9)


def test_monthly_date_normalization():
    assert geo._normalize_dates(["202201", "202202"]) == ["2022-01", "2022-02"]
    assert geo._normalize_dates(["2022"]) == ["2022"]


def test_fetch_map_attributes():
    result = geo.fetch_map(2)
    assert result["feature_count"] == 2
    first = result["attributes"][0]
    assert first["code"] == "TR1"
    assert first["ad"] == "İstanbul"  # whitespace trimmed
    assert "name" not in first
    assert "geojson" not in result


def test_fetch_map_geometry_fixes_type():
    result = geo.fetch_map(2, include_geometry=True)
    geojson = result["geojson"]
    assert geojson["type"] == "FeatureCollection"
    assert geojson["features"][0]["geometry"]["type"] == "MultiPolygon"
    assert geojson["features"][0]["properties"]["code"] == "TR1"


def test_fetch_map_invalid_level():
    with pytest.raises(ValueError):
        geo.fetch_map(5)
