/-
Copyright (c) 2026 Option Hedge Engine Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Akhil Karra
-/

import OptionHedge.Basic

/-!
# Option Hedge Engine

Formally verified options portfolio accounting and hedging system.

This library provides:
- Exact decimal arithmetic using scaled integers
- Portfolio state representation and NAV calculation
- Formally proven invariants (NAV identity, self-financing, conservation)
- Certificate-based verification of state transitions

## Main Components

- `OptionHedge.Basic`: Core data structures
- `OptionHedge.Numeric`: Exact decimal types (TODO: v0.2)
- `OptionHedge.Accounting`: Portfolio operations (TODO: v0.3)
- `OptionHedge.Certificate`: JSON certificate parsing and verification (TODO: v0.6)
-/
