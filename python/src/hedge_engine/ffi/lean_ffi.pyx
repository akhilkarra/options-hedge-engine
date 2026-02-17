# cython: language_level=3
"""
Cython FFI bindings to Lean 4 accounting kernel.

Exposes @[export hedge_*] functions from OptionHedge.Accounting.
"""

cdef extern from "lean/lean.h":
    ctypedef void* lean_object

    # Lean runtime initialization
    void lean_initialize_runtime_module()
    void lean_io_mark_end_initialization()

    # Reference counting
    void lean_inc(lean_object*)
    void lean_dec(lean_object*)

    # Integer operations
    lean_object* lean_box(size_t)
    lean_object* lean_int_to_int(lean_object*)
    int lean_is_scalar(lean_object*)

# External declarations for Lean @[export hedge_*] functions
cdef extern from *:
    """
    // Forward declarations for Lean exports (Accounting.lean)
    extern lean_object* hedge_position_value(lean_object*);
    extern lean_object* hedge_sum_position_values(lean_object*);
    extern lean_object* hedge_portfolio_nav(lean_object*);
    extern lean_object* hedge_mk_portfolio(lean_object*, lean_object*);
    extern lean_object* hedge_get_position(lean_object*, lean_object*);
    """
    lean_object* hedge_position_value(lean_object*)
    lean_object* hedge_sum_position_values(lean_object*)
    lean_object* hedge_portfolio_nav(lean_object*)
    lean_object* hedge_mk_portfolio(lean_object*, lean_object*)
    lean_object* hedge_get_position(lean_object*, lean_object*)


def initialize_lean():
    """Initialize Lean runtime. Call once before using any FFI functions."""
    lean_initialize_runtime_module()
    lean_io_mark_end_initialization()


# TODO: Implement Portfolio/Position marshalling (Python dict <-> Lean object)
# For now, stubs in __init__.py are used. Full implementation requires:
# 1. Python dict -> Lean Position constructor (hedge_mk_position?)
# 2. Python list[dict] -> Lean List Position
# 3. Lean Int -> Python int extraction
# 4. Lean Option Position -> Python dict | None
