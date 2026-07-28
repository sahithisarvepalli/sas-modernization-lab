FROM mcr.microsoft.com/devcontainers/python:3.11

RUN apt-get update \
    && apt-get install -y shellcheck npm \
    && npm install -g markdownlint-cli \
    && rm -rf /var/lib/apt/lists/*

# SAS-specific Python packages: SASPy (IOM/HTTP bridge), python-swat (SAS Viya CAS),
# pandas + numpy (standard data science stack used alongside SAS)
RUN pip install --no-cache-dir \
    saspy>=5.0.0 \
    swat>=1.14.0 \
    pandas>=2.0.0 \
    numpy>=1.26.0 \
    requests>=2.31.0 \
    jupyter>=1.0.0 \
    ipykernel>=6.0.0
