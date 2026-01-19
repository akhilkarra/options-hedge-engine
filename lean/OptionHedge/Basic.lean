/-
Copyright (c) 2026 Option Hedge Engine Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Akhil Karra
-/

/-!
# Basic Types

Core data structures for portfolio state representation.

This module defines:
- `Asset`: Asset identifiers
- `Position`: Asset holdings with quantities and prices
- `Portfolio`: Complete portfolio state including cash and positions

These types form the foundation of the verified accounting kernel.
-/

namespace OptionHedge

/-- Asset identifier -/
structure Asset where
  id : String
  deriving Repr, BEq, Hashable

/-- Type alias for asset identifiers -/
def AssetId := String

/-- Position in a single asset -/
structure Position where
  asset : Asset
  quantity : Int      -- Signed: positive = long, negative = short
  markPrice : Int     -- In basis points (price × 10,000)
  deriving Repr

/-- Portfolio state -/
structure Portfolio where
  cash : Int                  -- In cents
  positions : List Position
  accruedInterest : Int      -- In cents
  deriving Repr

end OptionHedge
