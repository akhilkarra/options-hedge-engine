"""Test FFI bindings to Lean accounting kernel."""

import pytest

from hedge_engine.ffi import (
    calc_nav,
    get_position,
    initialize_lean,
    position_value,
    sum_position_values,
)

# -- Lean runtime --


def test_lean_runtime_initialization():
    """Lean runtime initializes without error."""
    initialize_lean()


# -- position_value --


def test_position_value_long():
    """100 shares at $50.00 (500,000 bp) = $5,000.00 (50,000,000 bp)."""
    assert position_value(100, 500000) == 50_000_000


def test_position_value_short():
    """-50 shares at $180.00 (1,800,000 bp) = -$9,000.00 (-90,000,000 bp)."""
    assert position_value(-50, 1800000) == -90_000_000


def test_position_value_zero_quantity():
    """Zero quantity always yields zero value."""
    assert position_value(0, 500000) == 0


# -- sum_position_values --


def test_sum_position_values_empty():
    """Empty position list sums to zero."""
    assert sum_position_values([]) == 0


def test_sum_position_values_multiple():
    """SPY + AAPL position values."""
    positions = [
        {"quantity": 100, "mark_price": 500000},
        {"quantity": 50, "mark_price": 1800000},
    ]
    assert sum_position_values(positions) == 140_000_000


# -- calc_nav --


def test_calc_nav_empty_portfolio():
    """NAV of empty portfolio equals cash."""
    assert calc_nav(cash=1_000_000, positions=[]) == 1_000_000


def test_calc_nav_with_positions():
    """NAV = cash + sum of position values."""
    positions = [
        {"asset_id": "SPY", "quantity": 100, "mark_price": 500000},
        {"asset_id": "AAPL", "quantity": 50, "mark_price": 1800000},
    ]
    assert calc_nav(cash=1_000_000, positions=positions) == 141_000_000


# -- get_position --


def test_get_position_found():
    """Lookup returns matching position."""
    positions = [
        {"asset_id": "SPY", "quantity": 100, "mark_price": 500000},
        {"asset_id": "AAPL", "quantity": 50, "mark_price": 1800000},
    ]
    result = get_position(positions, "SPY")
    assert result is not None
    assert result["asset_id"] == "SPY"
    assert result["quantity"] == 100


def test_get_position_not_found():
    """Lookup returns None for missing asset."""
    positions = [
        {"asset_id": "SPY", "quantity": 100, "mark_price": 500000},
    ]
    assert get_position(positions, "TSLA") is None


def test_get_position_empty():
    """Lookup in empty list returns None."""
    assert get_position([], "SPY") is None


# -- Future FFI tests --


@pytest.mark.skip(reason="Cython compilation not yet implemented")
def test_calc_nav_via_lean_ffi():
    """Future: Test actual Lean FFI after Cython extension is compiled."""
