"""Repo-root entrypoint for hosted deployments (Prefect Horizon, fastmcp run).

Hosting platforms look for ``server.py`` at the repository root. The actual
FastMCP server lives in the installable package under ``mcp-server/src``;
this shim puts that directory on ``sys.path`` and re-exports the ``mcp``
object so ``server.py`` (or ``server.py:mcp``) works as an entrypoint
without installing the package first.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "mcp-server" / "src"))

from tuik_mcp.server import mcp  # noqa: E402

if __name__ == "__main__":
    mcp.run()
