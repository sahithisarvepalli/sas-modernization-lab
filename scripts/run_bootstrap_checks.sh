#!/bin/bash
set -euo pipefail

make lint
make test
make validate
