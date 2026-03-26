
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tuikr

<!-- badges: start -->

[![DOI](https://zenodo.org/badge/313863336.svg)](https://zenodo.org/badge/latestdoi/313863336)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
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

# Filter direct file downloads
file_tables <- tables[tables$node_type == "istab", ]
head(file_tables$table_url, 3)

# Get legacy database URLs for the same theme
databases <- statistical_databases(1)
head(databases, 3)
```

`statistical_tables()` returns a `node_type` column. Use `"dataflow"`
rows for SDMX-backed datasets and `"istab"` rows for direct file
downloads exposed in `table_url`.

### Geographic Data

``` r
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union

# List available geographic variables
variables <- geo_data()
head(variables, 3)
#> # A tibble: 3 × 6
#>   var_name                var_num var_levels var_period var_source var_recordnum
#>   <chr>                   <chr>   <list>     <chr>      <chr>              <int>
#> 1 Atık hizmeti verilen b… CVRBA-… <int [2]>  yillik     medas                  5
#> 2 Atıksu Arıtma Hizmeti … CVRAS-… <int [2]>  yillik     medas                  5
#> 3 Kişi Başı Günlük Atıks… CVRAS-… <int [2]>  yillik     medas                  5

# Download data for a specific variable
population <- geo_data(
  variable_no = "ADNKS-GK137473-O29001",
  variable_level = 3,
  variable_source = "medas",
  variable_period = "yillik",
  variable_recnum = 5
)
head(population, 3)
#> # A tibble: 3 × 3
#>   code  date  toplam_nufus
#>   <chr> <chr> <chr>       
#> 1 39    2024  379031      
#> 2 39    2023  377156      
#> 3 39    2022  369347

# Get map boundaries at different levels
nuts2_map <- geo_map(level = 2)  # 26 regions
nuts3_map <- geo_map(level = 3)  # 81 provinces
lau1_map <- geo_map(level = 4)   # 973 districts

# Preview map data
head(nuts3_map, 3)
#> Simple feature collection with 3 features and 5 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 27 ymin: 36.54 xmax: 39.26 ymax: 38.4
#> Geodetic CRS:  WGS 84
#> # A tibble: 3 × 6
#>   code  bolgeKodu nutsKodu name     ad                                  geometry
#>   <chr> <chr>     <chr>    <chr>    <chr>                     <MULTIPOLYGON [°]>
#> 1 9     TR32      TR321    AYDIN    AYDIN    (((28.25 37.55, 28.23 37.52, 28.22…
#> 2 1     TR62      TR621    ADANA    ADANA    (((36.18 37.71, 36.19 37.7, 36.14 …
#> 3 2     TRC1      TRC12    ADIYAMAN ADIYAMAN (((38.92 37.82, 38.95 37.8, 38.96 …
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
- [Known Issues](https://github.com/emraher/tuikr/blob/master/vignettes/known-issues.Rmd)
