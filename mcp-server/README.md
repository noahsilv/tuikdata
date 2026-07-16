# tuik-mcp — FastMCP server for TUIK data

A [FastMCP](https://gofastmcp.com) server that gives MCP clients (Claude
Desktop, Claude Code, or any Model Context Protocol client) access to all
Turkish Statistical Institute (TUIK) data.

It is a Python port of the [`tuikr`](https://github.com/emraher/tuik) R
package architecture and covers the same three data surfaces:

| Surface | Host | What it provides |
|---|---|---|
| Statistical Data Portal | `veriportali.tuik.gov.tr` | Themes, tables, databases, portal resources |
| SDMX web service | `nsiws.tuik.gov.tr` | Dataflow structures (dimensions, codelists) and observations |
| Geographic Portal | `cip.tuik.gov.tr` | Indicator series and map boundaries (NUTS-2/3, LAU-1, settlements) |

## Tools

**Statistical portal**

- `statistical_themes(lang)` — top-level themes and their IDs.
- `statistical_resources(theme, type?, lang)` — full resource catalog for a
  theme (`dataflow`, `istab`, `database`, `press`, `report`).
- `statistical_tables(theme, lang)` — SDMX dataflows and direct file
  downloads; `dataflow` rows carry a `dataflow_id`.
- `statistical_databases(theme, lang)` — legacy interactive database URLs.

**SDMX**

- `statistical_data_structure(dataflow_id, lang, max_codes_per_dimension)` —
  dimension order, codelists, and localized labels. Use it to build an SDMX
  key (dot-separated codes in dimension order; empty segment = all values).
- `statistical_data(dataflow_id, key, start, end, lang, max_rows, offset)` —
  observations as long-form records. Matches the R package output:
  invariant dimensions are dropped, `obsTime`/`obsValue` hold period and
  value, and coded dimensions gain `*_label` columns. Responses are
  paginated (`max_rows`/`offset`) so large dataflows don't blow up the
  context window.

**Geographic portal**

- `geo_variables(lang)` — all indicator series (`var_num`, available NUTS
  levels, yearly/monthly period).
- `geo_data(var_num, var_level?, lang)` — `{code, date, value}` records for
  one series at a NUTS level.
- `geo_map(level, include_geometry)` — boundary attributes (default) or full
  GeoJSON (WGS 84) at level 2 (NUTS-2), 3 (provinces), 4 (districts), or 9
  (settlement points). TUIK's malformed array-wrapped GeoJSON `type` fields
  are repaired automatically.

## Typical workflow

```text
statistical_themes()                      → pick a theme, e.g. "11"
statistical_tables("11")                  → find a dataflow_id, e.g. "TR,DF_ADNKS_T26,1.0"
statistical_data_structure("TR,DF_ADNKS_T26,1.0")
                                          → inspect dimensions and codes
statistical_data("TR,DF_ADNKS_T26,1.0", key="..TR100", start="2020")
                                          → download observations
```

For maps: `geo_variables()` → `geo_data(var_num, level)` →
`geo_map(level)` and join on `code`.

## Authentication (SDMX tools)

TUIK requires a personal API key for its SDMX web service
(`nsiws.tuik.gov.tr`), which backs `statistical_data_structure` and
`statistical_data`. The portal and geographic tools work without a key.

1. Register at [veriportali.tuik.gov.tr](https://veriportali.tuik.gov.tr/)
   and verify your phone number.
2. Generate an API key under **User Information**.
3. Set it in the `TUIK_API_KEY` environment variable where the server runs
   (shell profile, MCP client `env` config, or the hosting platform's
   secrets settings).

The server exchanges the key for short-lived (~300 s) Bearer tokens at the
TUIK login service and refreshes them automatically. Without the variable,
SDMX tools fail with setup guidance.

```json
{
  "mcpServers": {
    "tuik": {
      "command": "tuik-mcp",
      "env": { "TUIK_API_KEY": "<your key>" }
    }
  }
}
```

## Installation

```bash
cd mcp-server
pip install .            # or: pip install -e ".[dev]" for development
```

## Running

```bash
# stdio (default — what MCP clients spawn)
tuik-mcp

# or with the FastMCP CLI, using module mode (requires `pip install .` first)
fastmcp run -m tuik_mcp.server

# HTTP transport
fastmcp run -m tuik_mcp.server --transport http --port 8000
```

> Running `fastmcp run src/tuik_mcp/server.py:mcp` (pointing at the file
> path directly) fails with `attempted relative import with no known parent
> package` — the file uses package-relative imports (`from . import geo, ...`)
> that only resolve when `tuik_mcp` is loaded as an installed package.
> Use `-m tuik_mcp.server` or the `tuik-mcp` entry point instead.

### Hosted deployment (Prefect Horizon / FastMCP Cloud)

The repository root contains a `server.py` shim and `requirements.txt` for
hosting platforms that expect a root-level entrypoint. Point the platform's
entrypoint setting at `server.py` (or `server.py:mcp`) — no package install
step needed; the shim adds `mcp-server/src` to the path itself.

### Claude Desktop / Claude Code configuration

```json
{
  "mcpServers": {
    "tuik": {
      "command": "tuik-mcp"
    }
  }
}
```

Or with Claude Code: `claude mcp add tuik -- tuik-mcp`.

## Notes

- All names/labels support `lang="en"` (default) and `lang="tr"`.
- Portal and SDMX structure responses are cached in-memory (15–30 min TTL)
  to keep repeated discovery calls fast.
- The statistical portal is accessed the same way the R package does: a
  browser-like landing-page request establishes session cookies before the
  JSON API call.
- SDMX data is parsed from SDMX-ML 2.1 in both *generic* and
  *structure-specific* flavors, so the server works with whichever format
  the TUIK NSI web service returns.

## Development

```bash
pip install -e ".[dev]"
pytest
```

Tests run fully offline against fixture payloads that mirror the real TUIK
API shapes (theme tree JSON, SDMX-ML structure/data, sideMenu.json,
GetMapData, and geometry GeoJSON).
