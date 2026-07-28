#!/bin/bash
set -euo pipefail

for _gcfg in "${HOME:-/root}/.gitconfig" /home/vscode/.gitconfig; do
    if [ -f "$_gcfg" ]; then
        rm -rf "$_gcfg"
        touch "$_gcfg"
    fi
done
unset _gcfg
