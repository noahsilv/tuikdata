import pytest

from tuik_mcp import sdmx


def test_split_dataflow_id():
    assert sdmx.split_dataflow_id("TR,DF_ADNKS_T26,1.0") == (
        "TR",
        "DF_ADNKS_T26",
        "1.0",
    )


@pytest.mark.parametrize("bad", ["TR,DF", "TR,,1.0", "plain", ""])
def test_split_dataflow_id_invalid(bad):
    with pytest.raises(ValueError):
        sdmx.split_dataflow_id(bad)


def test_build_urls():
    assert sdmx.build_structure_url("TR,DF_X,1.0") == (
        "https://nsiws.tuik.gov.tr/rest/dataflow/TR/DF_X/1.0"
        "?detail=Full&references=Descendants"
    )
    url = sdmx.build_data_url("TR,DF_X,1.0", key="1.2.TR", start="2020", end="2023")
    assert url == (
        "https://nsiws.tuik.gov.tr/rest/data/TR,DF_X,1.0/1.2.TR/"
        "?detail=full&dimensionAtObservation=TIME_PERIOD"
        "&startPeriod=2020&endPeriod=2023"
    )


def test_build_data_url_empty_key():
    with pytest.raises(ValueError):
        sdmx.build_data_url("TR,DF_X,1.0", key="")


def test_parse_structure(structure_xml):
    structure = sdmx.parse_structure_xml(structure_xml, "TR,DF_ADNKS_T26,1.0")
    assert structure.name["en"] == "Population by province and sex"
    assert [d["id"] for d in structure.dimensions] == ["GOSTERGE", "IL", "CINSIYET"]
    assert structure.time_dimension == "TIME_PERIOD"
    assert structure.primary_measure == "OBS_VALUE"
    assert structure.codelists["CL_IL"]["TR100"]["en"] == "Istanbul"
    assert structure.dimensions[1]["codelist_id"] == "CL_IL"


def test_label_maps_language(structure_xml):
    structure = sdmx.parse_structure_xml(structure_xml, "TR,DF_ADNKS_T26,1.0")
    en_maps = sdmx.build_label_maps(structure, lang="en")
    tr_maps = sdmx.build_label_maps(structure, lang="tr")
    assert en_maps["CINSIYET"]["1"] == "Male"
    assert tr_maps["CINSIYET"]["1"] == "Erkek"


def test_parse_generic_data(data_generic_xml):
    records = sdmx.parse_data_xml(data_generic_xml)
    assert len(records) == 3
    assert records[0] == {
        "GOSTERGE": "POP",
        "IL": "TR100",
        "CINSIYET": "1",
        "obsTime": "2022",
        "obsValue": 7900000,
    }
    assert records[2]["obsValue"] == 2900000.5


def test_parse_structure_specific_data(data_structure_specific_xml, data_generic_xml):
    ss_records = sdmx.parse_data_xml(data_structure_specific_xml)
    generic_records = sdmx.parse_data_xml(data_generic_xml)
    assert ss_records == generic_records


def test_clean_records_drops_invariant_and_adds_labels(
    structure_xml, data_generic_xml
):
    structure = sdmx.parse_structure_xml(structure_xml, "TR,DF_ADNKS_T26,1.0")
    label_maps = sdmx.build_label_maps(structure, lang="en")
    records = sdmx.parse_data_xml(data_generic_xml)
    cleaned = sdmx.clean_records(records, label_maps=label_maps)

    # GOSTERGE is invariant (always POP) and must be dropped.
    assert "GOSTERGE" not in cleaned[0]
    assert cleaned[0]["IL"] == "TR100"
    assert cleaned[0]["IL_label"] == "Istanbul"
    assert cleaned[0]["CINSIYET_label"] == "Male"
    # Protected columns are last, matching the R package output shape.
    assert list(cleaned[0])[-2:] == ["obsTime", "obsValue"]


def test_clean_records_drops_label_columns_identical_to_codes():
    records = [
        {"DIM": "A", "obsTime": "2020", "obsValue": 1},
        {"DIM": "B", "obsTime": "2020", "obsValue": 2},
    ]
    cleaned = sdmx.clean_records(records, label_maps={"DIM": {"A": "A", "B": "B"}})
    assert "DIM_label" not in cleaned[0]


def test_clean_records_empty():
    assert sdmx.clean_records([]) == []
