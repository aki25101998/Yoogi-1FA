# Capital Management & Recovery Engine Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Loại bỏ hoàn toàn cơ chế nhồi lot Martingale lũy kế xuyên chuỗi (chống phình lot cấp số nhân), khống chế trần Recovery TP theo Available Space (tối đa 60 pips) kết hợp cơ chế trả nợ trừ dần (Amortization), và bổ sung cơ chế khóa hòa vốn (Break-Even) khi đạt Natural TP để ngăn chặn tình trạng lệnh đang lãi biến thành lỗ dính chuỗi DCA. Đồng thời tạo tệp backup `LegacyRecoveryMartingale.mqh` để lưu giữ nguyên vẹn logic cũ phục vụ rollback khi cần.

**Architecture:** 
1. **Tách & Backup Legacy Martingale**: Trích xuất logic tăng lot theo Global DCA Sequence cũ sang file dự phòng `LegacyRecoveryMartingale.mqh`.
2. **Per-Chain Lot Sizing (Không lũy kế xuyên chuỗi)**: Mọi chuỗi mới (kể cả Recovery) mở lệnh Master bằng Base Lot (`dca_seq = 1` hoặc hệ số cố định `1.0x..1.3x` 1 lần duy nhất). Chuỗi nội bộ chỉ DCA tối đa 3 vị thế. Khoản nợ được lưu độc lập và gỡ dần qua nhiều chuỗi thắng.
3. **Capped Recovery TP & Amortization**: `GetBasketTPPrice()` khống chế khoảng cách TP không vượt quá 85% Available Space và không vượt quá 60 pips. Lợi nhuận thực tế kiếm được khi chốt lời sẽ được trừ thẳng vào `system_debt` cho đến khi hết nợ.
4. **Break-Even Protection**: Khi giá thị trường chạm mốc `Natural TP` (30–40 pips) mà chưa tới Recovery TP, kích hoạt chế độ Break-Even (Entry + 2 pips). Nếu thị trường đảo chiều, lệnh đóng hòa vốn có lãi nhẹ, bảo toàn 100% tài khoản.

**Tech Stack:** MQL5, MetaTrader 5, Exness Standard/Pro ECN Broker, GlobalVariables Persistence, MetaEditor64 CLI.

---

## File Structure & Responsibilities

| File | Hành động | Trách nhiệm |
|---|---|---|
| `LegacyRecoveryMartingale.mqh` | **Create** | Lưu giữ nguyên vẹn 100% logic tăng lot Martingale lũy kế xuyên chuỗi cũ làm phương án dự phòng (backup/rollback). |
| `Globals.mqh` | **Modify** | Bổ sung các hằng số trần TP (`InpRecoveryTP_MaxPips = 60`), Break-Even offset (`InpBreakEven_OffsetPips = 2.0`), và cập nhật accessor `CalculateDCALot`. |
| `DynamicExitEngine.mqh` | **Modify** | Cập nhật struct `TradeProfile` thêm cờ `be_active`, `be_price`; khống chế trần khoảng cách TP trong `GetBasketTPPrice()`; bổ sung hàm kiểm tra kích hoạt Break-Even. |
| `Corelogic.mqh` | **Modify** | Cập nhật `OpenMasterTrade_Multi` để reset lot chuỗi mới về Base Lot (không dùng sequence lũy kế cũ); tích hợp xử lý Break-Even exit trong `ManagePairs()`; cập nhật hạch toán trả nợ trừ dần trong `ResolveClosedChainFromHistory()`. |
| `CONSTITUTION.md` | **Modify** | Cập nhật Điều 7, 8, 9 của Hiến pháp hệ thống để đồng bộ với nguyên lý: Per-Chain Lot Sizing, Capped Recovery TP, Amortization, và Break-Even Protection. |

---

## Tasks

### Task 1: Tạo tệp backup `LegacyRecoveryMartingale.mqh`

**Files:**
- Create: `d:\Project\yoogi 1fa\LegacyRecoveryMartingale.mqh`

- [ ] **Step 1: Tạo tệp `LegacyRecoveryMartingale.mqh` chứa toàn bộ hàm và logic Martingale cũ**
  - Đóng gói hàm `CalculateDCALot_Legacy(int idx, int dca_seq, double balance)`.
  - Đóng gói logic chuyển tiếp sequence cũ `GetNextMasterDCASeq_Legacy(bool is_recovery, int current_dca_seq)`.
  - Viết tài liệu giải thích chi tiết cơ chế hoạt động cũ (Sequence tăng liên tục 1..18, lot phình to từ 0.07 lên 2.20 lot) và hướng dẫn cách hoàn tác nếu người dùng muốn khôi phục.

- [ ] **Step 2: Biên dịch thử nghiệm để kiểm tra cú pháp**
  - Chạy lệnh compile CLI để xác nhận tệp `.mqh` mới độc lập, không gây lỗi cú pháp.

- [ ] **Step 3: Commit Git**
  - `git add LegacyRecoveryMartingale.mqh`
  - `git commit -m "feat(backup): create LegacyRecoveryMartingale.mqh preserving original cross-chain martingale logic"`

---

### Task 2: Phá bỏ Martingale xuyên chuỗi & Cố định kích thước Lot chuỗi mới

**Files:**
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:1107-1130`
- Modify: `d:\Project\yoogi 1fa\Corelogic.mqh:800-840, 950-990`

- [ ] **Step 1: Cập nhật hàm tính Lot trong `Globals.mqh`**
  - Giữ nguyên `CalculateAutoLot(idx, balance)` tính Base Lot dựa trên % rủi ro và Divisor từng cặp.
  - Sửa `CalculateDCALot(idx, dca_seq, balance)`:
    * Giới hạn `dca_seq` trong khoảng `[1, InpMaxDCAPerChain]`.
    * Chuỗi nội bộ chỉ nhân tối đa 3 lần: DCA 1 = BaseLot, DCA 2 = BaseLot * 1.3, DCA 3 = DCA 2 * 1.3.
    * Tuyệt đối không cho phép `dca_seq` vượt quá 3 (chặn cứng trần lot).

- [ ] **Step 2: Cập nhật `OpenMasterTrade_Multi` trong `Corelogic.mqh`**
  - Khi mở lệnh Master chuỗi mới:
    * Lệnh Master **LUÔN LUÔN mở với `next_dca_seq = 1`** (tương đương Base Lot `CalculateAutoLot()`).
    * Nếu tài khoản đang có `Debt > 0` (Recovery mode): Lệnh Master vẫn mở với Base Lot (để bảo vệ vốn tối đa khi tài khoản đang âm), hoặc có thể áp dụng multiplier cố định nhẹ 1 lần duy nhất ($1.0 \times$).
    * Gán `G_Pairs[idx].chain_position_count = 1`.
    * Gán `G_Pairs[idx].chain_start_dca_seq = 1`.
    * Gán `G_Pairs[idx].chain_end_dca_seq = 1`.
    * Loại bỏ hoàn toàn dòng lệnh: `next_dca_seq = current_dca_seq + 1;` (nút thắt gây phình lot).

- [ ] **Step 3: Cập nhật `ManageTrendDCA_Multi` trong `Corelogic.mqh`**
  - Chuỗi nội bộ quản lý từ `cur_pos_count = 1` lên tối đa `InpMaxDCAPerChain = 3`.
  - DCA 1 = `NormalizeLot(last_lot * 1.3)`.
  - DCA 2 = `NormalizeLot(last_lot * 1.3)`.
  - Khi chạm lệnh thứ 4: Ngắt chuỗi `MAX_DCA`, không mở thêm.

- [ ] **Step 4: Biên dịch kiểm tra lỗi**
  - Chạy MetaEditor64 CLI, đảm bảo `0 errors, 0 warnings`.

- [ ] **Step 5: Commit Git**
  - `git add Globals.mqh Corelogic.mqh`
  - `git commit -m "fix(capital): eliminate cross-chain martingale, enforce per-chain base lot reset"`

---

### Task 3: Khống chế trần Recovery TP & Cơ chế Trả nợ trừ dần (Amortization)

**Files:**
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:35-50`
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh:915-1040`
- Modify: `d:\Project\yoogi 1fa\Corelogic.mqh:630-675`

- [ ] **Step 1: Khai báo hằng số trần Recovery TP trong `Globals.mqh`**
  - `const double InpRecoveryTP_MaxPips = 60.0;` // Trần khoảng cách TP tối đa khi gỡ nợ
  - `const double InpRecoverySpaceRatio = 0.85;` // Tỷ lệ an toàn so với Available Space cản kỹ thuật

- [ ] **Step 2: Cập nhật `GetBasketTPPrice()` trong `DynamicExitEngine.mqh`**
  - Tính toán `req_distance` để gỡ nợ như hiện tại.
  - Thêm chốt chặn ép trần:
    ```mql5
    double avail_space_pips = G_TradeProfile[idx].available_space_pips;
    if(avail_space_pips <= 0.0) avail_space_pips = CalcAvailableSpace(idx);
    
    // Trần 1: Giới hạn theo khoảng trống cản kỹ thuật (Available Space * 0.85)
    double space_cap_pips = (avail_space_pips > 10.0) ? (avail_space_pips * InpRecoverySpaceRatio) : InpRecoveryTP_MaxPips;
    
    // Trần 2: Giới hạn trần cứng tuyệt đối (60 pips)
    double effective_max_tp_pips = MathMin(InpRecoveryTP_MaxPips, space_cap_pips);
    
    // Khoảng cách TP sau khi kẹp trần
    double max_tp_distance = PipsToPrice(idx, effective_max_tp_pips);
    double final_distance = MathMin(req_distance, max_tp_distance);
    
    // Đảm bảo tối thiểu bằng natural_distance (nếu natural_distance nằm trong giới hạn)
    if(final_distance < natural_distance && natural_distance <= max_tp_distance)
       final_distance = natural_distance;
    ```
  - Thay thế cảnh báo vô dụng thành log thông báo rõ: `[RECOVERY-TP-CAPPED] Required=%.1f pips -> Capped to=%.1f pips (AvailSpace=%.1f)`.

- [ ] **Step 3: Cập nhật `ResolveClosedChainFromHistory()` trong `Corelogic.mqh`**
  - Khi chuỗi chốt lời thành công bằng TP:
    * Lấy toàn bộ số tiền lãi ròng thực tế kiếm được (`realized_pnl`).
    * Trừ thẳng vào `system_debt`:
      ```mql5
      double debt_reduction = MathMin(debt_before, realized_pnl);
      double debt_after = debt_before - debt_reduction;
      SetSystemDebt(idx, debt_after);
      ```
    * Nếu `debt_after <= 0.001`: Đánh dấu `Full Recovery`, reset `system_recovery_level = 0`, `system_debt = 0`.
    * Nếu `debt_after > 0`: Tiếp tục trạng thái Recovery cho các chuỗi sau gỡ tiếp phần còn lại (Amortization).
    * Ghi log cấu trúc rõ ràng: `RealizedProfit=%.2f | DebtBefore=%.2f | DebtReduced=%.2f | DebtRemaining=%.2f`.

- [ ] **Step 4: Biên dịch kiểm tra lỗi**
  - Chạy MetaEditor64 CLI, đảm bảo `0 errors, 0 warnings`.

- [ ] **Step 5: Commit Git**
  - `git add Globals.mqh DynamicExitEngine.mqh Corelogic.mqh`
  - `git commit -m "feat(exit): cap recovery TP to available space and 60 pips with amortization accounting"`

---

### Task 4: Triển khai Cơ chế Khóa hòa vốn (Break-Even Protection)

**Files:**
- Modify: `d:\Project\yoogi 1fa\Globals.mqh`
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh`
- Modify: `d:\Project\yoogi 1fa\Corelogic.mqh`

- [ ] **Step 1: Khai báo tham số Break-Even trong `Globals.mqh`**
  - `const bool   InpEnableBreakEven     = true;`  // Bật/tắt bảo vệ hòa vốn
  - `const double InpBreakEven_TriggerRatio = 0.80;` // Tỷ lệ đạt Natural TP để kích hoạt BE (80%)
  - `const double InpBreakEven_OffsetPips   = 2.0;`  // Khóa lãi tối thiểu +2 pips trên giá vào lệnh

- [ ] **Step 2: Thêm trường Break-Even vào struct `TradeProfile` trong `DynamicExitEngine.mqh`**
  - `bool   be_active;`        // Đã kích hoạt khóa hòa vốn chưa
  - `double be_trigger_pips;`  // Ngưỡng pips để kích hoạt
  - `double be_stop_price;`    // Mức giá Stop Loss hòa vốn (Entry + 2 pips)
  - Khởi tạo giá trị mặc định trong `InitTradeProfile()` và reset trong `ResetTradeProfile()`.
  - Lưu và nạp trạng thái BE qua `SaveTradeProfile()` và `LoadTradeProfile()`.

- [ ] **Step 3: Viết hàm kiểm tra và kích hoạt Break-Even trong `DynamicExitEngine.mqh`**
  - Hàm `CheckAndActivateBreakEven(int idx, double avg_entry, int direction, double current_price)`:
    * Tính khoảng cách giá đã chạy được theo hướng có lợi.
    * Nếu khoảng cách $\ge \text{Natural TP} \times \text{InpBreakEven\_TriggerRatio}$:
      * Đặt `be_active = true`.
      * Đặt `be_stop_price = (direction == 1) ? avg_entry + PipsToPrice(idx, InpBreakEven_OffsetPips) : avg_entry - PipsToPrice(idx, InpBreakEven_OffsetPips)`.
      * Log `[BREAK-EVEN-ACTIVATED]`.

- [ ] **Step 4: Tích hợp thoát lệnh Break-Even vào `ManagePairs()` trong `Corelogic.mqh`**
  - Trong vòng lặp quản lý cặp đang có lệnh:
    * Gọi `CheckAndActivateBreakEven()`.
    * Nếu `G_TradeProfile[i].be_active == true`:
      * Kiểm tra xem giá hiện tại có chạm hoặc phá qua `be_stop_price` theo hướng ngược lại hay không:
        * Với BUY: `current_price <= be_stop_price`
        * Với SELL: `current_price >= be_stop_price`
      * Nếu chạm: Gọi `CloseAndResolveChain(i, "BREAK_EVEN")`.
  - Trong `ResolveClosedChainFromHistory()`: Xử lý lý do `"BREAK_EVEN"` an toàn như một lệnh đóng có lời nhẹ.

- [ ] **Step 5: Biên dịch kiểm tra lỗi**
  - Chạy MetaEditor64 CLI, đảm bảo `0 errors, 0 warnings`.

- [ ] **Step 6: Commit Git**
  - `git add Globals.mqh DynamicExitEngine.mqh Corelogic.mqh`
  - `git commit -m "feat(risk): implement Break-Even protection at Natural TP trigger"`

---

### Task 5: Cập nhật Hiến pháp (CONSTITUTION.md), Xác minh toàn diện & Backtest Test

**Files:**
- Modify: `d:\Project\yoogi 1fa\CONSTITUTION.md`

- [ ] **Step 1: Cập nhật `CONSTITUTION.md`**
  - Điều 7 (Quản lý vốn): Ghi rõ quy định Per-Chain Lot Sizing, loại bỏ hoàn toàn cơ chế tăng lot lũy kế xuyên chuỗi; quy định lệnh Master chuỗi mới luôn bắt đầu từ Base Lot.
  - Điều 8 (Dynamic Exit Engine): Bổ sung quy định trần Recovery TP (Max 60 pips và $\le 85\%$ Available Space) cùng cơ chế Break-Even Protection.
  - Điều 9 (Debt & Recovery): Bổ sung cơ chế Trả nợ trừ dần (Amortization) qua nhiều chuỗi thắng thay vì tất tay ở 1 chuỗi.

- [ ] **Step 2: Biên dịch sạch toàn bộ dự án**
  - Chạy `MetaEditor64 CLI`.
  - Kiểm tra kết quả: `0 errors, 0 warnings`.

- [ ] **Step 3: Chạy test kiểm chứng trên MT5 Strategy Tester (khoảng thời gian 01/01/2023 - 31/03/2023)**
  - Xác nhận rằng tại giai đoạn tháng 1-3/2023 (nơi trước đây EURGBP bị cháy tài khoản), hệ thống:
    * Không còn mở các lệnh 1.0, 1.69 hay 2.20 lots.
    * Không còn bị cảnh báo `REQUIRED_TP = 136.8 pips`.
    * Vốn được bảo toàn an toàn, không còn hiện tượng Stop Out.

- [ ] **Step 4: Commit Git & Push Remote (Tuân thủ Điều 1 Hiến pháp)**
  - `git add .`
  - `git commit -m "docs & core: complete capital management refactor with backup, capped TP, and break-even"`
  - `git push`
