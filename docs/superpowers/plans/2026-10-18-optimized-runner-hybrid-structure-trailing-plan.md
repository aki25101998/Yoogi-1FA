# Optimized Runner Engine: Hybrid Structure & Multi-Tier Trailing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Giải phóng toàn bộ tiềm năng gồng lời của 50% khối lượng Runner cho Trend-Following (FT), cho phép lệnh sống sót qua các đợt rung lắc sóng nhỏ M5 để gồng trọn con sóng dài H1/H4 (50 - 85 pips) thông qua cơ chế 3 giai đoạn: Vùng đệm thở tự do (15-30 pips), Bám cấu trúc Swing Low/High M15 (30-55 pips), và Chốt lời mở rộng TP2 tại cản H1 (50-85 pips).

**Architecture:** 
1. `Globals.mqh` & `DynamicExitEngine.mqh`: Bổ sung tham số cấu hình Runner (`TF_RUNNER_BREATHE_PIPS = 30.0`, `TF_RUNNER_TP2_MIN_PIPS = 50.0`, `TF_RUNNER_TP2_MAX_PIPS = 85.0`), mở rộng `TradeProfile` lưu trữ `runner_tp2_price`, `runner_tp2_pips`, `runner_stage` cùng cơ chế lưu/đọc qua GlobalVariables.
2. `DynamicExitEngine.mqh`: Hiện thực hóa động cơ tính cản mục tiêu H1 (`CalcH1TargetTP2`) và động cơ dò đáy/đỉnh cấu trúc M15 (`CalcM15SwingTrailingStop`). Nâng cấp `UpdateRunnerTrail` để chuyển đổi mượt mà giữa Giai đoạn 1 (Breathing SL tại Entry + 3 pips) và Giai đoạn 2 (Structure Trailing).
3. `Corelogic.mqh`: Tích hợp kiểm tra mục tiêu `RUNNER_TP2` trong vòng lặp thoát lệnh và hạch toán khấu trừ nợ trong `ResolveClosedChainFromHistory`.

**Tech Stack:** MQL5, MetaTrader 5 Platform, MetaEditor64 CLI, Git.

---

## File Structure & Responsibilities

| File | Hành động | Trách nhiệm |
|---|---|---|
| `Globals.mqh` | **Modify** | Bổ sung các hằng số cấu hình Runner tối ưu (`TF_RUNNER_BREATHE_PIPS`, `TF_RUNNER_TP2_MIN_PIPS`, `TF_RUNNER_TP2_MAX_PIPS`, `TF_RUNNER_SWING_BUFFER_ATR`, `TF_RUNNER_SWING_LOOKBACK`). |
| `DynamicExitEngine.mqh` | **Modify** | Cập nhật struct `TradeProfile`, viết hàm `CalcH1TargetTP2`, `CalcM15SwingTrailingStop`, nâng cấp `ExecuteFTPartialClose` và `UpdateRunnerTrail`. |
| `Corelogic.mqh` | **Modify** | Tích hợp kiểm tra `tp2_hit` trong `ManagePairs`, bổ sung lý do thoát lệnh `RUNNER_TP2` vào `CloseAndResolveChain` và `ResolveClosedChainFromHistory`. |

---

## Tasks

### Task 1: Cấu Hình Tham Số & Struct Trong `Globals.mqh` & `DynamicExitEngine.mqh`

**Files:**
- Modify: `d:\Project\yoogi 1fa\Globals.mqh`
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh`

- [ ] **Step 1: Thêm hằng số cấu hình Runner vào `Globals.mqh`**
  ```mql5
  // ==================================================================
  // OPTIMIZED RUNNER CONFIGURATION (Hardcoded)
  // ==================================================================
  const double TF_RUNNER_BREATHE_PIPS     = 30.0;  // Vùng đệm thở tự do trước khi bám Swing (30 pips)
  const double TF_RUNNER_TP2_MIN_PIPS     = 50.0;  // Sàn chốt lời TP2 tối thiểu cho Runner (50 pips)
  const double TF_RUNNER_TP2_MAX_PIPS     = 85.0;  // Trần chốt lời TP2 tối đa cho Runner (85 pips)
  const double TF_RUNNER_SWING_BUFFER_ATR = 0.5;   // Khoảng đệm an toàn dưới/trên Swing M15 (0.5x ATR M15)
  const int    TF_RUNNER_SWING_LOOKBACK   = 35;    // Số nến M15 dùng để quét tìm đỉnh/đáy swing
  ```

- [ ] **Step 2: Mở rộng `TradeProfile` trong `DynamicExitEngine.mqh`**
  - Thêm `double runner_tp2_price;`
  - Thêm `double runner_tp2_pips;`
  - Thêm `int runner_stage;` (1 = Breathing, 2 = Structure Trailing, 3 = Harvested)
  - Khởi tạo giá trị mặc định trong `ResetTradeProfile`.

- [ ] **Step 3: Cập nhật `SaveTradeProfile` và `LoadTradeProfile` trong `DynamicExitEngine.mqh`**
  - Lưu và đọc các biến GlobalVariables:
    - `Yoogi_RunnerTP2_{symbol}_{chain_id}`
    - `Yoogi_RunnerTP2Pips_{symbol}_{chain_id}`
    - `Yoogi_RunnerStage_{symbol}_{chain_id}`

---

### Task 2: Hiện Thực Thuật Toán Tính Cản H1 (`CalcH1TargetTP2`) & Dò Swing M15 (`CalcM15SwingTrailingStop`)

**Files:**
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh`

- [ ] **Step 1: Viết hàm `CalcH1TargetTP2(int idx, int direction, double entry)`**
  - Quét 40 nến H1 gần nhất tìm cản kỹ thuật tiếp theo:
    - BUY: Tìm Swing High H1 gần nhất nằm trên Entry từ 50 đến 85 pips.
    - SELL: Tìm Swing Low H1 gần nhất nằm dưới Entry từ 50 đến 85 pips.
  - Kiểm tra thêm cản động EMA50 H1 nếu có.
  - Kẹp trong `[TF_RUNNER_TP2_MIN_PIPS, TF_RUNNER_TP2_MAX_PIPS]`. Nếu không có cản cụ thể, dùng mặc định `60.0 pips`.
  - Trả về khoảng cách pips mục tiêu.

- [ ] **Step 2: Viết hàm `CalcM15SwingTrailingStop(int idx, int direction)`**
  - Sử dụng `ReadHighLow_Generic` đọc 35 nến M15 gần nhất.
  - BUY (tìm Higher Lows):
    - Dò đáy Swing Low gần nhất hợp lệ (`left = 3, right = 1`) nằm trên `Entry + 5 pips`.
    - Trừ đi khoảng đệm an toàn $0.5 \times \text{ATR}_{\text{M15}}$.
  - SELL (tìm Lower Highs):
    - Dò đỉnh Swing High gần nhất hợp lệ nằm dưới `Entry - 5 pips`.
    - Cộng thêm khoảng đệm an toàn $0.5 \times \text{ATR}_{\text{M15}}$.
  - Trả về candidate stop price (hoặc 0.0 nếu chưa tìm thấy).

---

### Task 3: Nâng Cấp Động Cơ Runner Trong `DynamicExitEngine.mqh`

**Files:**
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh`

- [ ] **Step 1: Cập nhật `ExecuteFTPartialClose`**
  - Tính toán và lưu `runner_tp2_pips = CalcH1TargetTP2(idx, dir, entry);`
  - Đặt `runner_tp2_price`:
    - BUY: `entry + PipsToPrice(idx, runner_tp2_pips);`
    - SELL: `entry - PipsToPrice(idx, runner_tp2_pips);`
  - Đặt `runner_stage = 1;` (Giai đoạn Breathing Buffer).
  - Khóa Stop ban đầu cố định tại `Entry + 3 pips`.

- [ ] **Step 2: Cập nhật `UpdateRunnerTrail(int idx)`**
  - Tính lợi nhuận hiện tại `profit_pips`.
  - Nếu `profit_pips < TF_RUNNER_BREATHE_PIPS` (dưới 30 pips):
    - Đảm bảo `runner_stage = 1`.
    - Giữ nguyên mức Stop an toàn tại `Entry + 3 pips`.
  - Nếu `profit_pips >= TF_RUNNER_BREATHE_PIPS` (từ 30 pips trở lên):
    - Chuyển `runner_stage = 2`.
    - Gọi `candidate = CalcM15SwingTrailingStop(idx, dir);`
    - Nếu `candidate > 0`: Tịnh tiến `runner_trail_price` theo nguyên tắc một chiều (Ratchet: chỉ nâng lên đối với BUY, chỉ hạ xuống đối với SELL).

---

### Task 4: Tích Hợp Thoát Lệnh Runner TP2 & Hạch Toán Nợ Trong `Corelogic.mqh`

**Files:**
- Modify: `d:\Project\yoogi 1fa\Corelogic.mqh`

- [ ] **Step 1: Tích hợp kiểm tra chạm `runner_tp2_price` trong `ManagePairs()`**
  - Tại đoạn kiểm tra Runner:
    - Nếu `basket_dir == 1 && current_price >= G_TradeProfile[i].runner_tp2_price && G_TradeProfile[i].runner_tp2_price > 0.0`
    - Hoặc `basket_dir == -1 && current_price <= G_TradeProfile[i].runner_tp2_price && G_TradeProfile[i].runner_tp2_price > 0.0`
    - Gọi `CloseAndResolveChain(i, "RUNNER_TP2");`
    - In log chi tiết `[RUNNER-TP2-HIT]`.

- [ ] **Step 2: Cập nhật `CloseAndResolveChain` & `ResolveClosedChainFromHistory`**
  - Thêm `reason == "RUNNER_TP2"` vào nhánh xử lý đóng có lãi (tương đương `RUNNER` và `TP`).
  - Gán pending reason value cho `RUNNER_TP2` (ví dụ `5.0`).
  - Khấu trừ toàn bộ lợi nhuận thực tế đạt được vào `System Debt`.

---

### Task 5: Biên Dịch Bằng MetaEditor64 CLI & Kiểm Tra Cú Pháp

- [ ] **Step 1: Xóa log cũ và biên dịch**
  ```powershell
  Remove-Item "d:\Project\yoogi 1fa\compile.log" -Force -ErrorAction SilentlyContinue
  cmd.exe /c "`"C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe`" /compile:`"d:\Project\yoogi 1fa\Yoogi 1FA.mq5`" /log:`"d:\Project\yoogi 1fa\compile.log`""
  ```
- [ ] **Step 2: Kiểm tra kết quả biên dịch**
  - Xác nhận `Result: 0 errors, 0 warnings`.
  - Xác nhận `Yoogi 1FA.ex5` được cập nhật timestamp mới.

---

### Task 6: Commit & Push Lên GitHub

- [ ] **Step 1: Git add, commit và push**
  ```powershell
  git add .
  git commit -m "feat(runner): implement hybrid structure trailing and extended H1 TP2 harvest"
  git push origin master
  ```
