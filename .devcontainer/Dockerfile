FROM mcr.microsoft.com/devcontainers/python:3.11

# Install system packages:
#   default-jdk-headless — Java runtime required by saspy's IOM (Workspace Server) bridge
#   shellcheck           — shell script linting
#   npm + markdownlint   — Markdown linting
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
           shellcheck \
           npm \
           default-jdk-headless \
    && npm install -g markdownlint-cli \
    && rm -rf /var/lib/apt/lists/*

# Expose JAVA_HOME so saspy can locate the JVM for IOM connections
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH="$JAVA_HOME/bin:$PATH"

# Python packages:
#   saspy         — Python-to-SAS bridge (IOM, HTTP Viya, and stdio modes)
#   swat          — SAS Viya CAS (Cloud Analytic Services) Python client
#   pandas/numpy  — Data science stack for DataFrame interchange with saspy
#   jupyterlab    — Full IDE for the saspy_execution.ipynb notebook
#   matplotlib    — Charting for notebook visualisations
#   requests      — HTTP client for SAS Viya REST API workflows
RUN pip install --no-cache-dir \
    "saspy>=5.0.0" \
    "swat>=1.14.0" \
    "pandas>=2.0.0" \
    "numpy>=1.26.0" \
    "requests>=2.31.0" \
    "jupyterlab>=4.0.0" \
    "jupyter>=1.0.0" \
    "ipykernel>=6.0.0" \
    "matplotlib>=3.7.0"
