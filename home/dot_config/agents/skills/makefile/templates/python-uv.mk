# ---- python: needs uv (mise); ruff + pyrefly + pytest as dev dependencies ----
.PHONY: python/init python/tidy python/lint python/test python/audit python/build python/updatedep
python/init:
	uv sync --dev
python/tidy:
	uv run ruff format .
	uv run ruff check --fix .
python/lint:
	uv run ruff format --check .
	uv run ruff check .
	uv run pyrefly check
python/test:
	uv run pytest
python/audit:
	uv lock --check
	uvx pip-audit
python/build:
	uv build
python/updatedep:
	uv lock --upgrade
	uv sync --dev
