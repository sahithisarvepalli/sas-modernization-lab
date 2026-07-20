"""SAS Viya REST API client scaffold.

Provides a lightweight client for the SAS Viya REST API that uses OAuth 2.0
client-credentials flow.  For heavier CAS workloads (in-memory analytics)
use ``python-swat`` (``import swat``) directly.

References
----------
- SAS Viya REST API reference: https://developer.sas.com/apis/rest/
- python-swat (SAS Viya CAS client): https://github.com/sassoftware/python-swat
- SAS Viya authentication: https://go.documentation.sas.com/doc/en/sasadmincdc/default/calauthmdl/n1iyx9c6e1uf5vn1bgz8a6b1rw1u.htm

Environment variables
---------------------
VIYA_HOST
    Base URL of the SAS Viya deployment (e.g. ``https://viya.example.com``).
VIYA_CLIENT_ID
    OAuth 2.0 client ID registered in SAS Viya.
VIYA_CLIENT_SECRET
    OAuth 2.0 client secret.
VIYA_TOKEN
    Pre-obtained bearer token.  When set, skips the client-credentials flow.
"""

from __future__ import annotations

import logging
import os
from typing import Any

log = logging.getLogger(__name__)

try:
    import requests

    _REQUESTS_AVAILABLE = True
except ImportError:  # pragma: no cover
    requests = None  # type: ignore[assignment]
    _REQUESTS_AVAILABLE = False


class ViyaClient:
    """Minimal SAS Viya REST client using client-credentials OAuth flow.

    Parameters
    ----------
    host:
        Base URL (no trailing slash).  Falls back to ``VIYA_HOST`` env var.
    client_id:
        OAuth client ID.  Falls back to ``VIYA_CLIENT_ID`` env var.
    client_secret:
        OAuth client secret.  Falls back to ``VIYA_CLIENT_SECRET`` env var.
    token:
        Pre-obtained bearer token.  Falls back to ``VIYA_TOKEN`` env var.
        When supplied, the OAuth token exchange is skipped.
    verify_ssl:
        Verify TLS certificates.  Disable only in local dev with self-signed certs.
    """

    def __init__(
        self,
        host: str | None = None,
        client_id: str | None = None,
        client_secret: str | None = None,
        token: str | None = None,
        *,
        verify_ssl: bool = True,
    ) -> None:
        if not _REQUESTS_AVAILABLE:
            raise ImportError("requests is not installed.  Run: pip install requests")

        self.host = (host or os.environ.get("VIYA_HOST", "")).rstrip("/")
        self._client_id = client_id or os.environ.get("VIYA_CLIENT_ID", "")
        self._client_secret = client_secret or os.environ.get("VIYA_CLIENT_SECRET", "")
        self._token: str | None = token or os.environ.get("VIYA_TOKEN")
        self.verify_ssl = verify_ssl
        self._session = requests.Session()
        self._session.verify = verify_ssl

    # ── Authentication ────────────────────────────────────────────────────────

    def authenticate(self) -> str:
        """Obtain a bearer token via client-credentials flow.

        Returns the token string and caches it for subsequent requests.
        """
        if self._token:
            return self._token

        url = f"{self.host}/SASLogon/oauth/token"
        response = self._session.post(
            url,
            data={"grant_type": "client_credentials"},
            auth=(self._client_id, self._client_secret),
            headers={"Accept": "application/json"},
        )
        response.raise_for_status()
        self._token = response.json()["access_token"]
        log.info("SAS Viya authentication succeeded")
        return self._token

    # ── Generic request helpers ───────────────────────────────────────────────

    def _auth_headers(self) -> dict[str, str]:
        if not self._token:
            self.authenticate()
        bearer = "Bearer " + (self._token or "")
        return {
            "Authorization": bearer,
            "Accept": "application/json",
        }

    def get(self, path: str, **kwargs: Any) -> dict[str, Any]:
        """HTTP GET against a Viya REST endpoint."""
        response = self._session.get(
            f"{self.host}{path}",
            headers=self._auth_headers(),
            **kwargs,
        )
        response.raise_for_status()
        return response.json()

    def post(self, path: str, payload: dict[str, Any], **kwargs: Any) -> dict[str, Any]:
        """HTTP POST against a Viya REST endpoint."""
        response = self._session.post(
            f"{self.host}{path}",
            json=payload,
            headers={**self._auth_headers(), "Content-Type": "application/json"},
            **kwargs,
        )
        response.raise_for_status()
        return response.json()

    # ── SAS Viya Compute Service ──────────────────────────────────────────────

    def list_compute_contexts(self) -> list[dict[str, Any]]:
        """Return all available SAS Viya Compute Service contexts."""
        result = self.get("/compute/contexts")
        return result.get("items", [])

    def create_compute_session(self, context_name: str) -> dict[str, Any]:
        """Create a new SAS Compute session for the given context.

        Parameters
        ----------
        context_name:
            Display name of the compute context (e.g. ``"SAS Studio compute context"``).

        Returns
        -------
        dict
            Session resource representation including ``id`` and ``links``.
        """
        contexts = self.list_compute_contexts()
        ctx = next((c for c in contexts if c.get("name") == context_name), None)
        if ctx is None:
            available = [c.get("name") for c in contexts]
            raise ValueError(
                f"Compute context {context_name!r} not found.  Available: {available}"
            )
        context_id = ctx["id"]
        return self.post(f"/compute/contexts/{context_id}/sessions", payload={})

    def submit_compute_job(
        self, session_id: str, sas_code: str
    ) -> dict[str, Any]:
        """Submit SAS code to an active Compute session.

        Parameters
        ----------
        session_id:
            Session ID returned by :meth:`create_compute_session`.
        sas_code:
            SAS program text.

        Returns
        -------
        dict
            Job resource representation including ``id`` and ``state``.
        """
        return self.post(
            f"/compute/sessions/{session_id}/jobs",
            payload={"code": sas_code},
        )
