"""Python interoperability entrypoint for SAS modernization lab."""

from __future__ import annotations

import json
from pathlib import Path


MODULE_ROOTS = [
    Path("src/sas/module_a_advanced_core"),
    Path("src/sas/module_b_modernization_simulation"),
    Path("src/sas/module_c_api_reporting"),
]


def build_status_payload() -> dict[str, object]:
    """Build a small status payload for SAS-to-Python integration checks."""
    return {
        "status": "ready",
        "modules": [path.name for path in MODULE_ROOTS],
        "workspace": str(Path.cwd()),
    }


def main() -> None:
    """Print a JSON payload that can be consumed by external automation."""
    print(json.dumps(build_status_payload(), indent=2))


if __name__ == "__main__":
    main()
