# Development Guide

Deep technical reference for Options Hedge Engine development.

---

## Table of Contents

1. [Makefile Reference](#makefile-reference)
2. [Lean Project Structure](#lean-project-structure)
3. [Python Package Architecture](#python-package-architecture)
4. [Certificate Schema Evolution](#certificate-schema-evolution)
5. [Adding New Invariants](#adding-new-invariants)
6. [CI Pipeline Details](#ci-pipeline-details)
7. [Performance Profiling](#performance-profiling)
8. [ADR Template](#adr-template)

---

## Makefile Reference

### Root Makefile

All targets orchestrate operations across `lean/` and `python/` subdirectories.

| Target | Description | Dependencies |
|--------|-------------|--------------|
| `make help` | Show available targets | None |
| `make setup` | Install Lean + Python deps | elan, uv |
| `make build` | Compile proofs + Python pkg | setup |
| `make test` | Run all tests | build |
| `make lint` | Lint + typecheck Python | setup |
| `make clean` | Remove build artifacts | None |
| `make docs-build` | Build JupyterBook | setup |
| `make docs-serve` | Serve docs on :8000 | docs-build |
| `make integration` | Run Python → Lean test | build |
| `make dev-lean` | Open Lean in VSCode | None |
| `make dev-python` | Activate Python shell | setup |
| `make watch-lean` | Auto-rebuild Lean | setup |
| `make ci-local` | Simulate CI with `act` | act installed |

**Shortcuts:**
- `make l` → `cd lean && lake build`
- `make p` → `cd python && uv run pytest`
- `make d` → `make docs-serve`

### Lean Makefile (`lean/Makefile`)

| Target | Command | Notes |
|--------|---------|-------|
| `setup` | Install elan | Downloads Lean toolchain |
| `build` | `lake build` | Compiles all Lean files |
| `test` | `lake test` | Runs test suites |
| `clean` | `lake clean` | Removes build/ |
| `watch` | `lake build --watch` | Continuous compilation |

### Python Makefile (`python/Makefile`)

| Target | Command | Notes |
|--------|---------|-------|
| `setup` | `uv sync` | Installs from uv.lock |
| `build` | `uv build` | Creates wheel/sdist |
| `test` | `uv run pytest` | With coverage |
| `lint` | `uv run ruff check` | Code quality |
| `typecheck` | `uv run mypy` | Type validation |
| `format` | `uv run ruff format` | Auto-format code |
| `clean` | Remove caches | .venv, .pytest_cache, etc. |

---

## Lean Project Structure

### Directory Layout

```
lean/
├── lakefile.lean          # Lake build configuration
├── lean-toolchain         # Lean version (e.g., leanprover/lean4:v4.X.0)
├── Makefile               # Lean-specific targets
├── OptionHedge/
│   ├── Basic.lean         # Core types: Portfolio, Position, Asset
│   ├── Numeric.lean       # Price, Decimal4 (scaled integers)
│   ├── Accounting.lean    # calcNAV, applyTrade, accrueInterest
│   ├── Invariants.lean    # Theorem statements (all invariants)
│   ├── Proofs/            # Individual proofs for each invariant
│   │   ├── NAVIdentity.lean
│   │   ├── SelfFinancing.lean
│   │   ├── Conservation.lean
│   │   ├── CashCorrectness.lean
│   │   ├── TimeMonotonicity.lean
│   │   ├── DomainConstraints.lean
│   │   └── DeterministicReplay.lean
│   └── Certificate/       # JSON certificate handling
│       ├── Schema.lean    # Certificate structure definition
│       ├── Parser.lean    # JSON → Lean types
│       └── Verifier.lean  # Main verification entry point
└── Tests/
    ├── UnitTests.lean     # Basic test cases
    └── IntegrationFixtures.lean  # Test data for integration
```

### Lake Build System

**lakefile.lean** structure:
```lean
import Lake
open Lake DSL

package optionHedge {
  -- Package configuration
}

lean_lib OptionHedge {
  -- Library configuration
}

lean_exe verify_certs {
  root := `OptionHedge.Certificate.Verifier
  -- CLI executable for certificate verification
}

@[default_target]
lean_lib OptionHedge
```

### Numeric Type Design

**Scaled Integer Approach:**
```lean
-- Represent $123.4567 as 1234567 basis points (×10,000)
structure Price where
  basisPoints : Int
  deriving Repr, BEq

def Price.fromDecimal (intPart : Int) (fracPart : Nat) : Price :=
  ⟨intPart * 10000 + fracPart⟩

def Price.add (a b : Price) : Price :=
  ⟨a.basisPoints + b.basisPoints⟩

def Price.mul (a b : Price) : Price :=
  -- Careful: (a × 10⁴) × (b × 10⁴) = result × 10⁸
  ⟨(a.basisPoints * b.basisPoints) / 10000⟩

theorem Price.add_assoc (a b c : Price) :
  Price.add (Price.add a b) c = Price.add a (Price.add b c) := by
  simp [Price.add]
  ring
```

### Proof Workflow

1. **Define theorem** in `Invariants.lean`:
   ```lean
   theorem navIdentity (p : Portfolio) :
     calcNAV p = p.cash + (sumPositionValues p.positions) := by
     sorry  -- Placeholder
   ```

2. **Implement proof** in `Proofs/NAVIdentity.lean`:
   ```lean
   import OptionHedge.Invariants
   import OptionHedge.Accounting

   theorem navIdentity (p : Portfolio) :
     calcNAV p = p.cash + (sumPositionValues p.positions) := by
     unfold calcNAV sumPositionValues
     simp [List.foldl]
     -- Detailed proof steps...
   ```

3. **Import proof** back in `Invariants.lean`:
   ```lean
   import OptionHedge.Proofs.NAVIdentity
   -- Theorem now proven
   ```

---

## Python Package Architecture

### Directory Layout

```
python/
├── pyproject.toml         # Project metadata + dependencies
├── uv.lock                # Locked dependency versions
├── .python-version        # Python version (3.12)
├── Makefile               # Python-specific targets
├── src/
│   └── hedge_engine/
│       ├── __init__.py
│       ├── numeric.py     # Decimal types (mirrors Lean)
│       ├── state.py       # Portfolio, Position dataclasses
│       ├── accounting.py  # NAV, cash calculations
│       ├── pricer/
│       │   ├── __init__.py
│       │   ├── black_scholes.py  # BS formula + Greeks
│       │   └── hull_reference.py # DG validation helpers
│       ├── optimizer/
│       │   ├── __init__.py
│       │   ├── lp_hedger.py      # scipy/cvxpy LP solver
│       │   └── cvar.py           # CVaR optimization
│       ├── etl/
│       │   ├── __init__.py
│       │   └── market_data.py    # Data loading/validation
│       ├── certificate/
│       │   ├── __init__.py
│       │   ├── schema.py         # Pydantic models
│       │   └── emitter.py        # Serialize to JSON
│       └── cli.py                # Click-based CLI
├── tests/
│   ├── conftest.py        # pytest fixtures
│   ├── test_numeric.py    # Cross-validate with Lean
│   ├── test_accounting.py
│   ├── test_pricer.py
│   ├── test_certificate.py
│   └── fixtures/
│       └── tiny_cert_stream.json  # 3-step test scenario
└── scripts/
    └── emit_test_certs.py # Generate test certificates
```

### pyproject.toml Structure

```toml
[project]
name = "hedge-engine"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "pydantic>=2.0",
    "numpy>=1.24",
    "scipy>=1.11",
    "cvxpy>=1.4",
    "click>=8.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "pytest-cov>=4.0",
    "mypy>=1.5",
    "ruff>=0.1",
    "ipython>=8.0",
]
docs = [
    "jupyter-book>=0.15",
    "matplotlib>=3.7",
    "seaborn>=0.12",
]

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=hedge_engine --cov-report=term-missing"
```

### Numeric Precision Pattern

```python
from decimal import Decimal, getcontext

# Set high precision globally
getcontext().prec = 28

class Price:
    """Represents monetary amount with exact decimal precision.

    Internally stores as Decimal. Converts to/from Lean's basis points.
    """

    def __init__(self, value: Decimal | str | int) -> None:
        if isinstance(value, int):
            # From Lean: basis points
            self.value = Decimal(value) / 10000
        else:
            self.value = Decimal(str(value))

    def to_lean_int(self) -> int:
        """Convert to basis points for Lean interop."""
        return int(self.value * 10000)

    def __add__(self, other: "Price") -> "Price":
        return Price(self.value + other.value)

    def __str__(self) -> str:
        return f"{self.value:.4f}"  # Always 4 decimals
```

---

## Certificate Schema Evolution

### Versioning Strategy

**Schema Version Format**: `major.minor` (e.g., "1.0", "1.1", "2.0")

- **Major bump** (1.0 → 2.0): Breaking changes (field removal, type change)
- **Minor bump** (1.0 → 1.1): Backward-compatible additions (new optional fields)

### Schema Change Workflow

1. **Propose change** in GitHub Issue/Discussion
2. **Update Python schema** (`certificate/schema.py`):
   ```python
   class CertificateV1_1(BaseModel):
       version: str = "1.1"  # Increment version
       new_field: Optional[str] = None  # Add new field
       # ... existing fields
   ```

3. **Update Lean schema** (`Certificate/Schema.lean`):
   ```lean
   structure Certificate where
     version : String
     newField : Option String  -- Match Python
     -- ... existing fields
   ```

4. **Update parser** (`Certificate/Parser.lean`)
5. **Add migration test** (v1.0 → v1.1 compatibility)
6. **Update docs** (`book/architecture/certificate_flow.md`)
7. **Increment milestone** if breaking change

### Backward Compatibility

```python
def parse_certificate(data: dict) -> Certificate:
    """Parse certificate with version detection."""
    version = data.get("version", "1.0")

    if version == "1.0":
        return CertificateV1_0.model_validate(data)
    elif version == "1.1":
        return CertificateV1_1.model_validate(data)
    else:
        raise ValueError(f"Unsupported schema version: {version}")
```

---

## Adding New Invariants

Complete workflow for adding a new formally verified invariant.

### Step 1: Document Rationale

Add to [RISKS.md](RISKS.md) or [DECISIONS.md](DECISIONS.md):
```markdown
## Why This Invariant Matters

**Property**: Fee Non-Negativity
**Rationale**: Ensures no negative fees (would imply system paying trader)
**Impact**: Critical for accounting correctness
```

### Step 2: Define Lean Theorem

In `OptionHedge/Invariants.lean`:
```lean
/-- All transaction fees must be non-negative -/
theorem fees_non_negative (t : Trade) : t.fee ≥ 0 := by
  sorry  -- Placeholder for now
```

### Step 3: Implement Proof

Create `OptionHedge/Proofs/FeeNonNegativity.lean`:
```lean
import OptionHedge.Invariants
import OptionHedge.Basic

theorem fees_non_negative (t : Trade) : t.fee ≥ 0 := by
  cases t with
  | mk asset delta price fee =>
    -- fee is constructed from Nat, so always ≥ 0
    exact Nat.zero_le fee
```

### Step 4: Add to Verifier

In `OptionHedge/Certificate/Verifier.lean`:
```lean
def checkFeeNonNegativity (cert : Certificate) : Bool :=
  cert.action.trades.all (fun t => t.fee ≥ 0)

def verifyCertificate (cert : Certificate) : VerificationResult :=
  let checks := [
    ("NAV Identity", checkNAVIdentity cert),
    ("Fee Non-Negativity", checkFeeNonNegativity cert),  -- Add here
    -- ... other checks
  ]
  combineResults checks
```

### Step 5: Test in Python

In `tests/test_invariants.py`:
```python
def test_fee_non_negativity():
    """Fees must always be non-negative."""
    trade = Trade(asset_id="SPY", delta=100, price=400.0, fee=-1.0)
    cert = emit_certificate(portfolio, [trade])

    # Should fail verification
    result = verify_with_lean(cert)
    assert not result.success
    assert "Fee Non-Negativity" in result.failures
```

### Step 6: Document

Create `book/invariants/fee_non_negativity.ipynb`:
```markdown
# Fee Non-Negativity Invariant

## Mathematical Definition

$$\forall t \in \text{Trades} : t.\text{fee} \geq 0$$

## Rationale

Transaction fees represent costs to the trader...

## Proof Sketch

[LaTeX proof steps]

## Code Implementation

[Show Lean proof]
[Show Python validation]
```

---

## CI Pipeline Details

### GitHub Actions Workflows

#### 1. Lean Build (`.github/workflows/lean.yml`)

```yaml
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Lean
        run: |
          curl -sSfL https://github.com/leanprover/elan/releases/download/v3.0.0/elan-x86_64-unknown-linux-gnu.tar.gz | tar xz
          ./elan-init -y --default-toolchain none
      - name: Cache Lake
        uses: actions/cache@v4
        with:
          path: |
            ~/.elan
            lean/build
          key: lean-${{ hashFiles('lean/lakefile.lean') }}
      - name: Build Proofs
        run: cd lean && make build
      - name: Check for Axioms
        run: |
          count=$(grep -r "axiom" lean/OptionHedge --exclude-dir=build | wc -l)
          echo "Axiom count: $count"
          # Fail if count increases (track in GitHub env)
```

#### 2. Python Tests (`.github/workflows/python.yml`)

```yaml
on: [push, pull_request]
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - name: Install uv
        uses: astral-sh/setup-uv@v4
      - name: Run Tests
        run: cd python && make test
      - name: Check Coverage
        run: cd python && uv run pytest --cov-fail-under=80
```

#### 3. Integration (`.github/workflows/integration.yml`)

```yaml
on: [push, pull_request]
needs: [lean-build, python-test]
jobs:
  integrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup
        run: make setup
      - name: Run Integration
        run: make integration
      - name: Upload Artifacts
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: failed-certs
          path: /tmp/certs.json
```

### Local CI Simulation

```bash
# Install act (GitHub Actions local runner)
brew install act  # macOS
# or: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run specific job
act -j lean-build

# Run all jobs
act

# Use different Docker image
act -P ubuntu-latest=catthehacker/ubuntu:act-latest
```

---

## Performance Profiling

### Lean Verifier Profiling

```bash
# Profile certificate verification
cd lean
lake exe verify_certs /path/to/certs.json --profile

# Output shows time per function
# Optimize hotspots (likely JSON parsing or arithmetic)
```

### Python Profiling

```python
# tests/test_performance.py
import cProfile
import pstats
from hedge_engine.backtest import run_backtest

def test_backtest_performance():
    profiler = cProfile.Profile()
    profiler.enable()

    run_backtest(days=100)

    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.sort_stats('cumtime')
    stats.print_stats(20)  # Top 20 functions
```

```bash
# Run profiling
uv run pytest tests/test_performance.py -v -s

# Use line_profiler for detailed analysis
uv add kernprof
uv run kernprof -l -v script.py
```

### Benchmark Targets

| Component | Target | Current | Status |
|-----------|--------|---------|--------|
| Lean verify (1 cert) | <10ms | TBD | 🟡 |
| Python cert emit | <1ms | TBD | 🟡 |
| Backtest (100 steps) | <10s | TBD | 🟡 |
| BS pricing (1 option) | <0.1ms | TBD | 🟡 |
| LP solve (10 assets) | <100ms | TBD | 🟡 |

---

## ADR Template

For new architectural decisions, add to [DECISIONS.md](DECISIONS.md):

```markdown
## ADR-XXX: [Title]

**Status**: ✅ Accepted / 🔄 Proposed / ❌ Rejected
**Date**: YYYY-MM-DD
**Deciders**: [Names/roles]
**Consulted**: [Experts/references]

### Context

[Describe the problem and constraints]

### Decision

[Describe the chosen solution]

### Rationale

1. [Reason 1]
2. [Reason 2]
3. [Reason 3]

### Consequences

**Positive**:
- [Benefit 1]
- [Benefit 2]

**Negative**:
- [Drawback 1]
- [Drawback 2]

**Neutral**:
- [Trade-off 1]

### Alternatives Considered

1. **[Alternative 1]**: [Why rejected]
2. **[Alternative 2]**: [Why rejected]

### Consultation Points

- [Question for experts]
- [Area requiring validation]

### References

- [Link 1]
- [Link 2]
```

---

## Debugging Tips

### Lean Debugging

```lean
-- Add trace messages
#check myFunction  -- Show type
#eval myFunction arg  -- Evaluate

-- Use sorry with comments
theorem myTheorem : ... := by
  sorry  -- TODO: Prove using induction on positions
```

### Python Debugging

```python
# Use ipdb for interactive debugging
import ipdb; ipdb.set_trace()

# Or use pytest with pdb
pytest --pdb  # Drop into debugger on failure

# Print with rich
from rich import print as rprint
rprint(portfolio)  # Pretty-printed output
```

---

## Further Reading

- [Lean 4 Manual](https://leanprover.github.io/lean4/doc/)
- [Mathlib4 Docs](https://leanprover-community.github.io/mathlib4_docs/)
- [uv Documentation](https://docs.astral.sh/uv/)
- [JupyterBook Guide](https://jupyterbook.org/)

---

**Last Updated**: 2026-01-18 (v0.1-scaffold)
