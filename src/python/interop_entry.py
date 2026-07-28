"""Python interoperability entrypoint for SAS modernization lab.

This module exposes the primary status payload consumed by CI smoke tests and
provides a clear import surface for SASPy and SAS Viya utilities.

See Also
--------
src.python.saspy_session : SASPy session context manager
src.python.viya_client   : SAS Viya REST API client
"""

from __future__ import annotations

import json
from pathlib import Path

from src.python.saspy_session import is_saspy_available

MODULE_ROOTS = [
    Path("src/sas/module_a_advanced_core"),
    Path("src/sas/module_b_modernization_simulation"),
    Path("src/sas/module_c_api_reporting"),
]


def build_status_payload() -> dict[str, object]:
    """Build a status payload for SAS-to-Python integration checks.

    Returns a dictionary that describes discovered SAS module roots, the
    current working directory, and whether the SASPy bridge is available in
    the active Python environment.
    """
    return {
        "status": "ready",
        "modules": [path.name for path in MODULE_ROOTS],
        "workspace": str(Path.cwd()),
        "saspy_available": is_saspy_available(),
    }


def main() -> None:
    """Print a JSON payload that can be consumed by external automation."""
    print(json.dumps(build_status_payload(), indent=2))


if __name__ == "__main__":
    main()
