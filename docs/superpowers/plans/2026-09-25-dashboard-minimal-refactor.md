# Minimal Dashboard Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `InfoDisplay.mqh` to display a minimal, clean 3-row System Summary and a 5-column Pair Monitor (PAIR, TYPE, SCORE, STATUS, DEBT) while removing Active Chain, Entry Analysis, and unused debug fields, with zero changes to trading logic.

**Architecture:** Modify `InfoDisplay.mqh` layout tokens, `CreateDisplay()` and `UpdateDisplay()` functions. Keep all underlying state tracking and scanning logic intact so trading engine references and scans remain functional.

**Tech Stack:** MQL5, MetaEditor64 CLI compilation.

---

### Task 1: Update Configuration Tokens & Column Coordinates in `InfoDisplay.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/InfoDisplay.mqh:10-75`

- [ ] **Step 1: Update Panel Dimensions and Anchor Offsets**
  - Adjust `DASH_Y` to `250`
  - Adjust `BACK_W` to `410` (safety margin to avoid any text clipping)
  - Adjust `BACK_H` to `265`
  - Update column offsets:
    - `P_PAIR = 0`
    - `P_TYPE = 65`
    - `P_SCOR = 145`
    - `P_STAT = 220`
    - `P_DEBT = 315`
  - Remove obsolete column tokens: `P_SEP1` through `P_SEP7`, `P_MODE`, `P_DIR`, `P_NEXT`, `P_CHN`, `P_PNL`.

### Task 2: Refactor `CreateDisplay()` in `InfoDisplay.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/InfoDisplay.mqh:80-235`

- [ ] **Step 1: Simplify Section A (System Summary)**
  - Keep only:
    - `Sys_Bal_Lbl`, `Sys_Bal_Val`
    - `Sys_VBal_Lbl`, `Sys_VBal_Val`
    - `Sys_Debt_Lbl`, `Sys_Debt_Val`
  - Remove all other labels in Section A (`Sys_DXY_*`, `Sys_CT_*`, `Sys_FT_*`, `Sys_Chain_*`, `Sys_DCA_*`, `Sys_Risk_*`, `Sys_DynTP_*`).

- [ ] **Step 2: Refactor Section B (Pair Monitor)**
  - Create 5 column headers:
    - `H_Pair` at `x + P_PAIR` ("PAIR")
    - `H_Type` at `x + P_TYPE` ("TYPE")
    - `H_Score` at `x + P_SCOR` ("SCORE")
    - `H_Stat` at `x + P_STAT` ("STATUS")
    - `H_Debt` at `x + P_DEBT` ("DEBT")
  - In loop for 5 pairs:
    - Create `R{i}_Pair`, `R{i}_Type`, `R{i}_Score`, `R{i}_Status`, `R{i}_Debt`.

- [ ] **Step 3: Remove Section C (Active Chain) & Section D (Entry Analysis)**
  - Remove creation of Section C (`SecC_Title`, `Chain_L1`, `Chain_L2`, `Chain_L3`).
  - Remove creation of Section D (`SecD_Title`, `Entry_L1`, `Entry_L2`, `Entry_L3`, `Entry_L4`).
  - Adjust Footer separator and text Y position.

### Task 3: Refactor `UpdateDisplay()` in `InfoDisplay.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/InfoDisplay.mqh:240-496`

- [ ] **Step 1: Update System Summary values**
  - Set `Sys_Bal_Val`, `Sys_VBal_Val`, `Sys_Debt_Val`.
  - Remove updating of removed System Summary labels.

- [ ] **Step 2: Update Pair Monitor values with Authoritative STATUS Priority**
  - For each pair `i`:
    - Retrieve `pair_orders` from open positions scan.
    - Format `sym_short` (e.g. `EURUSD`).
    - Format `TYPE` from `data.displayMode` + `data.displayDir`.
    - Format `SCORE` from `data.displayScoreStr`.
    - Retrieve `pair_debt = GetSystemDebt(i)`.
    - Map `STATUS` using strict priority:
      - Priority A: `pair_debt > 0.001 || G_Pairs[i].system_recovery_active` => `"RECOVERY"`, Color: `clrOrange`
      - Priority B: `pair_orders > 1 || G_Pairs[i].chain_position_count > 1` => `"DCA"`, Color: `clrGold`
      - Priority C: `pair_orders == 1` => `"TRADING"`, Color: `clrDeepSkyBlue`
      - Priority D:
        - `data.displayState == "READY" || data.displayNextGate == "ENTRY"` => `"READY"`, Color: `clrLime`
        - `data.displayState == "BLOCKED"` => `"LOCKED"`, Color: `clrIndianRed`
        - `data.displayState == "NO SETUP"` => `"NO SETUP"`, Color: `clrLightGray`
        - Else => `"WAIT"`, Color: `clrLightGray`
    - Format `DEBT`: `StringFormat("$%.2f", pair_debt)`, Color: `(pair_debt > 0.001 ? clrOrange : clrLightGray)`.
    - Set labels: `R{i}_Pair`, `R{i}_Type`, `R{i}_Score`, `R{i}_Status`, `R{i}_Debt`.

- [ ] **Step 3: Remove Section C and Section D label updates**
  - Delete all `SetLabelText` calls for `SecC_*`, `Chain_*`, `SecD_*`, `Entry_*`.
  - Keep chain scanning and candidate tracking if needed or clean up unused local vars.

### Task 4: Compilation and Verification

- [ ] **Step 1: Compile with MetaEditor64**
  - Run compiler command.
  - Verify 0 errors.

- [ ] **Step 2: Verify Search Cleanliness**
  - Ensure no references to removed labels remain.
  - Check that no trading logic was altered.

- [ ] **Step 3: Backup and Commit**
  - Run `git add .`
  - Commit changes.
