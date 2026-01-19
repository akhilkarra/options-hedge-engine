"""
Hedge Engine - Formally Verified Options Portfolio Hedging

Python handles:
1. ETL: Load data from WRDS/FEDS, process and validate
2. Certificate emission: Describe ETL results in JSON for Lean verification
3. FFI bindings: Call Lean accounting kernel via Cython

Lean handles:
1. Accounting kernel: ALL portfolio accounting logic (compiled to C, called via FFI)
2. Certificate verification: Validate ETL certificates against assumptions
"""

__version__ = "0.1.0"
