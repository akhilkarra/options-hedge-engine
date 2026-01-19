/-
  Numeric Types with Exact Decimal Arithmetic

  Implements scaled integer approach for financial calculations.
  All monetary amounts use basis points (×10,000) for 4 decimal precision.

  Design Decision (ADR-001):
  - Use Int (scaled) instead of Float (inexact) or Rat (GCD overhead)
  - See DECISIONS.md for full rationale
-/

namespace OptionHedge

/-- Price represented as basis points (×10,000 for 4 decimal places)
    Example: $123.4567 = 1,234,567 basis points -/
structure Price where
  basisPoints : Int
  deriving Repr, BEq

namespace Price

/-- Create Price from integer and fractional parts
    Example: fromParts 123 4567 = $123.4567 -/
def fromParts (intPart : Int) (fracPart : Nat) : Price :=
  ⟨intPart * 10000 + fracPart⟩

/-- Create Price from basis points directly -/
def fromBasisPoints (bp : Int) : Price := ⟨bp⟩

/-- Zero price -/
def zero : Price := ⟨0⟩

/-- Add two prices -/
def add (a b : Price) : Price :=
  ⟨a.basisPoints + b.basisPoints⟩

/-- Subtract two prices -/
def sub (a b : Price) : Price :=
  ⟨a.basisPoints - b.basisPoints⟩

/-- Multiply price by integer quantity -/
def mulInt (p : Price) (q : Int) : Price :=
  ⟨p.basisPoints * q⟩

/-- Multiply two prices (careful with scaling!) -/
def mul (a b : Price) : Price :=
  -- (a × 10⁴) × (b × 10⁴) = result × 10⁸
  -- Divide by 10⁴ to get back to basis points
  ⟨(a.basisPoints * b.basisPoints) / 10000⟩

/-- Check if price is non-negative -/
def isNonNegative (p : Price) : Bool :=
  p.basisPoints ≥ 0

/-- Check if price is positive -/
def isPositive (p : Price) : Bool :=
  p.basisPoints > 0

end Price

/-- General decimal type with 4 decimal places (basis points representation) -/
abbrev Decimal4 := Price

/-- Helper: Convert basis points to human-readable string (for debugging)
    Note: This is for display only, not for computation -/
def Price.toDecimalString (p : Price) : String :=
  let intPart := p.basisPoints / 10000
  let fracPart := (p.basisPoints % 10000).natAbs
  s!"{intPart}.{fracPart}"

-- Notation for prices (optional, for convenience in proofs)
notation "Price.+" => Price.add
notation "Price.-" => Price.sub

end OptionHedge
