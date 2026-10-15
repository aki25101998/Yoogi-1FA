# FT H4 Trend Alignment & Dynamic ATR Trailing Stop Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triệt tiêu 97.5% các vụ sập chuỗi DCA của Trend-Following bằng bộ lọc đồng pha H4 EMA, và cải tiến cơ chế Trailing Stop theo ATR M15 để loại bỏ tình trạng 75.2% lệnh bị chốt non ở +2 pips.

**Architecture:** 
1. Tích hợp H4 EMA20/50 alignment, slope và price position vào Layer 1 của FT Engine để chặn đứng tín hiệu ngược sóng khung lớn.
2. Nâng cấp `UpdateBreakEvenState` trong `DynamicExitEngine.mqh` từ khóa cứng +2 pips sang Trailing Stop động 1.5x ATR M15 với ngưỡng kích hoạt tối thiểu $\max(1.0\times\text{ATR}, 0.60\times\text{Natural TP})$.
3. Bảo toàn khả năng lưu trữ trạng thái qua GlobalVariables và tương thích hạch toán nợ.

**Tech Stack:** MQL5, MetaTrader 5 MetaEditor64 Compiler.

---

### Task 1: Thêm trường dữ liệu và Diagnostics cho H4 Filter

**Files:**
- Modify: `d:\Project\yoogi 1fa\Globals.mqh`
- Modify: `d:\Project\yoogi 1fa\TrendFollowingDiagnostics.mqh`

- [ ] **Step 1: Bổ sung trường trạng thái H4 vào `TrendFollowingContext` trong `Globals.mqh`**
  Thêm `bool h4_trend_aligned;` và `int h4_trend_direction;` vào `struct TrendFollowingContext`.

- [ ] **Step 2: Bổ sung bộ đếm Rejection Funnel trong `TrendFollowingDiagnostics.mqh`**
  Thêm trường `h4_trend_reject` vào struct `TFRejectionFunnelCounters`, thêm hàm `TFDiag_RecordH4Reject(int idx, int h1_dir, int h4_dir)` và in trong hàm in báo cáo summary funnel.

---

### Task 2: Hiện thực H4 EMA Trend Filter trong `TrendFollowingEngine.mqh`

**Files:**
- Modify: `d:\Project\yoogi 1fa\TrendFollowingEngine.mqh`

- [ ] **Step 1: Viết hàm `EvaluateH4TrendFilter(int idx, int required_direction)`**
  Kiểm tra trên `PERIOD_H4`:
  - `ema20_h4` vs `ema50_h4`
  - `h4_slope_bull` / `h4_slope_bear` từ `CalculateEMA_Generic(sym, PERIOD_H4, 50, 1 + TF_SLOPE_LOOKBACK)`
  - Giá đóng cửa `close_h4[0]` so với `ema50_h4`.
  - Trả về `true` nếu đồng thuận hướng `required_direction`, ngược lại trả về `false`.

- [ ] **Step 2: Tích hợp vào `EvaluateH1TrendRegime` / `ProcessTFLayer1`**
  Nếu `EvaluateH4TrendFilter` trả về `false`, ghi nhận reject `TFDiag_RecordH4Reject`, đặt `direction = 0` và không cho phép xác lập xu hướng FT.

---

### Task 3: Cải tiến Trailing Stop động theo ATR M15 trong `DynamicExitEngine.mqh`

**Files:**
- Modify: `d:\Project\yoogi 1fa\DynamicExitEngine.mqh`

- [ ] **Step 1: Sửa đổi hàm `UpdateBreakEvenState(int idx)`**
  - Tính ngưỡng kích hoạt:
    `double be_threshold_pips = MathMax(atr_pips * 1.0, natural_tp_pips * 0.60);`
    `if(be_threshold_pips < 10.0) be_threshold_pips = 10.0;`
  - Khoảng đệm trailing:
    `double trail_dist = PipsToPrice(idx, atr_pips * 1.5);`
  - Tính `candidate_stop`:
    - BUY: `candidate_stop = current_price - trail_dist`. Chặn dưới: `min_stop = avg_entry + PipsToPrice(idx, InpBreakEven_OffsetPips)`. Nếu `candidate_stop < min_stop`, gán bằng `min_stop`. Khi `candidate_stop > be_stop_price`, cập nhật `be_stop_price = candidate_stop`.
    - SELL: `candidate_stop = current_price + trail_dist`. Chặn trên: `max_stop = avg_entry - PipsToPrice(idx, InpBreakEven_OffsetPips)`. Nếu `candidate_stop > max_stop`, gán bằng `max_stop`. Khi `candidate_stop < be_stop_price` (hoặc `be_stop_price <= 0`), cập nhật `be_stop_price = candidate_stop`.

- [ ] **Step 2: Đảm bảo trạng thái Trailing được đồng bộ và lưu trữ**
  Gọi `SaveTradeProfile(idx, G_Pairs[idx].active_chain_id)` mỗi khi `be_stop_price` được nâng/hạ theo giá.

---

### Task 4: Compile EA & Backup Git

**Files:**
- Compile target: `d:\Project\yoogi 1fa\Yoogi 1FA.mq5`

- [ ] **Step 1: Compile EA bằng MetaEditor64 từ terminal**
  Chạy lệnh compile MetaEditor và kiểm tra file log:
  `powershell -Command "& 'C:\Program Files\MetaTrader 5\metaeditor64.exe' /compile:'d:\Project\yoogi 1fa\Yoogi 1FA.mq5' /log:'d:\Project\yoogi 1fa\compile.log'"`
  Xác nhận: 0 errors, 0 warnings.

- [ ] **Step 2: Commit và Push GitHub**
  Tuân thủ Điều 1 CONSTITUTION:
  `git add . ; git commit -m "feat: implement FT H4 trend alignment filter and dynamic ATR trailing stop" ; git push`
