# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Formally verified options portfolio backtesting and hedging engine. Lean 4 implements the accounting kernel (NAV calculation, trades, proofs). Python handles data engineering, orchestration, and visualization. They communicate via Cython FFI. Currently at v0.2 milestone (NAV calculation + FFI setup).

## Build & Test Commands

### Full project (from repo root)
- `make setup` — install Lean (elan) + Python (uv) dependencies
- `make build` — build Lean proofs + Python package
- `make test` — run all Lean + Python tests
- `make lint` — ruff lint + mypy typecheck on Python
- `make clean` — remove all build artifacts

### Lean only (from `lean/` or via root)
- `lake build` — build Lean library and proofs
- `lake build OptionHedge.Tests.UnitTests` — run Lean tests
- `lake build --watch` — rebuild on file changes

### Python only (from `python/`)
- `uv run pytest -v --cov=hedge_engine --cov-report=term-missing` — run tests with coverage
- `uv run ruff check src/ tests/` — lint
- `uv run mypy src/` — typecheck (strict mode)
- `uv run ruff format src/ tests/` — format code
- Run a single test: `uv run pytest tests/test_ffi.py -v` or `uv run pytest -k test_name`

## Architecture

### Dual-language monorepo
```
lean/           — Lean 4 accounting kernel (Lake build system, Mathlib dependency)
python/         — Python package managed by uv (src/hedge_engine/)
integration/    — Cross-language integration tests
book/           — JupyterBook documentation
data/           — Encrypted market data (git-crypt)
```

### Core design: no code duplication
- **Lean** implements all accounting logic as pure functions (`Portfolio → Trade → Portfolio`). The kernel is data-source agnostic — it never touches I/O or makes assumptions about where data came from.
- **Python** handles data loading (WRDS, FRED), certificate emission, FFI calls, and visualization.
- **Cython FFI** bridges the two: Lean compiles to C via Lake (`@[export]`), Cython wraps the C functions, Python calls them. Currently using Python stubs until FFI build is complete.
- **JSON certificates** carry data from Python to Lean's verifier with string-encoded decimals for precision.

### Lean types and functions (lean/OptionHedge/)
- `Basic.lean` — core types: `Asset`, `Position`, `Portfolio`
- `Accounting.lean` — `Position.value`, `Portfolio.sumPositionValues`, `Portfolio.calcNAV` (all `@[export]`-ed)
- `Invariants.lean` — theorem statements (NAV identity, self-financing, conservation)

### Python package (python/src/hedge_engine/)
- `ffi/lean_ffi.pyx` — Cython FFI declarations against Lean C headers
- `ffi/__init__.py` — Python stub implementations (used until Cython extension is built)

## Key Conventions

- **Numeric precision**: All monetary values use **basis points** (×10,000) as `Int`. Example: $50.25 = 502,500. Never pass floats across the FFI boundary.
- **Lean toolchain**: v4.27.0-rc1 (pinned in `lean/lean-toolchain`, managed by elan)
- **Python**: 3.12+, managed by uv. Strict mypy, ruff for linting/formatting.
- **Line length**: 100 characters (ruff config in `pyproject.toml`)
- **Ruff rules**: E, W, F, I, B, C4, UP with double-quote style
- **Pre-commit hooks**: trailing whitespace, ruff, mypy, markdownlint, lean build, pytest
- **Milestone branches**: `feat/v0.X-name` pattern, PRs to `main`

## Decision Records

Major design decisions are documented in `DECISIONS.md` with full rationale. Key ADRs:
- **ADR-000**: Lean for accounting, Python for ETL, data-source agnostic kernel
- **ADR-001**: Scaled integer arithmetic (basis points) instead of floats or rationals
- **ADR-002**: JSON certificates with string-encoded decimals
- **ADR-004**: Monorepo structure with root Makefile orchestration
