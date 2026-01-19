# Risk Register

**Purpose**: Document all identified risks, mitigation strategies, and decision rationale. Consult with professors/practitioners before major pivots.

**Last Updated**: 2026-01-18
**Review Cadence**: Every milestone completion
**Status**: Work in Progress (v0.1-scaffold)

---

## R1: Decimal Precision Policy

**Risk**: Mismatch between Python `float64` and Lean numeric types causes NAV discrepancies.

**Severity**: 🔴 Critical (breaks verification)

**Mitigation Strategy** ✅ DECIDED:
- **Lean**: Use scaled `Int` (basis points: `Int` × 10,000 for 4 decimals)
  - Type: `structure Price where basisPoints : Int`
  - Rationale: Exact decimal arithmetic, standard in financial systems, fast, provably correct
- **Python**: Use `decimal.Decimal` (arbitrary precision)
  - Convert to int (basis points) at FFI boundary
  - Never use `float` for accounting/cash/prices
- **Float exception**: Black-Scholes/Greeks use `float` for performance, then convert to `Decimal`
- **Tolerance**: Allow ε = 0.0001 (1 basis point) in verification for numerical stability

**Implementation**: v0.2-numeric

**References**:
- Industry practice: Java `BigDecimal`, Python `decimal`, Rust `rust_decimal`
- Lean community: Scaled integers recommended for financial computing
- Research: See DECISIONS.md ADR-001

**Open Questions** 🤔:
- Should options Greeks use higher precision (8 decimals)? → Consult quant researchers
- How to handle very small probabilities in CVaR? → May need `Rat` for tail calculations

**Alternatives Considered**:
1. `Rat` everywhere: Exact fractions, but denominators grow unpredictably (GCD overhead)
2. `Float` everywhere: Fast but non-deterministic, rounding errors accumulate
3. Mixed (current choice): Exact for accounting, approximate for analytics

---

## R2: Interface Churn (Lean ↔ Python Schema Drift)

**Risk**: Lean types evolve independently from Python Pydantic models, breaking integration.

**Severity**: 🟡 Medium (slows development)

**Mitigation Strategy** ✅ DECIDED:
- **Version field** in JSON schema (`"version": "1.0"`)
- **Schema sync test**: Roundtrip test (Python serialize → Lean parse → verify types)
- **Code generation** (future): Meta-program to generate Pydantic from Lean (or vice versa)
  - Script: `scripts/generate_pydantic_from_lean.py` (v0.7+)
- **Property tests**: Hypothesis tests comparing Lean/Python accounting outputs
- **Monorepo benefit**: Both in same repo, easier to keep in sync

**Implementation**: v0.5-certs (schema), v0.7-integration (sync tests)

**Monitoring**:
- CI fails if schema version mismatch detected
- Integration test exercises full schema

**Open Questions** 🤔:
- Should we generate Python from Lean, or Lean from Python? → Lean is source of truth (formal spec)
- Use external schema DSL (Protocol Buffers, JSON Schema)? → Adds complexity, defer to v0.7

**Fallback**: Manual sync with strict review process + automated tests

---

## R3: JSON Parsing Complexity in Lean

**Risk**: Lean's JSON support is verbose; parsing nested structures is error-prone.

**Severity**: 🟡 Medium (development friction)

**Mitigation Strategy** ✅ DECIDED:
- **Incremental complexity**: Start with flat schema (v0.5), add nesting in v0.6+
- **Helper functions**: Write reusable JSON parsers in `Certificate/Parser.lean`
- **Validation layer**: Parse to unvalidated types, then validate separately
- **Future optimization**: If JSON proves unwieldy, consider MessagePack or Cap'n Proto
  - Benchmark required: >1000 certs/sec throughput

**Implementation**: v0.6-verifier

**Resources**:
- Use `Lean.Json` from Lean 4 core
- Pattern: `Json.getObj? >>= (·.get? "field") >>= Json.getInt?`

**Open Questions** 🤔:
- Should we use Lean meta-programming to derive JSON parsers? → Explore in v0.6
- Performance target: Can Lean verify 100 certs/sec? → Profile in v0.11

**Fallback**: Binary format (msgpack) if JSON latency >100ms per cert

---

## R4: Numerical Tolerances (Float ↔ Decimal Conversion)

**Risk**: Conversion between pricer `float` and accounting `Decimal` introduces precision loss.

**Severity**: 🟡 Medium (affects invariant checking)

**Mitigation Strategy** ✅ DECIDED:
- **Tolerance parameter**: Lean verifier accepts `epsilon : Rat` (default: 0.0001 = 1bp)
- **Documented precision**: All certificates include `"precision_decimals": 4` field
- **Conversion rules**:
  - `float` → `Decimal`: Use `Decimal(str(round(float_val, 6)))` (6 decimals, then round to 4)
  - `Decimal` → Lean `Int`: Multiply by 10,000, round to nearest integer
- **Proof**: Prove invariants hold within ε (e.g., `|NAV_calc - NAV_cert| < ε`)
- **Test suite**: Include edge cases (very small/large numbers, near-zero differences)

**Implementation**: v0.6-verifier (tolerance), v0.8-pricer (conversion)

**Monitoring**:
- Log all tolerance violations in certificates
- Alert if >1% of steps exceed ε/2

**Open Questions** 🤔:
- Should epsilon vary by invariant? (e.g., stricter for cash, looser for Greeks) → Consult practitioners
- How to handle accumulation of errors over long backtests? → May need periodic "reset" with exact recomputation

**Fallback**: If tolerance violations common, switch pricer to `Decimal` (accept performance hit)

---

## R5: Lean Proof Difficulty Underestimation

**Risk**: Invariants assumed "easy" require deep Mathlib expertise, blocking progress.

**Severity**: 🟠 High (schedule risk)

**Mitigation Strategy** ✅ DECIDED:
- **Prioritization**: Prove simple invariants first (NAV identity, conservation)
- **Defer complex proofs**: Self-financing requires field theory; defer to later milestones
- **Escape hatches**: Use `axiom` temporarily with `-- TODO: prove` comment
  - CI warning (not failure) if `axiom` count increases
- **Expert consultation**: Budget time to ask on Lean Zulip or engage theorem-proving consultant
- **Incremental approach**: Prove special cases first (e.g., single-asset portfolio), generalize later

**Implementation**: v0.3-nav (simple), v0.13-proofs (complete)

**Monitoring**:
- Track `axiom` count in CI
- Allocate 20% time buffer in proof-heavy milestones

**Open Questions** 🤔:
- Which invariant is hardest? → NAV identity likely easiest, self-financing hardest
- Should we hire a Lean expert consultant? → Decide after v0.3 if blocked >1 week

**Fallback**: Accept `axiom` for v1.0, target full proofs in v2.0

---

## R6: Performance - Lean Verification Latency

**Risk**: Verifying each certificate takes seconds, making backtest infeasibly slow.

**Severity**: 🟡 Medium (usability)

**Mitigation Strategy** ✅ DECIDED:
- **Batch verification**: Verify 100 certs at once (single Lean process)
- **Compiled executable**: Build optimized binary (`lake build --release`)
- **Async verification**: Verify timestep t-1 while Python computes timestep t
- **Profiling**: Use Lean's `--profile` flag to identify bottlenecks in v0.11
- **Sampling**: For 10k-step backtests, verify every 10th step in dev (full verify in CI)
- **Performance target**: <10ms per certificate (100 certs/sec)

**Implementation**: v0.11-backtest (profiling), v0.15 (optimization)

**Benchmark Plan** (v0.11):
1. Measure baseline: single cert verification time
2. Test batching: 10, 100, 1000 certs
3. Identify hotspots: JSON parsing vs. invariant checking

**Open Questions** 🤔:
- Should we use Lean FFI (call Lean from Python directly)? → Reduces serialization overhead, but complex
- Can we parallelize verification? → Explore Lean's `Task` API

**Fallback**: If <10ms infeasible, verify only critical steps (trade execution, expiry) + sample others

---

## R7: DerivaGem Reference Mismatch

**Risk**: Spreadsheet pricing differs from Python Black-Scholes due to undocumented quirks.

**Severity**: 🟢 Low (reference issue, not system risk)

**Mitigation Strategy** ✅ DECIDED:
- **Use as sanity check only**: DG400a is not ground truth, just a reference
- **Document divergences**: Track known differences in `book/architecture/pricer_validation.md`
- **Analytical benchmarks**: Test against known solutions (European call put-call parity, ATM straddle)
- **Multiple references**: Compare to QuantLib, OptionMetrics formulas
- **Tolerance**: Allow 1% difference from DG spreadsheets (document when exceeded)

**Implementation**: v0.8-pricer

**Testing Strategy**:
- Unit tests: Black-Scholes matches analytical solutions (ATM, ITM, OTM)
- Integration tests: Compare Python pricer to DG spreadsheet on sample grid
- Log warnings (not errors) for >1% divergence

**Open Questions** 🤔:
- Should we reverse-engineer DG spreadsheet formulas? → No, too time-consuming
- Which pricer to trust when they disagree? → Analytical solution > QuantLib > DG

**Fallback**: If systematic divergence found, add adjustment factor (document in cert metadata)

---

## R8: CI Timeout on Large Integration Tests

**Risk**: Full backtest emits 10k certs; CI times out (GitHub Actions: 6hr limit).

**Severity**: 🟢 Low (process issue)

**Mitigation Strategy** ✅ DECIDED:
- **Tiny fixture in CI**: ≤10 certs for fast feedback (<1 min total)
  - Fixture: `tests/fixtures/tiny_cert_stream.json`
- **Nightly job**: Separate workflow for full backtest (100-1000 certs)
  - Workflow: `.github/workflows/nightly.yml` (future)
- **Sampling in CI**: Verify every 100th cert for medium-sized tests
- **Caching**: Cache Lean build artifacts (`~/.elan`, `build/`)

**Implementation**: v0.7-integration

**CI Strategy**:
- PR checks: Tiny fixture (fast feedback)
- Main branch: Medium fixture (100 certs)
- Nightly/weekly: Full backtest

**Open Questions** 🤔:
- Use GitHub Actions large runners for faster CI? → Cost-benefit analysis needed
- Self-hosted runners? → Security concerns, defer unless critical

**Fallback**: Run full tests locally before release (manual verification)

---

## R9: JupyterBook Execution Timeout

**Risk**: Notebooks with large backtests time out during `jupyter-book build`.

**Severity**: 🟢 Low (documentation issue)

**Mitigation Strategy** ✅ DECIDED:
- **Execution timeout**: Set `execution_timeout: 300` (5 min) in `book/_config.yml`
- **Cache mode**: Use `execution_mode: cache` for slow notebooks
  - Execute manually, commit outputs (`.ipynb` with cells executed)
  - JupyterBook skips re-execution if cached
- **Smaller datasets**: Use 20-step backtests in docs, not 1000-step
- **Pre-execution**: For expensive notebooks, run `make docs-execute` locally before commit

**Implementation**: v0.5-scaffold (config), v0.14-docs (notebooks)

**Workflow**:
1. Develop notebook interactively
2. Execute with full data
3. Clear outputs, save
4. Run `make docs-execute` (executes & caches)
5. Commit with outputs
6. CI builds book in cache mode (fast)

**Open Questions** 🤔:
- Should we use Binder for live execution? → Requires Docker image, defer to future
- Separate "live" vs "static" notebooks? → Tag expensive ones with warning banner

**Fallback**: Pre-execute all notebooks, commit outputs, disable execution in CI

---

## R10: uv Lock File Drift (Cross-Platform)

**Risk**: Team members on Linux/macOS/Windows get different dependency versions.

**Severity**: 🟡 Medium (reproducibility)

**Mitigation Strategy** ✅ DECIDED:
- **Pin Python version**: `.python-version` (3.12)
- **Universal lock**: Use `uv lock --universal` (cross-platform resolution)
- **CI matrix**: Test on Linux, macOS, Windows (GitHub Actions)
  - Workflow: `.github/workflows/python.yml` with `matrix: [ubuntu, macos, windows]`
- **Lockfile in git**: Commit `uv.lock`
- **Regular updates**: `uv lock --upgrade` monthly (scheduled PR)

**Implementation**: v0.1-scaffold (lockfile), v0.7-integration (CI matrix)

**Testing**:
- CI runs on all platforms
- Developer setup: `make setup` verifies lockfile hash

**Open Questions** 🤔:
- Support Python 3.11 as well? → Stick to 3.12 for simplicity (reassess in v1.0)
- Pin transitive dependencies? → uv handles this automatically

**Fallback**: If platform issues persist, use Docker for dev environment (heavier but reproducible)

---

## R11: Makefile Portability (Windows)

**Risk**: Makefile doesn't work on Windows without WSL/Cygwin.

**Severity**: 🟡 Medium (accessibility)

**Mitigation Strategy** ✅ DECIDED:
- **Require WSL on Windows**: Document in CONTRIBUTING.md
  - WSL 2 is standard on Windows 10/11, widely adopted
- **Alternative**: Provide PowerShell script `scripts/setup.ps1` for Windows users (future)
  - Mirrors Makefile targets (`.\scripts\setup.ps1 build`)
- **Future**: Consider `justfile` (cross-platform Make alternative)
  - Defer to v0.15 based on user feedback
- **CI**: Windows job runs via WSL or PowerShell

**Implementation**: v0.1-scaffold (Makefile), future (PowerShell)

**Documentation**:
- CONTRIBUTING.md: "Windows users: use WSL or PowerShell scripts"
- README.md: Note WSL requirement

**Open Questions** 🤔:
- Invest in full Windows native support (batch/PowerShell)? → Wait for user requests
- Switch to `just` or `task` now? → Stick with Make (familiar), reassess in v0.15

**Fallback**: Docker-based dev environment (works everywhere, no Make needed)

---

## R12: Data Decryption Key Management

**Risk**: Decryption key for `data/` leaks via commit history or CI logs.

**Severity**: 🔴 Critical (security/compliance)

**Mitigation Strategy** ✅ DECIDED:
- **Never commit key**: Add to `.gitignore` and `data/.gitignore`
  - Pattern: `*.key`, `*.pem`, `secrets.*`
- **git-crypt**: Encrypt data files at rest in repo
  - Setup: `git-crypt init`, add `data/.gitattributes`
  - Pattern: `*.csv filter=git-crypt diff=git-crypt`
- **Key handoff**: Secure channel only (Signal, 1Password share, GPG-encrypted email)
  - Document in `data/README.md`: "Request key via secure channel"
- **CI**: Use GitHub Secrets for decryption key
  - Workflow: `env: DECRYPT_KEY: ${{ secrets.DATA_DECRYPT_KEY }}`
  - Never log key or decrypted data
- **Access control**: Limit who can access GitHub Secrets (admin only)
- **Rotation**: Rotate key if leaked (re-encrypt all data)

**Implementation**: v0.1-scaffold (git-crypt config), v0.10-data (unlock)

**Operational Procedure**:
1. New contributor requests access → secure key handoff
2. Run `git-crypt unlock /path/to/key` (one-time setup)
3. Data transparently encrypted/decrypted by git

**Monitoring**:
- Audit git history for accidental key commits (`git log -p | grep -i "key"`)
- GitHub Secret access logs

**Open Questions** 🤔:
- Use hardware key (YubiKey) for extra security? → Overkill for academic project, reassess if productionizing
- Separate keys for dev vs. CI? → Yes, different keys (principle of least privilege)

**Fallback**: If git-crypt too complex, use external encrypted storage (S3 with KMS, decrypt locally)

---

## Summary Risk Matrix

| ID | Risk | Severity | Status | Milestone |
|----|------|----------|--------|-----------|
| R1 | Decimal precision | 🔴 Critical | ✅ Mitigated | v0.2-numeric |
| R2 | Schema drift | 🟡 Medium | ✅ Mitigated | v0.7-integration |
| R3 | JSON parsing | 🟡 Medium | ✅ Mitigated | v0.6-verifier |
| R4 | Float tolerances | 🟡 Medium | ✅ Mitigated | v0.6, v0.8 |
| R5 | Proof difficulty | 🟠 High | 🔄 Monitoring | v0.3, v0.13 |
| R6 | Verification perf | 🟡 Medium | 🔄 Monitoring | v0.11, v0.15 |
| R7 | DG mismatch | 🟢 Low | ✅ Accepted | v0.8-pricer |
| R8 | CI timeout | 🟢 Low | ✅ Mitigated | v0.7-integration |
| R9 | Docs timeout | 🟢 Low | ✅ Mitigated | v0.14-docs |
| R10 | uv lock drift | 🟡 Medium | ✅ Mitigated | v0.1, v0.7 |
| R11 | Windows Make | 🟡 Medium | ✅ Mitigated | v0.1-scaffold |
| R12 | Key leak | 🔴 Critical | ✅ Mitigated | v0.1, v0.10 |

**Review Schedule**: Update after each milestone; full review before v1.0.

---

## Notes

This is a living document. Risks are documented candidly to facilitate informed decision-making. Consultation with domain experts (professors, practitioners) is encouraged before making major architectural changes.
