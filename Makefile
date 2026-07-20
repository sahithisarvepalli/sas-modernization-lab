.PHONY: help install clean lint test validate

help:
	@echo "SAS Modernization Lab"
	@echo "  make install   - Install project and dev dependencies"
	@echo "  make lint      - Run Python and markdown lint checks"
	@echo "  make test      - Run bootstrap smoke tests"
	@echo "  make validate  - Run repo guardrails, SAS checks, and pre-commit"

install:
	python -m pip install --upgrade pip setuptools wheel
	python -m pip install -r requirements.txt
	python -m pip install -e .[dev]

clean:
	find . -type d -name '__pycache__' -prune -exec rm -rf {} +
	find . -type d -name '.pytest_cache' -prune -exec rm -rf {} +
	find . -type d -name '.ruff_cache' -prune -exec rm -rf {} +
	find . -type f -name '.coverage' -delete

lint:
	ruff check src tests scripts
	@if command -v markdownlint >/dev/null 2>&1; then \
		markdownlint README.md CONTRIBUTING.md docs/**/*.md .github/pull_request_template.md; \
	else \
		echo "markdownlint not found; install via devcontainer or npm"; \
		exit 1; \
	fi

test:
	pytest tests -v

validate:
	python scripts/check_sas_static.py
	python scripts/check_repo_guardrails.py
	pre-commit run --all-files
