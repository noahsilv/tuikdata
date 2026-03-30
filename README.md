
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tuikr

<!-- badges: start -->

[![DOI](https://zenodo.org/badge/313863336.svg)](https://zenodo.org/badge/latestdoi/313863336)
[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check](https://github.com/emraher/tuikr/workflows/R-CMD-check/badge.svg)](https://github.com/emraher/tuikr)
[![pkgdown](https://github.com/emraher/tuikr/actions/workflows/pkgdown.yaml/badge.svg)](https://eremrah.com/tuikr/)
<!-- badges: end -->

R package for accessing Turkish Statistical Institute (TUIK) data from
two portals:

- **Statistical data**: Themes, file downloads, SDMX dataflows, and
  legacy databases from
  [veriportali.tuik.gov.tr](https://veriportali.tuik.gov.tr/)
- **Geographic data**: Maps and spatial statistics from
  [cip.tuik.gov.tr](https://cip.tuik.gov.tr/)

## Installation

``` r
# Install from GitHub
devtools::install_github("emraher/tuikr")
```

## Quick Start

### Statistical Data

``` r
library(tuikr)

# 1. List themes
theme_catalog <- statistical_themes()

# 2. Tables for Population & Demography (theme 11)
population_tables <- statistical_tables("11")

# 3. SDMX dataflows only
population_dataflows <- dplyr::filter(
  population_tables,
  node_type == "dataflow"
)

# 4. File downloads expose a direct table_url
population_files <- dplyr::filter(
  population_tables,
  node_type == "istab"
)
population_files$table_url[1]

# 5. Download one dataset
population_observations <- statistical_data(
  population_dataflows$dataflow_id[1]
)

# 6. Legacy database URLs
population_databases <- statistical_databases("11")

# 7. All portal resources
population_resources <- statistical_resources("11")

# 8. Press releases and reports keep their portal URLs
population_publications <- dplyr::filter(
  population_resources,
  resource_type %in% c("press", "report")
)
population_publications |>
  dplyr::select(resource_type, resource_name, resource_url) |>
  dplyr::slice(3)
```

`statistical_data()` adds adjacent `*_label` columns when TUIK exposes
human-readable code-list metadata. The default `key = "ALL"` works for
many datasets, but some SDMX dataflows need a narrower key to constrain
the remaining dimensions.

### Geographic Data

``` r
library(tuikr)

# List available geographic variables
geo_variable_catalog <- geo_data()
head(geo_variable_catalog, 3)

# List geographic variables in Turkish
geo_variable_catalog_tr <- geo_data(lang = "tr")
head(geo_variable_catalog_tr, 3)

# Download data for a specific variable
population_values <- geo_data(
  var_num = "ADNKS-GK137473-O29001",
  var_level = 3
)
head(population_values, 3)

# Get map boundaries at different levels
nuts2_map <- geo_map(level = 2)  # 26 regions
nuts3_map <- geo_map(level = 3)  # 81 provinces
lau1_map <- geo_map(level = 4)   # 973 districts
settlements <- geo_map(level = 9)  # settlement points

# Preview map data
head(nuts3_map, 3)
```

`geo_map()` returns `sf` objects in WGS 84 (EPSG:4326), ready for
`dplyr::left_join()` on the `code` column when you want to combine
boundaries with values returned by `geo_data()`.

## Available Map Levels

| Level | Geography         | Count | Geometry     |
|------:|:------------------|------:|:-------------|
|     2 | NUTS-2 regions    |    26 | MULTIPOLYGON |
|     3 | NUTS-3 provinces  |    81 | MULTIPOLYGON |
|     4 | LAU-1 districts   |   973 | MULTIPOLYGON |
|     9 | Settlement points | 1,003 | POINT        |

## Vignettes

- [Getting
  Started](https://github.com/emraher/tuikr/blob/master/vignettes/getting-started.Rmd)
- [Geographic
  Mapping](https://github.com/emraher/tuikr/blob/master/vignettes/geographic-mapping.Rmd)

## License

MIT © Emrah Er
