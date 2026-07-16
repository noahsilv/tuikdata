import json
import sys
from pathlib import Path

import pytest

SRC = Path(__file__).resolve().parents[1] / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

FIXTURES = Path(__file__).resolve().parent / "fixtures"


@pytest.fixture()
def fixtures_dir() -> Path:
    return FIXTURES


@pytest.fixture()
def theme_tree() -> list:
    return json.loads((FIXTURES / "theme_tree.json").read_text())["data"]


@pytest.fixture()
def structure_xml() -> str:
    return (FIXTURES / "structure.xml").read_text()


@pytest.fixture()
def data_generic_xml() -> str:
    return (FIXTURES / "data_generic.xml").read_text()


@pytest.fixture()
def data_structure_specific_xml() -> str:
    return (FIXTURES / "data_structure_specific.xml").read_text()


@pytest.fixture()
def side_menu() -> dict:
    return json.loads((FIXTURES / "side_menu.json").read_text())


@pytest.fixture()
def map_data() -> dict:
    return json.loads((FIXTURES / "map_data.json").read_text())


@pytest.fixture()
def nuts2_geojson() -> dict:
    return json.loads((FIXTURES / "nuts2.json").read_text())


@pytest.fixture(autouse=True)
def clear_caches():
    from tuik_mcp import auth, geo, portal, sdmx

    portal.clear_cache()
    sdmx.clear_cache()
    geo.clear_cache()
    auth.clear_token_cache()
    yield
    portal.clear_cache()
    sdmx.clear_cache()
    geo.clear_cache()
    auth.clear_token_cache()
