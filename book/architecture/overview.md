# Architecture Overview

**Last Updated**: 2026-02-16 (v0.2-nav)

## Core Principle: No Code Duplication + Data Source Agnostic

**Lean** and **Python** have distinct, non-overlapping responsibilities:

1. **Lean**: Accounting kernel implementation + formal verification (data source agnostic)
2. **Python**: Data pipeline (backtests OR simulations) + FFI bindings + certificate emission

**Key Design Goal**: The accounting kernel must work for:
- ✅ Historical backtests (WRDS data)
- ✅ MCMC simulations (stochastic processes) - *future*
- ✅ Synthetic data (testing)
- ✅ Live trading (market feeds) - *future*

---

## Component 1: Accounting Kernel (100% Lean) - Pure Functions

### Responsibility

Implement ALL portfolio accounting logic as **pure functions**:
- Portfolio state representation (`Portfolio`, `Position`, `Trade`)
- NAV calculation (`calcNAV : Portfolio → Int`)
- Trade application (`applyTrade : Portfolio → Trade → Portfolio`)
- Cash accrual (`accrueInterest : Portfolio → Rate → Portfolio`)
- Position management

**Critical**: Functions accept data as inputs, never load data themselves.

### Implementation

```lean
-- OptionHedge/Accounting.lean

@[export lean_calc_nav]
def calcNAV (p : Portfolio) : Int :=
  p.cash + sumPositionValues p.positions

@[export lean_apply_trade]
def applyTrade (p : Portfolio) (t : Trade) : Portfolio :=
  -- Implementation with proofs
  ...
```

### Formal Verification

Prove invariants about accounting functions:
- NAV identity
- Self-financing property
- Conservation of quantities
- Cash update correctness
- Time monotonicity
- Domain constraints
- Deterministic replay

```lean
-- OptionHedge/Invariants.lean

theorem navIdentity (p : Portfolio) :
  calcNAV p = p.cash + sumPositionValues p.positions := by
  -- Proof
  ...
```

### Compilation & Export

```bash
# Lake compiles Lean → C
lake build OptionHedge

# Generates:
# - .lake/build/lib/libOptionHedge.a (static library)
# - .lake/build/lib/libOptionHedge.so (shared library)
# - C headers with exported functions
```

### Python Interface

Python calls Lean functions via Cython FFI (NO Python implementation of accounting):

```python
# python/src/hedge_engine/bindings/accounting.pyx (Cython)

cdef extern from "lean/lean.h":
    ctypedef struct lean_object

cdef extern from "OptionHedge.h":
    lean_object* lean_calc_nav(lean_object* portfolio)
    lean_object* lean_apply_trade(lean_object* portfolio, lean_object* trade)

def calc_nav(portfolio):
    """Calculate NAV by calling Lean."""
    # Convert Python → Lean
    lean_portfolio = python_to_lean_portfolio(portfolio)
    # Call Lean function
    result = lean_calc_nav(lean_portfolio)
    # Convert Lean → Python
    return lean_to_python_int(result)
```

---

## Component 2: Data Pipeline (Python + Lean Verification)

### Python: Multiple Data Sources

The data pipeline is **modular** - swap sources without changing accounting kernel:

**Historical Backtests (v0.10):**
```python
# python/src/hedge_engine/etl/wrds_loader.py

def load_option_metrics(start_date, end_date):
    """Load historical OptionMetrics data from WRDS."""
    # Connect to WRDS database
    # Load option prices, implied vols, etc.
    return options_dataframe
```

**MCMC Simulations (future):**
```python
# python/src/hedge_engine/simulation/mcmc.py

def generate_price_paths(initial (Source-Agnostic)

After getting data (historical OR simulated), Python describes it in a certificate:

```python
# python/src/hedge_engine/certificate/emitter.py

def emit_data_certificate(data, source_type, validation_results):
    """Emit certificate describing data - works for ANY source."""
    return {
        "version": "1.0",
        "source_type": source_type,  # "historical_wrds" | "mcmc_simulation" | "synthetic"
        "date_range": {"start": "2024-01-01", "end": "2024-12-31"},
        "row_count": len(data),
        "validation": {
            "no_nulls": validation_results.nulls_ok,
            "dates_monotonic": validation_results.dates_sorted,
            "prices_positive": validation_results.prices_valid,
        },
        "assumptions": {
            # These are what Lean verifies - same for any source!
            "max_strike_price": 10000.0,
            "min_days_to_expiry": 1,
            "implied_vol_range": [0.01, 5.0],
        }
    }
```

**Key**: Certificate describes "what the data looks like", NOT "where it came from". Lean verifies assumptions, doesn't care about source. """Emit certificate describing ETL output."""
    return {
        "version": "1.0",
        "etl_type": "option_metrics",
        "date_range": {"start": "2024-01-01", "end": "2024-12-31"},
        "row_count": len(data),
        "schema_version": "OptionMetrics_v2024",
        "validation": {
            "no_nulls": validation_results.nulls_ok,
            "dates_monotonic": validation_results.dates_sorted,
            "prices_positive": validation_results.prices_valid,
        },
        "assumptions": {
            "max_strike_price": 10000.0,
            "min_days_to_expiry": 1,
            "implied_vol_range": [0.01, 5.0],
        }
    }
``` (Source-Agnostic)

Lean validates assumptions, doesn't care if data is historical or simulated:

```lean
-- OptionHedge/Certificate/DataVerifier.lean

structure DataCertificate where
  version : String
  sourceType : String  -- "historical_wrds" | "mcmc_simulation" | etc.
  rowCount : Nat
  validation : ValidationResults
  assumptions : Assumptions

-- Verify assumptions - same check regardless of source!
def verifyDataAssumptions (cert : DataCertificate) : Bool :=
  cert.assumptions.maxStrikePrice ≤ MAX_ALLOWED_STRIKE ∧
  cert.assumptions.minDaysToExpiry ≥ MIN_DAYS_TO_EXPIRY ∧
  cert.validation.pricesPositive = true
  -- Source type is informational only, not part of verification

theorem dataCertificateValid (cert : DataCertificate)
  (h : verifyDataAssumptions cert = true) :
  -- Theorem holds for ANY data source
  (h : verifyETLAssumptions cert = true) :
  -- If certificate passes, data meets accounting kernel assumptions
  DataMeetsAssumptions cert := by
  ...
```

**Historical Backtest:**
```
┌─────────────────────────────────────────────┐
│  WRDS Database (OptionMetrics, FEDS)       │
└──────────────┬──────────────────────────────┘
               │
               ↓ SQL queries
┌─────────────────────────────────────────────┐
│  Python ETL (hedge_engine/etl/)             │
│  - Load historical data                     │
│  - Clean & validate                         │
└──────────────┬──────────────────────────────┘
               │
               ├─→ Emit Certificate (JSON)
               │   └─→ Lean verifies assumptions
               │
               ↓ Call via FFI (prices as input)
┌─────────────────────────────────────────────┐
│  Lean Accounting Kernel (compiled C)        │
│  - Accepts prices from ANY source           │
│  - calcNAV, applyTrade (pure functions)     │
└──────────────┬──────────────────────────────┘
               │
               ↓ Return results
┌─────────────────────────────────────────────┐
│  Python Orchestration                       │
│  - Receives NAV, updated portfolio          │
│  - Continues backtest                       │
└─────────────────────────────────────────────┘
```

**MCMC Simulation (future):**
```
┌─────────────────────────────────────────────┐
│  Stochastic Process Model (GBM, etc.)      │
└──────────────┬──────────────────────────────┘
               │
               ↓ Generate paths
┌─────────────────────────────────────────────┐
│  Python Simulator (hedge_engine/sim/)       │
│  - Generate price paths                     │
│  - Validate statistical properties          │
└──────────────┬──────────────────────────────┘
               │
               ├─→ Emit Certificate (JSON)
               │   └─→ Lean verifies assumptions (same as backtest!)
               │
               ↓ Call via FFI (simulated prices)
┌─────────────────────────────────────────────┐
│  SAME Lean Accounting Kernel                │
│  - Doesn't care if prices are historical    │
│  - Pure functions: state + prices → NAV     │
└──────────────┬──────────────────────────────┘
               │
               ↓ Return results
┌─────────────────────────────────────────────┐
│  Python MCMC Loop                           │
│  - Aggregate across scenarios               │
│  - Compute statistics                       │
└─────────────────────────────────────────────┘
```

**Key**: Same accounting kernel, different data sources!Python Orchestration                       │
│  - Receives NAV, updated portfolio          │
│  - Continues backtest                       │
└─────────────────────────────────────────────┘
```

---

## Milestone Breakdown

### v0.2-nav (Lean + FFI) — IN PROGRESS
- Setup Lake for Lean → C shared library compilation
- Implement `calcNAV` in Lean with `@[export]`
- Create Cython FFI bindings
- Add FFI round-trip tests
- Prove NAV identity theorem

### v0.3-trades (Lean + FFI)
- Define `Trade` type, implement `applyTrade` in Lean with `@[export]`
- Prove conservation, cash-correctness, and self-financing theorems
- Python: stub + Cython binding for `apply_trade`

### v0.4-data (Python only)
- WRDS OptionMetrics loader, FRED risk-free rate loader
- Data validation pipeline
- Synthetic test data generator (deterministic, for CI without WRDS)

### v0.5-certs (Python + Lean types)
- Certificate schema (Pydantic models + Lean `Certificate` structure)
- Certificate emission after ETL/trade steps

### v0.6-verifier (Lean + Python integration)
- Lean JSON parser for certificates
- Invariant verification pipeline (NAV, conservation, cash, self-financing)
- End-to-end: Python emits cert → Lean verifies → pass/fail

### v0.7-pricer (Python, DG400a validated)
- Black-Scholes pricing, Greeks, implied vol solver, vol surface
- Validated against DerivaGem (Hull & White) DG400a spreadsheets

### v0.8-options (Lean + Python)
- Option lifecycle: expiry/exercise, position rolls, mark-to-market
- Lean proofs for settlement and cash conservation at expiry

### v0.9-optimizer (Python + Lean specs)
- LP/QP hedging with CVaR objective (cvxpy)
- Rebalancing triggers, margin estimation
- Lean formal specification of constraints

### v0.10-backtest (Full integration)
- End-to-end backtest loop wiring all components
- NAV time series, PnL attribution, visualization

### v0.11-release (v1.0)
- Proof audit (zero `sorry`), CLI, JupyterBook docs, release

---

## Design Principles

### Flexibility for Future Use Cases

Accounting kernel works for multiple scenarios:
- **Backtests**: Historical WRDS data (v0.10)
- **MCMC simulations**: Stochastic price paths (future)
- **Stress testing**: Synthetic worst-case scenarios (future)
- **Live trading**: Real-time market feeds (future)
- **Research**: Custom data sources for academic studies

All use the same proven-correct accounting kernel.

### Swappable Data Layer

Can swap Python for another language without touching accounting:
- **R** for statistical analysis + same Lean kernel
- **Julia** for numerical computing + same Lean kernel
- **JavaScript** for web interfaces + same Lean kernel

---

## Anti-Patterns (What NOT to Do)

- **DON'T** implement accounting in Python (defeats formal verification)
- **DON'T** implement ETL/data loading in Lean (wrong tool for the job)
- **DON'T** hard-code data source assumptions in the kernel (must stay agnostic)
- **DON'T** mix responsibilities (certificates = Lean proof; data loading = Python I/O)

---

## Questions & Answers

**Q: Why not just write everything in Lean?**
A: ETL requires database connectors, pandas-like operations, visualization. Python's ecosystem is unmatched for data engineering.

**Q: Why not just write everything in Python?**
A: Can't formally verify Python code. Would have to trust accounting implementation. Defeats the whole point of formal verification.

**Q: How does this support MCMC simulations?**
A: Accounting kernel is pure functions — doesn't care if prices are historical or simulated. Just swap the data source and use the same kernel. Certificate verifier checks the same assumptions regardless of source.

**Q: What's the FFI overhead?**
A: ~10-50ns per function call. For batch operations (e.g., applying 1000 trades), amortized cost is negligible.

**Q: How are types converted across FFI?**
A: Lean `Int` → C `lean_object*` → Cython wrapper → Python `int`. Strings, arrays require marshaling. See DEVELOPMENT.md for details.

**Q: What if certificate verification fails?**
A: Backtest halts. Certificate shows exactly which assumption was violated (e.g., "negative price detected"). Fix the data pipeline and rerun.

---

## Further Reading

- [DECISIONS.md](../../DECISIONS.md) - ADR-000 (Architecture), ADR-001 (Numeric Types)
- [DEVELOPMENT.md](../../DEVELOPMENT.md) - FFI implementation details
- [Lean 4 FFI Examples](https://github.com/leanprover/lean4/tree/master/tests/lake/examples/ffi)
