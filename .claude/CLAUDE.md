# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`tuikr` is an R package for accessing Turkish Statistical Institute (TUIK) data from two distinct portals:
- **Statistical Data Portal** (`veriportali.tuik.gov.tr`): Themes, tables, databases, SDMX dataflows, and portal resources
- **Geographic Portal** (`cip.tuik.gov.tr`): Spatial data, map boundaries at multiple NUTS levels

The package combines web scraping (statistical data) and JSON APIs (geographic data) to expose unified R functions.

## Key Architecture

### Two Data Access Patterns

1. **Statistical Data** (web scraping-based):
   - `statistical_themes()`: Scrapes main portal page for available theme list
   - `statistical_tables(theme)`: Returns theme tables with `node_type`, `dataflow_id`, and `table_url`
   - `statistical_databases(theme)`: Legacy database URLs
   - `statistical_data(dataflow_id, key = "ALL")`: Downloads SDMX data, drops invariant dimensions, and adds `*_label` columns when labels are available
   - `statistical_resources(theme)`: Returns all portal resources with `resource_type` and `resource_url`

2. **Geographic Data** (JSON API-based):
   - `geo_data()`: Without params returns variable metadata; with params downloads specific variable data for a level
   - `geo_map(level, dataframe = FALSE)`: Downloads `sf` objects for mapping, or a plain tibble when `dataframe = TRUE`
   - API endpoints: `cip.tuik.gov.tr/Home/GetMapData` and geometry files in `cip.tuik.gov.tr/assets/geometri/`

### Geographic Levels Reference

| Level | Geography | Count | Geometry |
|-------|-----------|-------|----------|
| 2 | NUTS-2 regions | 26 | MULTIPOLYGON |
| 3 | NUTS-3 provinces | 81 | MULTIPOLYGON |
| 4 | LAU-1 districts | 973 | MULTIPOLYGON |
| 9 | Settlement points | 1,003 | POINT |

### Helper Functions & Utilities

- `make_request(url)`: HTTP POST wrapper using `crul` package
- `check_theme_id(theme)`: Validates single theme ID, provides colored terminal feedback
- Data cleaning: SDMX data is normalized to long form, invariant dimensions are removed, and label columns are appended where available
- Validation: exported geo helpers reject vector, empty, and `NA` level inputs with package errors before any network call

### Code Style & Patterns

- **R Style**: tidyverse conventions, 2-space indentation, 120-char line limit (`.lintr` config)
- **Pipes**: Uses native `|>` pipe (R 4.1+), not legacy `%>%`
- **Returns**: Functions use implicit returns (last expression is returned automatically), not explicit `return()`
- **Slicing**: Uses `dplyr::slice_head(n = 1)` instead of `dplyr::slice(1)` for explicit intent
- **Non-standard evaluation**: Uses `.data$` in data-masking contexts (for example, `mutate()` and `filter()`), but not inside tidyselect helpers like `rename()` or `select()`
- **Documentation**: Roxygen2 with markdown (RoxygenNote: 7.3.3)
- **Conditional logic**: Prefers `dplyr::case_when()`
- **Data structures**: Returns tibbles, not data.frames

### Key Dependencies

**Core imports** (always available):
- `crul`: HTTP client for web requests
- `dplyr`, `tidyr`, `purrr`: Data transformation
- `stringr`, `janitor`: String/name cleaning
- `jsonlite`: JSON parsing
- `rsdmx`: SDMX dataflow parsing
- `sf`: Spatial features for geographic data
- `rlang`, `tibble`: Tidyverse foundation

**Suggested dependencies** (optional, loaded as needed):
- `testthat`: Testing framework
- `covr`: Code coverage
- `knitr`, `rmarkdown`: Vignettes
- `pkgdown`: Website documentation
- `V8`: Suggested dependency retained for broader compatibility work, but not used by the current geographic parser

## Development Commands

### Loading & Documentation

```r
# Load package for development (without reinstalling)
devtools::load_all()

# Generate documentation from roxygen comments (creates man/ and updates NAMESPACE)
devtools::document()
```

### Testing

```r
# Run all tests
devtools::test()

# Run network-backed integration tests explicitly
Sys.setenv(RUN_NETWORK_TESTS = "true")
devtools::test()

# Run specific test file
testthat::test_file("tests/testthat/test-statistical-themes.R")

# Run tests with coverage report
covr::report()
```

**Testing patterns**: Network-dependent tests are guarded by `RUN_NETWORK_TESTS` and `skip_if_offline()`. Testthat edition 3 is configured in DESCRIPTION.

### Package Checking & Building

```r
# Full package check (runs tests, documentation, examples, warnings)
devtools::check()

# Build package tarball and run checks
system("R CMD build . && R CMD check tuikr_*.tar.gz")

# Install package locally
devtools::install()
```

### Linting

```r
# Run lintr checks (configured in .lintr for 120-char line length)
lintr::lint_package()
```

### Website Documentation

```r
# Build pkgdown website (uses eerdown theme)
pkgdown::build_site()
```

## Important Implementation Details

### Theme Validation

- `check_theme_id()` only accepts **single theme IDs**, not vectors
- Validates against current TUIK website list
- Provides colored terminal feedback using `crayon`

### Locale Handling in `statistical_tables()`

Turkish date parsing requires locale switching:
- Windows: `"Turkish_Turkey.utf8"`
- Unix/macOS: `"tr_TR"`

This is necessary because TUIK returns dates in Turkish format.

### Language Support

The `geo_data()` function supports:
- Default: English labels (`lang = "en"`)
- Turkish labels: `lang = "tr"`
English is the default language (set in recent refactoring).

### SDMX Dataflow Key Syntax

`statistical_data()` uses SDMX dimension keys:
- `key = "ALL"` works for many datasets (default)
- Some dataflows require narrower keys to constrain dimensions
- Key format: dimension constraints like `"1.2.3"` for specific values
- Returned columns vary by dataset because invariant dimensions are dropped after normalization

### Web Scraping Sensitivities

The package relies on web scraping for statistical data (HTML parsing) and is sensitive to TUIK website structure changes. Geographic data is more stable (JSON API endpoints).

## CI/CD & Deployment

GitHub Actions workflows (`.github/workflows/`):
- **R-CMD-check**: Multi-platform testing (Ubuntu devel/release/oldrel-1, macOS, Windows)
- **test-coverage**: Code coverage tracking with codecov
- **pkgdown**: Automatic website deployment to gh-pages branch
- **air-format-check**: Code formatting validation

Dependabot automatically updates GitHub Actions.

## Known Sensitivities

- **Database links**: Some TUIK database URLs may be outdated or non-functional due to TUIK website changes
- **Excel files**: Downloaded XLS files from TUIK often have messy structure (multiple header rows, mixed languages, metadata at bottom) requiring manual cleaning
- **API endpoint stability**: Geographic API is stable; statistical portal structure changes may break scraping logic

## Vignettes

Located in `vignettes/`:
- `getting-started.Rmd`: Basic workflow for statistical and geographic data
- `geographic-mapping.Rmd`: SF object joining and spatial visualization

Vignettes are built and deployed with pkgdown.

## Package Documentation

- **Website**: https://eremrah.com/tuikr/ (deployed from gh-pages branch)
- **Theme**: eerdown (custom theme, configured in `_pkgdown.yml`)
- **Citation**: CFF v1.2.0 format in `CITATION.cff`

## Modern R Development Practices

This codebase follows **r-development skill** patterns for modern tidyverse development:

### Key Patterns

**Native Pipe (`|>` not `%>%`)**: All code uses R 4.1+ native pipe
```r
data |>
  filter(year >= 2020) |>
  summarise(mean_value = mean(value))
```

**Implicit Returns**: Functions return the last expression automatically
```r
# ✓ Modern style
my_function <- function(x) {
  x |>
    dplyr::filter(condition) |>
    dplyr::mutate(new_col = x * 2)
}

# ✗ Outdated
my_function <- function(x) {
  result <- x |> filter(condition) |> mutate(new_col = x * 2)
  return(result)
}
```

**Explicit Intent with `slice_head()`**: Use `slice_head(n = 1)` instead of `slice(1)`
```r
data |>
  dplyr::filter(var_num == selected) |>
  dplyr::slice_head(n = 1)  # Clear: get the first row
```

**NSE with `.data` Pronoun**: Use `.data$` for column references in data-masking contexts only
```r
dplyr::filter(.data$var_num == .env$selected_var_num)
```

Use string or bare column references in tidyselect contexts:
```r
dplyr::rename(code = "duzeyKodu")
```

## Quick Development Workflow

1. **Make changes to R files in `R/`**
2. **Document**: `devtools::document()`
3. **Test locally**: `devtools::test()`
4. **Full check**: `devtools::check()` (catches documentation, examples, warnings)
5. **Lint**: `lintr::lint_package()` (enforces 120-char line limit and style)
6. **Push**: GitHub Actions runs full R-CMD-check on multiple platforms

## Claude Code Automation Recommendations

When working on tuikr, consider using these Claude Code features:

### Skills

- **`r-skill:r-development`**: Modern R/tidyverse patterns (native pipes, implicit returns, `.by` parameter)
  - Use before implementing features or refactoring R code
  - Validates adherence to tidyverse best practices

- **`commit-commands:commit`**: Streamlined git commits with proper attribution
  - Use to create commits with clear messages

### MCP Servers

- **GitHub MCP**: Check PR status, manage issues, read repository context
  - Install: `claude mcp add github`

### Hooks (Optional)

- **PostToolUse lint**: Auto-run `lintr::lint_file()` after editing R files
- **PreToolUse protection**: Block accidental edits to DESCRIPTION or lock files

### Subagents

- **code-reviewer**: Parallel code quality review across modified files
  - Useful for PR preparation before human review
