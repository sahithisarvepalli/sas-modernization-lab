"""
saspy_config.py — SASPy Connection Configuration
=================================================
This file defines all SAS connection profiles for the Healthcare Analytics
Playground. Set the SASPY_CFG environment variable to point to this file:

    export SASPY_CFG=/workspaces/sas-modernization-lab/saspy_config.py

Or reference it programmatically:
    import saspy
    sas = saspy.SASsession(cfgfile='/workspaces/sas-modernization-lab/saspy_config.py',
                           cfgname='iom_workspace')

PROFILES:
  iom_workspace  — Traditional SAS 9.4 Workspace Server (Java / IOM bridge)
  http_viya      — SAS Viya 4 (SAS Studio Compute context, REST API)
  stdio_local    — Local SAS executable via STDIN/STDOUT (fastest for dev)
  iom_grid       — SAS Grid Manager (LSF/SLURM workload scheduling)

CREDENTIALS (never committed to git):
  IOM passwords are read from ~/.authinfo  (format: machine HOST login USER password PASS)
  Viya tokens are read from ~/.sas_viya_token  or injected via environment variable
  See: https://sassoftware.github.io/saspy/install.html#authentication

SECURITY NOTE:
  Never hard-code passwords or tokens in this file.
  Use the authinfo file, environment variables, or a secrets manager.
"""

# ---------------------------------------------------------------------------
# Required: list of all profile names defined below.
# SASPy will only accept cfgname values present in this list.
# ---------------------------------------------------------------------------
SAS_config_names = [
    "iom_workspace",
    "http_viya",
    "stdio_local",
    "iom_grid",
]

# Optional: display name shown in saspy.list_configs()
SAS_config_options = {
    "lock_down": False,  # Allow users to override options at connect time
    "verbose": True,  # Print connection info to stdout
    "prompt": True,  # Prompt for credentials if not found in authinfo
}

# ---------------------------------------------------------------------------
# PROFILE 1: iom_workspace
# Traditional SAS 9.4 Workspace Server using the IOM (Integrated Object Model)
# Java bridge. Requires Java 8+ and the SAS IOM client JARs (included with SASPy).
#
# To resolve host / port: check your SAS Management Console or contact your
# SAS admin for the Workspace Server Object Spawner port (default: 8591).
# ---------------------------------------------------------------------------
iom_workspace = {
    "java": "/usr/bin/java",  # Path to Java executable
    "iomhost": "your-sas-server.example.com",
    "iomport": 8591,  # Default IOM port
    "omruser": "",  # Leave blank → reads from authinfo
    "omrpw": "",  # Leave blank → reads from authinfo
    "encoding": "utf-8",
    "options": ["-fullstimer", "-memsize 4G"],
    "timeout": 20,  # Connection timeout in seconds
}

# ---------------------------------------------------------------------------
# PROFILE 2: http_viya
# SAS Viya 4 via the Compute REST API. No Java required. Authentication is
# handled via OAuth2 tokens (stored in ~/.sas_viya_token after running
# `python -m saspy.sasconfig` or via client credentials flow).
#
# context: name of your SAS Studio Compute Context (ask your Viya admin).
# ---------------------------------------------------------------------------
http_viya = {
    "url": "https://your-viya-server.example.com",
    "context": "SAS Studio compute context",
    "authtype": "password",  # Options: password | token | client_credentials
    "user": "",  # Leave blank → reads from authinfo or prompts
    "pw": "",  # Leave blank → reads from authinfo or prompts
    "options": ["-fullstimer", "-memsize 8G"],
    "ssl_check": True,  # Always True in production; False for dev with self-signed certs
    "verify": True,  # SSL certificate verification
    "timeout": 30,
}

# ---------------------------------------------------------------------------
# PROFILE 3: stdio_local
# Local SAS executable invoked via STDIN/STDOUT. This is the simplest setup
# for developers who have SAS installed on the same machine (or container).
# No network or Java required — SAS is launched as a subprocess.
#
# Find your SAS executable:  which sas   OR   find /opt/sas -name "sas" -type f
# ---------------------------------------------------------------------------
stdio_local = {
    "saspath": "/opt/sas/SASFoundation/9.4/sas",  # Adjust to your SAS install
    "options": [
        "-nodms",  # Disable Display Manager (batch mode)
        "-stdio",  # Use STDIN/STDOUT for I/O
        "-terminal",  # Allow terminal interaction
        "-nosyntaxcheck",  # Don't abort on syntax errors (better for interactive)
        "-fullstimer",  # Performance timers
    ],
    "encoding": "utf-8",
    "timeout": 60,
}

# ---------------------------------------------------------------------------
# PROFILE 4: iom_grid
# SAS Grid via the IOM bridge with LSF/SLURM load balancing.
# Useful for running large SAS jobs across a cluster.
# ---------------------------------------------------------------------------
iom_grid = {
    "java": "/usr/bin/java",
    "iomhost": "your-grid-server.example.com",
    "iomport": 8591,
    "omruser": "",
    "omrpw": "",
    "encoding": "utf-8",
    "options": ["-fullstimer", "-memsize 16G", "-sortsize 8G"],
    "sspi": False,  # Kerberos/SSPI auth (Windows AD environments)
    "timeout": 30,
}
