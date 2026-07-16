import pytest

from tuik_mcp import portal


@pytest.fixture(autouse=True)
def stub_theme_tree(monkeypatch, theme_tree):
    monkeypatch.setattr(portal, "_fetch_theme_tree_uncached", lambda lang: theme_tree)


def test_list_themes():
    themes = portal.list_themes()
    assert themes == [
        {"theme_name": "Population and Demography", "theme_id": "110"},
        {"theme_name": "Justice and Elections", "theme_id": "120"},
    ]


def test_theme_resources_all_types():
    rows = portal.theme_resources(110)
    types = {row["resource_type"] for row in rows}
    assert types == {"dataflow", "istab", "press", "database", "report"}
    assert len(rows) == 5


def test_theme_resources_dataflow_id_extraction():
    rows = portal.theme_resources("110", types=["dataflow"])
    assert len(rows) == 1
    assert rows[0]["dataflow_id"] == "TR,DF_ADNKS_T26,1.0"
    assert rows[0]["theme_id"] == "110"


def test_theme_resources_relative_urls_normalized():
    rows = portal.theme_resources(110, types=["istab"])
    assert rows[0]["resource_url"] == (
        "https://veriportali.tuik.gov.tr/media/istab/pop_summary.xls"
    )
    assert rows[0]["dataflow_id"] is None


def test_theme_resources_empty_theme():
    assert portal.theme_resources(120) == []


def test_invalid_theme_lists_choices():
    with pytest.raises(ValueError) as excinfo:
        portal.theme_resources(999)
    assert "110 = Population and Demography" in str(excinfo.value)


def test_invalid_resource_type():
    with pytest.raises(ValueError):
        portal.theme_resources(110, types=["bogus"])


def test_invalid_lang():
    with pytest.raises(ValueError):
        portal.list_themes(lang="de")
