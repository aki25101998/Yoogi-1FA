# Kế Hoạch Triển Khai: Tích Hợp Cặp Vàng (XAUUSD) Vào EA Yoogi 1FA

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mở rộng EA Yoogi 1FA từ 6 cặp lên 7 cặp (bổ sung XAUUSD), hỗ trợ tự động nhận diện ký hiệu sàn (XAUUSD/GOLD), chuẩn hóa pip value ($0.10), áp dụng hệ số an toàn lot (Divisor = 12.0), cấu hình DCA Step (60 - 120 pips), Dynamic TP (40 - 150 pips TF, 30 - 80 pips CT), Runner Trailing (70 - 200 pips, Breathe 40 pips, BE 25 pips) và thêm Required Score cho XAUUSD trên Input.mqh.

**Architecture:** Bám sát đặc tả kỹ thuật tại [docs/superpowers/specs/2026-10-23-add-gold-xauusd-support-design.md](file:///d:/Project/yoogi%201fa/docs/superpowers/specs/2026-10-23-add-gold-xauusd-support-design.md). Hệ thống mở rộng `TOTAL_PAIRS` = 7, sử dụng kiến trúc Dedicated Pair Profile Helpers để điều phối các thông số tính toán pip, lot, step và exit cho Vàng hoàn toàn biệt lập với 6 cặp Forex hiện tại.

**Tech Stack:** MQL5, MetaEditor64 CLI, Git

---

### Task 1: Cập nhật `Input.mqh` - Thêm Tham Số Required Score Cho XAUUSD

**Files:**
- Modify: `d:\Project\yoogi 1fa\Input.mqh:20-33`

- [x] **Step 1: Bổ sung input CT và TF Required Score cho XAUUSD**
  - Mở `Input.mqh`
  - Thêm `input double InpXAUUSD_CT_Score = 100.0;  // [XAUUSD] Counter-Trend Required Score` vào nhóm CT Score.
  - Thêm `input double InpXAUUSD_TF_Score = 100.0; // [XAUUSD] Trend-Following Required Score` vào nhóm TF Score.

- [x] **Step 2: Xác nhận cú pháp và lưu file**
  - Đảm bảo các comment rõ ràng, đồng bộ với các cặp tiền khác.

---

### Task 2: Cập nhật `Globals.mqh` - Khởi Tạo 7 Cặp, Nhận Diện Sàn, Pip Value, Lot Divisor & Score Accessors

**Files:**
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:13-14` (TOTAL_PAIRS, DXY_CONTEXTS)
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:289-335` (Score Accessors)
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:558-605` (StandardBaseNames & GetBrokerSymbol)
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:676-695` (Pip Value Standardization)
- Modify: `d:\Project\yoogi 1fa\Globals.mqh:1161-1185` (CalculateAutoLot Divisor)

- [x] **Step 1: Cập nhật hằng số số lượng cặp**
  - Sửa `#define TOTAL_PAIRS 6` thành `#define TOTAL_PAIRS 7`.
  - Sửa `#define DXY_CONTEXTS 6` thành `#define DXY_CONTEXTS 7`.

- [x] **Step 2: Cập nhật mảng tên chuẩn và hàm tự động nhận diện ký hiệu sàn (`GetBrokerSymbol`)**
  - Cập nhật `StandardBaseNames[TOTAL_PAIRS]`: thêm `"XAUUSD"`.
  - Cập nhật `CommonBases[]`: thêm `"XAUUSD"`.
  - Mở rộng hàm `GetBrokerSymbol`: nếu `std_name == "XAUUSD"`, kiểm tra `XAUUSD` hoặc `GOLD`, hỗ trợ prefix/suffix từ biểu đồ hiện tại.

- [x] **Step 3: Chuẩn hóa Pip Value cho Vàng trong `InitGlobals()`**
  - Kiểm tra `if(G_Pairs[i].base_name == "XAUUSD")`:
    - Nếu digits == 2: `pip_value = 10.0 * point` (0.10 USD).
    - Nếu digits == 3: `pip_value = 100.0 * point` (0.10 USD).
    - Ngược lại: `pip_value = 10.0 * point`.

- [x] **Step 4: Cập nhật Lot Divisor cho XAUUSD trong `CalculateAutoLot`**
  - Thêm điều kiện: `else if(base == "XAUUSD") divisor = 12.0;`

- [x] **Step 5: Cập nhật hàm truy xuất điểm Required Score**
  - Cập nhật `GetPairCTRequiredScore`: map `base == "XAUUSD"` và `case 6:` trả về `InpXAUUSD_CT_Score`.
  - Cập nhật `GetPairTFRequiredScore`: map `base == "XAUUSD"` và `case 6:` trả về `InpXAUUSD_TF_Score`.

---

### Task 3: Cập nhật `CoreLogic.mqh` - Tối Ưu Hóa Tham Số DCA Step Cho Vàng

**Files:**
- Modify: `d:\Project\yoogi 1fa\CoreLogic.mqh`

- [x] **Step 1: Bổ sung các hàm helper phân định Step theo cặp**
  - Thêm `GetPairDCAMinStep(int idx)`: trả về 60 cho `XAUUSD`, `InpDCA_MinStepPips` (30) cho Forex.
  - Thêm `GetPairDCAMaxStep(int idx)`: trả về 120 cho `XAUUSD`, `InpDCA_MaxStepPips` (60) cho Forex.
  - Thêm `GetPairDCADefaultStep(int idx)`: trả về 70 cho `XAUUSD`, `InpKhoangMoPip` (30) cho Forex.

- [x] **Step 2: Cập nhật logic tính Dynamic Step và Fallback Step**
  - Tại vị trí tính `dyn_step` khi mở Master Order:
    - Kẹp biên: `if(dyn_step < GetPairDCAMinStep(idx)) dyn_step = GetPairDCAMinStep(idx);`
    - Kẹp biên: `if(dyn_step > GetPairDCAMaxStep(idx)) dyn_step = GetPairDCAMaxStep(idx);`
  - Tại vị trí khôi phục / fallback DCA Step: thay `InpDCA_MinStepPips` bằng `GetPairDCAMinStep(idx)`.

---

### Task 4: Cập nhật `DynamicExitEngine.mqh` - Cấu Hình Dynamic TP & Runner Trailing Cho Vàng

**Files:**
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh`

- [x] **Step 1: Xây dựng các hàm helper xác định TP & Trailing theo cặp**
  - Thêm `GetPairDynamicTPMinPips(int idx, int strategy_type)`:
    - XAUUSD: 40.0 cho FT, 30.0 cho CT.
    - Forex: `TF_DYNAMIC_TP_MIN_PIPS` (15.0), `CT_DYNAMIC_TP_MIN_PIPS` (15.0).
  - Thêm `GetPairDynamicTPMaxPips(int idx, int strategy_type)`:
    - XAUUSD: 150.0 cho FT, 80.0 cho CT.
    - Forex: `TF_DYNAMIC_TP_MAX_PIPS` (100.0), `CT_DYNAMIC_TP_MAX_PIPS` (40.0).
  - Thêm `GetPairRunnerTP2MinPips(int idx)`: XAUUSD = 70.0, Forex = 50.0.
  - Thêm `GetPairRunnerTP2MaxPips(int idx)`: XAUUSD = 200.0, Forex = 85.0.
  - Thêm `GetPairRunnerBreathePips(int idx)`: XAUUSD = 40.0, Forex = 30.0.
  - Thêm `GetPairBEMinPips(int idx)`: XAUUSD = 25.0, Forex = 15.0.

- [x] **Step 2: Áp dụng các helper vào các logic tính toán**
  - Trong `CalculateNaturalTP`: thay thế các biến kẹp min/max pips bằng `GetPairDynamicTPMinPips(idx, strategy_type)` và `GetPairDynamicTPMaxPips(idx, strategy_type)`.
  - Trong `CalcH1TargetTP2`: thay thế `TF_RUNNER_TP2_MIN_PIPS` và `TF_RUNNER_TP2_MAX_PIPS` bằng helper theo cặp.
  - Trong `UpdateRunnerStage`: kiểm tra `profit_pips < GetPairRunnerBreathePips(idx)`.
  - Trong `CheckAndApplyBreakEven`: kiểm tra `profit_pips >= GetPairBEMinPips(idx)`.

---

### Task 5: Cập nhật `Yoogi 1FA.mq5` - Cập Nhật Diagnostic OnInit

**Files:**
- Modify: `d:\Project\yoogi 1fa\Yoogi 1FA.mq5:84-88`

- [x] **Step 1: Cập nhật in diagnostic điểm số của XAUUSD trong `OnInit`**
  - Bổ sung `XAU=%.0f` vào cả 2 dòng `PrintFormat` của `CT_REQUIRED_SCORE` và `TF_REQUIRED_SCORE`.
  - Cập nhật nội dung log mô tả `Chế độ: 7 Pairs Fixed (EURUSD, AUDUSD, USDCAD, EURGBP, GBPUSD, NZDUSD, XAUUSD)`.

---

### Task 6: Biên Dịch Bằng MetaEditor64 & Kiểm Tra Hoàn Tất

**Files:**
- Run: MetaEditor64 CLI compilation

- [x] **Step 1: Chạy biên dịch qua PowerShell CLI**
  - Xóa `compile.log`.
  - Chạy `MetaEditor64.exe /compile:"Yoogi 1FA.mq5" /log:"compile.log"`.
  - Đọc `compile.log` và xác nhận kết quả: `0 errors, 0 warnings`.
  - Xác nhận file thực thi `Yoogi 1FA.ex5` được cập nhật timestamp mới.

---

### Task 7: Tự Động Backup Code Lên GitHub (CONSTITUTION Điều 1)

**Files:**
- Git: Commit & Push

- [x] **Step 1: Thực hiện commit và push toàn bộ thay đổi**
  - `git add .`
  - `git commit -m "feat(pair): add XAUUSD gold support with dedicated lot, step and dynamic exit profiles"`
  - `git push origin master`
