FROM mcr.microsoft.com/devcontainers/python:3.11

RUN apt-get update \
    && apt-get install -y shellcheck npm \
    && npm install -g markdownlint-cli \
    && rm -rf /var/lib/apt/lists/*
