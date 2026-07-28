from src.python.interop_entry import build_status_payload


def test_build_status_payload_smoke() -> None:
    payload = build_status_payload()
    assert payload["status"] == "ready"
    assert "module_a_advanced_core" in payload["modules"]
