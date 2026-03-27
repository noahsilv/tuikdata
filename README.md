
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tuikr

<!-- badges: start -->

[![DOI](https://zenodo.org/badge/313863336.svg)](https://zenodo.org/badge/latestdoi/313863336)
[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check](https://github.com/emraher/tuikr/workflows/R-CMD-check/badge.svg)](https://github.com/emraher/tuikr)
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

# List all themes
themes <- statistical_themes()
head(themes)

# Get statistical tables and SDMX dataflows for a theme
tables <- statistical_tables(1)
head(tables, 3)

# Discover all portal resources for the same theme
resources <- statistical_resources(1)
head(resources, 3)

# Filter SDMX-backed rows
sdmx_tables <- tables[tables$node_type == "dataflow", ]
head(sdmx_tables, 3)

# Download observations for one SDMX dataflow
sdmx_data <- statistical_data(sdmx_tables$dataflow_id[1])
head(sdmx_data, 3)

# Get legacy database URLs for the same theme
databases <- statistical_databases(1)
head(databases, 3)

# Discover press releases and reports
news_items <- statistical_resources(1, type = c("press", "report"))
head(news_items, 3)

# Filter direct file downloads
file_tables <- tables[tables$node_type == "istab", ]
head(file_tables$table_url, 3)
```

`statistical_resources()` returns the full supported portal catalog for
a theme: SDMX dataflows, direct file downloads, legacy databases, press
releases, and reports.

`statistical_tables()` returns a `node_type` column. Use `"dataflow"`
rows for SDMX-backed datasets and `"istab"` rows for direct file
downloads exposed in `table_url`.

`dataflow_id` is the canonical machine identifier for SDMX-backed
datasets. Use `statistical_data()` to download observations. Some
datasets work with the default `key = "ALL"`, while others need a more
specific SDMX key.

### Geographic Data

``` r
library(dplyr)

# List available geographic variables
variables <- geo_data()
head(variables, 3)

# Download data for a specific variable
population <- geo_data(
  variable_no = "ADNKS-GK137473-O29001",
  variable_level = 3,
  variable_source = "medas",
  variable_period = "yillik",
  variable_recnum = 5
)
head(population, 3)

# Get map boundaries at different levels
nuts2_map <- geo_map(level = 2)  # 26 regions
nuts3_map <- geo_map(level = 3)  # 81 provinces
lau1_map <- geo_map(level = 4)   # 973 districts

# Preview map data
head(nuts3_map, 3)
```

## Available Map Levels

- **Level 2**: NUTS-2 regions (26 regions)
- **Level 3**: NUTS-3 / Provincial level (81 provinces)
- **Level 4**: LAU-1 / District level (973 districts)
- **Level 9**: Settlement points (returns POINT geometries)

## Vignettes

- [Getting
  Started](https://github.com/emraher/tuikr/blob/master/vignettes/getting-started.Rmd)
- [Geographic Mapping
  Examples](https://github.com/emraher/tuikr/blob/master/vignettes/geographic-mapping.Rmd)
- [Known
  Issues](https://github.com/emraher/tuikr/blob/master/vignettes/known-issues.Rmd)
