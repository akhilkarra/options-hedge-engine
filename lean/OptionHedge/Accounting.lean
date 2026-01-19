/-
  Accounting Functions

  Core portfolio accounting: NAV calculation, trade application, cash accrual.
  These functions are intentionally simple in v0.1 and will be proven correct in v0.3-v0.4.
-/

import OptionHedge.Basic
import OptionHedge.Numeric

namespace OptionHedge

/-- Calculate the market value of a single position -/
def Position.value (pos : Position) : Int :=
  pos.quantity * pos.markPrice

/-- Calculate total value of all positions -/
def sumPositionValues (positions : List Position) : Int :=
  positions.foldl (fun acc pos => acc + pos.value) 0

/-- Calculate Net Asset Value (NAV) of portfolio
    NAV = cash + Σ(position values) -/
def calcNAV (p : Portfolio) : Int :=
  p.cash + sumPositionValues p.positions

/-- Apply a single trade to portfolio (simplified for v0.1)
    Updates position quantity and deducts cash -/
def applyTrade (p : Portfolio) (t : Trade) : Portfolio :=
  sorry  -- Implementation in v0.4

/-- Apply multiple trades sequentially -/
def applyTrades (p : Portfolio) (trades : List Trade) : Portfolio :=
  trades.foldl applyTrade p

/-- Accrue interest on cash balance (simplified for v0.1) -/
def accrueInterest (p : Portfolio) (rate : Int) : Portfolio :=
  sorry  -- Implementation in v0.4

end OptionHedge
