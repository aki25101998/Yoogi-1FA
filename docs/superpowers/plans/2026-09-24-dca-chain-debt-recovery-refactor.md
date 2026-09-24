# DCA Chain, Global Sequence, Debt & Recovery Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the entire Chain, DCA Sequencing, Debt tracking, and Recovery system for Yoogi-1FA according to the official specification, completely separating Global DCA Sequence, Active Chain Position Count, Debt, and Recovery State, eliminating all "ENTRY" comments, enforcing max 3 positions per chain with chain-limit closure, continuous lot progression, and strict reset conditions only upon full debt recovery via TP.

**Architecture:** 
- Isolate the 4 core concepts in `Globals.mqh` and `Corelogic.mqh`:
  1. `DCA GLOBAL SEQUENCE` (`ct_dca_sequence`, `ft_dca_sequence`, `dual_dca_sequence`): persists across chain closures and losses; increments with each position; resets to 0 ONLY when recovery TP settles Debt to 0.
  2. `ACTIVE CHAIN POSITION COUNT` (`chain_position_count`): tracks positions in the current active chain (1..3); resets to 0 on chain close; starts at 1 on new chain open.
  3. `DEBT` (`ct_realized_bleed_loss`, etc.): tracks cumulative unpaid losses; increases on chain loss; reduces on chain profit.
  4. `RECOVERY STATE`: `RECOVERY MODE` when Debt > 0; `NORMAL MODE` when Debt == 0.
- Refactor `OpenMasterTrade_Multi`: opens position #1 of the chain as `DCA 1` (normal) or `DCA N` (recovery continuation) without any "ENTRY" comments, using normalized continuous lot progression.
- Refactor `ManageTrendDCA_Multi`: enforces `InpMaxDCAPerChain` (3). When adverse step triggers position #4, immediately logs `[CHAIN-LIMIT]`, does NOT open DCA 4, closes entire active chain, resolves PnL as Debt, and waits for a new entry signal.
- Refactor `CloseAndResolveChain`: distinguishes `MAX_DCA` (loss -> debt accumulation, sequence continues) vs `TP`/`RUNNER` (settlement: if debt reaches 0 -> full recovery reset; if debt > 0 -> partial recovery, sequence continues). Standardizes all required logging formats (`[DCA-OPEN]`, `[CHAIN-LIMIT]`, `[CHAIN-LOSS]`, `[RECOVERY-PROFIT]`, `[RECOVERY-COMPLETE]`, `[RECOVERY-CONTINUE]`).
- Update `Trimming.mqh` and `InfoDisplay.mqh` to align with `chain_position_count`.

**Tech Stack:** MQL5, MetaEditor64 compiler CLI.

---

### Task 1: Update Data Structures and Helper Functions in `Globals.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/Globals.mqh`

- [ ] **Step 1: Update `PairContext` structure**
  - Add `chain_position_count` (standardizing from `chain_dca_count`).
  - Add `chain_start_dca_seq` and `chain_end_dca_seq`.
  - In `InitPairs()`, initialize these to 0 and ensure persistence loading of DCA sequence and Debt is intact.

- [ ] **Step 2: Add Lot Progression & Strategy Accessor functions**
  - Implement `CalculateDCALot(int idx, int dca_seq, double balance)`.
  - Implement `GetStrategyDebt(int idx, string strat)`.
  - Implement `SetStrategyDebt(int idx, string strat, double debt)`.
  - Implement `GetStrategyDCASeq(int idx, string strat)`.
  - Implement `SetStrategyDCASeq(int idx, string strat, int seq)`.
  - Implement `GetStrategyRecLvl(int idx, string strat)`.
  - Implement `SetStrategyRecLvl(int idx, string strat, int lvl)`.
  - Implement `IsStrategyInRecovery(int idx, string strat)`.
  - Add persistence name helpers `GetVarName_StartSeq` and `GetVarName_EndSeq`.

- [ ] **Step 3: Compile to verify `Globals.mqh` syntax**

---

### Task 2: Refactor Persistence and Chain Management in `Corelogic.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/Corelogic.mqh`

- [ ] **Step 1: Refactor `SavePersistentState` and `SaveChainState_Multi`**
  - Separate permanent state persistence (Debt, RecLvl, DCASeq) from active chain persistence (`chain_position_count`, `chain_step_pips`, `locked_balance`, `chain_start_dca_seq`, `chain_end_dca_seq`).
  - Ensure persistent variables are saved regardless of whether `active_chain_id` is 0.

- [ ] **Step 2: Refactor `LoadChainState_Multi` and `ClearChainState_Multi`**
  - Load `chain_position_count`, `chain_start_dca_seq`, `chain_end_dca_seq`.
  - Failsafe count open positions from market if variable missing.
  - In `ClearChainState_Multi`, reset chain-specific fields to 0 without touching persistent Debt and DCASeq.

- [ ] **Step 3: Refactor `OpenMasterTrade_Multi`**
  - Remove comment `"ENTRY"`. Set comment to `strat + " | DCA " + IntegerToString(next_dca_seq)`.
  - If in Normal Mode (Debt == 0): `next_dca_seq = 1`.
  - If in Recovery Mode (Debt > 0): `next_dca_seq = current_dca_seq + 1`.
  - Calculate lot using `CalculateDCALot(idx, next_dca_seq, lot_calculation_bal)`.
  - Set `chain_position_count = 1`, `chain_start_dca_seq = next_dca_seq`, `chain_end_dca_seq = next_dca_seq`.
  - Update strategy DCA sequence `SetStrategyDCASeq(idx, strat, next_dca_seq)`.
  - Output standardized log `[DCA-OPEN]`.

---

### Task 3: Refactor DCA Management and Limit Enforcement in `Corelogic.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/Corelogic.mqh`

- [ ] **Step 1: Refactor `ManageTrendDCA_Multi`**
  - Detect chain limit: `if(G_Pairs[idx].chain_position_count >= InpMaxDCAPerChain)`.
  - When limit reached upon step condition:
    - Log `[CHAIN-LIMIT]` with `DCA_SEQUENCE`, `CHAIN_POSITION`, `MAX_CHAIN_POSITIONS`, `NEXT_DCA_SEQUENCE`, `ACTION=CLOSE_CHAIN`.
    - Call `CloseAndResolveChain(idx, "MAX_DCA")`.
    - Return immediately. Do NOT open DCA 4!
  - If limit not reached:
    - `next_chain_pos = chain_position_count + 1`.
    - `next_dca_seq = current_dca_seq + 1`.
    - Calculate lot using `NormalizeLot(sym, last_lot * InpHeSoLot)`.
    - Set comment `strat + " | DCA " + IntegerToString(next_dca_seq)`.
    - Open order. On success, update `chain_position_count`, `chain_end_dca_seq`, and `SetStrategyDCASeq`.
    - Output standardized log `[DCA-OPEN]`.

---

### Task 4: Refactor Chain Settlement & Resolution in `Corelogic.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/Corelogic.mqh`

- [ ] **Step 1: Refactor `CloseAndResolveChain`**
  - Handle `reason == "MAX_DCA"`:
    - If `pnl < 0`:
      - `net_loss = MathAbs(pnl)`.
      - `debt_after = debt_before + net_loss`.
      - `SetStrategyDebt(idx, strat, debt_after)`.
      - Increment recovery level.
      - Log `[CHAIN-LOSS]` with `CHAIN_ID`, `DCA_FROM`, `DCA_TO`, `CHAIN_RESULT`, `DEBT_BEFORE`, `DEBT_ADDED`, `DEBT_AFTER`, `MODE=RECOVERY`.
      - Global DCA sequence stays at `chain_end_dca_seq` (does NOT reset).
    - If `pnl >= 0`:
      - `debt_after = MathMax(0.0, debt_before - pnl)`.
      - `SetStrategyDebt(idx, strat, debt_after)`.
      - Mode remains RECOVERY, DCA sequence does NOT reset.
  - Handle `reason == "TP" || reason == "RUNNER"`:
    - If `debt_before == 0.0`:
      - Normal TP.
      - Reset `SetStrategyDCASeq(idx, strat, 0)`.
    - If `debt_before > 0.0`:
      - Recovery TP!
      - `debt_after = MathMax(0.0, debt_before - pnl)`.
      - Log `[RECOVERY-PROFIT]`.
      - If `debt_after == 0.0`:
        - Full recovery complete!
        - `SetStrategyDebt(idx, strat, 0.0)`.
        - `SetStrategyRecLvl(idx, strat, 0)`.
        - `SetStrategyDCASeq(idx, strat, 0)`.
        - Log `[RECOVERY-COMPLETE]`.
      - If `debt_after > 0.0`:
        - Partial recovery.
        - `SetStrategyDebt(idx, strat, debt_after)`.
        - DCA sequence does NOT reset.
        - Log `[RECOVERY-CONTINUE]`.
  - Save persistent state and clear chain state.

- [ ] **Step 2: Update `ResolveClosedChainFromHistory`**
  - Align history deal resolution logic with the same recovery completion conditions.

---

### Task 5: Update `Trimming.mqh` and `InfoDisplay.mqh`

**Files:**
- Modify: `d:/Project/yoogi 1fa/Trimming.mqh`
- Modify: `d:/Project/yoogi 1fa/InfoDisplay.mqh`

- [ ] **Step 1: Update `Trimming.mqh`**
  - Replace `chain_dca_count` with `chain_position_count`.

- [ ] **Step 2: Update `InfoDisplay.mqh`**
  - Replace `chain_dca_count` with `chain_position_count`.
  - Display `Chain Pos`, `DCA Seq`, `Debt`, `Mode` cleanly in Section C.

---

### Task 6: Comprehensive Verification & Acceptance Testing

**Files:**
- Verify: Full compilation of `Yoogi 1FA.mq5` with 0 errors.
- Verify: Acceptance Tests 1 through 8 from specification.
- Git commit and sync.
