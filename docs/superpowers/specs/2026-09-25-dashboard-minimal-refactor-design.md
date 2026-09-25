# Info Display / Dashboard Minimal Refactor Design

## Overview
Refactor the entire Info Display / Dashboard panel in `InfoDisplay.mqh` of the MT5 EA "Yoogi One For All" to be minimal, highly readable, and focused on actionable live trading states and debt tracking.

## Goals & Constraints
1. **Strictly UI Only**: No changes to trading logic, CT/FT entry conditions, DCA rules, Debt calculation, Recovery Chain logic, TP/SL, or state engine.
2. **Remove Unused Sections**:
   - Completely remove Section C (`=== ACTIVE CHAIN ===`) rendering.
   - Completely remove Section D (`=== ENTRY ANALYSIS ===`) rendering.
   - Remove debug items from System Summary (DXY, CT Engine, FT Engine, Active Chains, DCA Mode, Risk/Pair, Dynamic TP).
   - Remove obsolete Pair Monitor columns (`CHAIN`, `CHAIN ID`, `CHAIN POS`, `STATE`, `NEXT GATE`, `P/L`).
3. **Keep Exact Data Semantics**:
   - `Balance`: `AccountInfoDouble(ACCOUNT_BALANCE)`
   - `Virtual Bal`: `AccountInfoDouble(ACCOUNT_BALANCE) + GetTotalSystemDebt()`
   - `Total Debt`: `GetTotalSystemDebt()`
   - `Pair Debt`: `GetSystemDebt(i)`
   - `Score`: `data.displayScoreStr` from `BuildReversalDisplayData`
   - `Type`: Merged `displayMode` + `displayDir` (e.g. `CT BUY`, `FT SELL`)
4. **Authoritative STATUS Mapping Priority**:
   - A. If `GetSystemDebt(i) > 0.001` or `G_Pairs[i].system_recovery_active` => `RECOVERY`
   - B. Else if not Recovery and (`pair_orders > 1` or `G_Pairs[i].chain_position_count > 1`) => `DCA`
   - C. Else if not Recovery/DCA and `pair_orders == 1` => `TRADING`
   - D. Else (no active orders):
     - If `data.displayState == "READY"` or `data.displayNextGate == "ENTRY"` => `READY`
     - Else if `data.displayState == "BLOCKED"` => `LOCKED`
     - Else if `data.displayState == "NO SETUP"` => `NO SETUP`
     - Else => `WAIT`
   - *Technical states like LOCATION, EXHAUSTION, LIQUIDITY, PULLBACK must never appear directly on the dashboard.*
5. **Dimensions & Alignment**:
   - Anchor: `CORNER_LEFT_LOWER`
   - Panel size: Width ~410px (providing generous margin for column labels), Height ~265px
   - Position: `DASH_Y = 250`, `DASH_X = 20`
   - Monospace font: "Consolas", size 10 (labels & values), 11-12 (headers)
