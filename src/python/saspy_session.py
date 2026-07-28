"""SASPy session management utilities.

Provides a thin wrapper around :func:`saspy.SASsession` that reads connection
settings from environment variables so callers never hard-code credentials.

Typical usage::

    from src.python.saspy_session import get_sas_session

    with get_sas_session() as sas:
        df = sas.sd2df(table="claims", libref="work")
        sas.submit("proc print data=work.claims; run;")

Environment variables
---------------------
SASPY_CFG
    Absolute path to ``sascfg_personal.py``.  Falls back to the SASPy
    package default if unset.
SASPY_CFGNAME
    Configuration profile name (key in ``SAS_config_names``).  Defaults to
    ``"default"``.
"""

from __future__ import annotations

import contextlib
import logging
import os
from collections.abc import Generator

log = logging.getLogger(__name__)

# Optional import — saspy is not installed in all CI environments.
try:
    import saspy  # type: ignore[import-untyped]

    _SASPY_AVAILABLE = True
except ImportError:  # pragma: no cover
    saspy = None  # type: ignore[assignment]
    _SASPY_AVAILABLE = False


def is_saspy_available() -> bool:
    """Return True when saspy is importable (does not check server reachability)."""
    return _SASPY_AVAILABLE


@contextlib.contextmanager
def get_sas_session(
    cfgname: str | None = None,
    *,
    results: str = "HTML",
) -> Generator[saspy.SASsession, None, None]:
    """Context manager that yields an authenticated :class:`saspy.SASsession`.

    Parameters
    ----------
    cfgname:
        Connection profile name.  Reads ``SASPY_CFGNAME`` env var if *None*.
    results:
        SASPy results format — ``"HTML"`` (default) or ``"TEXT"``.

    Yields
    ------
    saspy.SASsession
        An active SAS session.  The session is terminated when the context exits.

    Raises
    ------
    ImportError
        When ``saspy`` is not installed.
    RuntimeError
        When the SAS server is unreachable.
    """
    if not _SASPY_AVAILABLE:
        raise ImportError("saspy is not installed.  Run: pip install saspy")

    resolved_cfgname = cfgname or os.environ.get("SASPY_CFGNAME", "default")
    cfg_path = os.environ.get("SASPY_CFG")
    if cfg_path:
        log.debug("SASPy config: %s (profile: %s)", cfg_path, resolved_cfgname)

    sas: saspy.SASsession | None = None
    try:
        sas = saspy.SASsession(cfgname=resolved_cfgname, results=results)
        log.info("SAS session started (profile=%s)", resolved_cfgname)
        yield sas
    except Exception as exc:
        log.error("Failed to start SAS session: %s", exc)
        raise RuntimeError(f"SAS session could not be established: {exc}") from exc
    finally:
        if sas is not None:
            try:
                sas.endsas()
                log.info("SAS session terminated")
            except Exception as exc:  # noqa: BLE001
                log.warning("Error while ending SAS session: %s", exc)


def submit_sas_code(code: str, cfgname: str | None = None) -> str:
    """Submit a SAS code block and return the log output as a string.

    Parameters
    ----------
    code:
        SAS program text to submit.
    cfgname:
        Connection profile name (see :func:`get_sas_session`).

    Returns
    -------
    str
        SAS log output for the submitted code.
    """
    with get_sas_session(cfgname=cfgname, results="TEXT") as sas:
        result = sas.submit(code)
        return result.get("LOG", "")
