# Hybrid Scalp-and-Run Engine: Strategy-Aware TP, Breathing Space Trailing & FT Partial Close Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triệt tiêu 80% các vụ chốt non hòa vốn +2 pips bằng cơ chế nới lỏng Trailing Stop và tăng lợi nhuận cho Trend-Following (FT) thông qua Take Profit mở rộng kết hợp Chốt lời từng phần (Partial Close 50/50) mà không ảnh hưởng tới an toàn của rổ lệnh DCA và Debt Pool.

**Architecture:** 
1. Tách biệt cấu hình TP cho Counter-Trend (scalp ngắn 15-40 pips) và Trend-Following (sóng lớn 25-100 pips) trong `Globals.mqh` và `DynamicExitEngine.mqh`.
2. Nới lỏng không gian thở của Trailing Stop trong `UpdateBreakEvenState` lên $\ge 75\%$ TP1 (min 18 pips) với đệm giãn cách $2.0 \times \text{ATR}_{\text{M15}}$ và khóa lợi nhuận theo nấc thực chất (+30% và +60% TP).
3. Hiện thực hóa động cơ `ExecuteFTPartialClose` trong `DynamicExitEngine.mqh` và nối vào `Corelogic.mqh` tại điểm `tp_hit`: Khi lệnh đơn FT chạm TP1, chốt 50% bỏ túi tiền tươi (và trừ nợ ngay nếu có nợ), 50% còn lại bật Runner Trailing Stop để gồng trọn con sóng H1/H4.
4. Đảm bảo lệnh CT và chuỗi đã nhồi DCA 2, 3 luôn Full Close 100% tại Basket TP để giải phóng Margin.

**Tech Stack:** MQL5, MetaEditor64 CLI, Git

---

## File Structure & Responsibilities

- `Globals.mqh`: Khai báo hằng số TP phân nhánh cho FT/CT và mở rộng struct `TradeProfile` (các cờ partial close).
- `DynamicExitEngine.mqh`: 
  - Nâng cấp `CalculateNaturalTP` phân nhánh theo `strategy_type`.
  - Nâng cấp `UpdateBreakEvenState` (ngưỡng 75% TP, đệm 2.0x ATR, bậc thang khóa lợi nhuận).
  - Thêm hàm `ExecuteFTPartialClose` và đồng bộ lưu/đọc qua Global Variables.
- `Corelogic.mqh`: Tích hợp logic kích hoạt `ExecuteFTPartialClose` khi `tp_hit` cho Lệnh đơn FT.

---

### Task 1: Khai báo hằng số và mở rộng `TradeProfile` trong `Globals.mqh`

- [x] **Step 1: Thêm hằng số TP phân nhánh cho FT và CT**
  - Mở `Globals.mqh`.
  - Thêm các hằng số:
    ```mql5
    const int    TF_DYNAMIC_TP_MIN_PIPS      = 25;    // Min TP cho FT (25 pips)
    const int    TF_DYNAMIC_TP_MAX_PIPS      = 100;   // Max TP cho FT (100 pips)
    const double TF_DYNAMIC_TP_ATR_MULT      = 3.0;   // FT ATR Multiplier (3.0x ATR M15)
    
    const int    CT_DYNAMIC_TP_MIN_PIPS      = 15;    // Min TP cho CT (15 pips)
    const int    CT_DYNAMIC_TP_MAX_PIPS      = 40;    // Max TP cho CT (40 pips)
    const double CT_DYNAMIC_TP_ATR_MULT      = 1.5;   // CT ATR Multiplier (1.5x ATR M15)
    
    const double TF_BE_TRIGGER_RATIO         = 0.75;  // Ngưỡng kích hoạt BE/Trailing (75% TP)
    const double TF_BE_MIN_PIPS              = 18.0;  // Ngưỡng tối thiểu pips kích hoạt BE
    const double TF_TRAILING_ATR_MULT        = 2.0;   // Khoảng đệm trailing (2.0x ATR M15)
    ```

- [x] **Step 2: Mở rộng struct `TradeProfile`**
  - Thêm các trường:
    ```mql5
    bool   ft_partial_closed;  // Đã partial close 50% tại TP1 chưa?
    double ft_partial_profit;  // Lợi nhuận thực tế của 50% chốt trước ($)
    double ft_partial_vol;     // Khối lượng đã đóng (lot)
    datetime ft_partial_time;  // Thời điểm partial close
    ```

---

### Task 2: Nâng cấp tính toán Natural TP trong `DynamicExitEngine.mqh`

- [x] **Step 1: Cập nhật hàm `CalculateNaturalTP`**
  - Điều chỉnh `atr_tp` và kẹp biên dải `[MinPips, MaxPips]` theo `strategy_type`:
    - Với `STRATEGY_FT`: Dùng `TF_DYNAMIC_TP_ATR_MULT`, clamp trong `[TF_DYNAMIC_TP_MIN_PIPS, TF_DYNAMIC_TP_MAX_PIPS]`.
    - Với `STRATEGY_CT`: Dùng `CT_DYNAMIC_TP_ATR_MULT`, clamp trong `[CT_DYNAMIC_TP_MIN_PIPS, CT_DYNAMIC_TP_MAX_PIPS]`.

---

### Task 3: Nâng cấp Trailing Stop & Bậc thang khóa lợi nhuận trong `DynamicExitEngine.mqh`

- [x] **Step 1: Cập nhật `UpdateBreakEvenState`**
  - Ngưỡng kích hoạt: `double be_threshold_pips = MathMax(atr_pips * TF_TRAILING_ATR_MULT, natural_tp_pips * TF_BE_TRIGGER_RATIO); if(be_threshold_pips < TF_BE_MIN_PIPS) be_threshold_pips = TF_BE_MIN_PIPS;`
  - Nếu `pips_run < be_threshold_pips`: return ngay để cho lệnh thở.
  - Khoảng đệm trailing: `trail_pips = atr_pips * TF_TRAILING_ATR_MULT;`
  - Bậc thang khóa lợi nhuận:
    - Nếu `pips_run >= natural_tp_pips * 0.90`: Khóa tối thiểu `natural_tp_pips * 0.60`.
    - Ngược lại (`pips_run >= natural_tp_pips * 0.75`): Khóa tối thiểu `natural_tp_pips * 0.30`.

---

### Task 4: Hiện thực hóa Partial Close 50/50 cho Lệnh Đơn FT

- [x] **Step 1: Viết hàm `ExecuteFTPartialClose` trong `DynamicExitEngine.mqh`**
  - Kiểm tra điều kiện hợp lệ: `strategy_type == STRATEGY_FT`, `pos_count == 1`, `!ft_partial_closed`.
  - Tính 50% lot chuẩn sàn: `half_vol = MathFloor((total_vol * 0.5) / step) * step;`
  - Nếu `half_vol >= min_vol`:
    - Gọi `trade.PositionClosePartial(ticket, half_vol)`.
    - Đánh dấu `ft_partial_closed = true`.
    - Hạch toán nợ nếu `debt > 0`: trừ trực tiếp lợi nhuận vừa đóng vào Debt Pool.
    - Kéo Stop ảo phần còn lại lên `Entry + 3 pips`.
    - Kích hoạt `runner_active = true` cho 50% khối lượng còn lại bám theo Trailing Stop.
  - Nếu `half_vol < min_vol` (ví dụ lệnh 0.01 lot): Chuyển toàn bộ vị thế sang Runner Mode với Stop khóa tại +50% TP1.

- [x] **Step 2: Lưu và khôi phục trạng thái Partial Close qua Global Variables**
  - Trong `SaveTradeProfile` và `LoadTradeProfile`: Lưu thêm `ft_partial_closed`, `ft_partial_profit`.

- [x] **Step 3: Tích hợp vào `Corelogic.mqh` tại điểm `tp_hit`**
  - Khi `tp_hit` xảy ra cho chuỗi:
    - Nếu `G_TradeProfile[i].strategy_type == STRATEGY_FT && count == 1 && !G_TradeProfile[i].ft_partial_closed`:
      - Gọi `ExecuteFTPartialClose(i, current_price)`.
      - Không gọi `CloseAndResolveChain(i, "TP")`.
    - Các trường hợp khác (CT hoặc chuỗi DCA $\ge 2$ lệnh hoặc đã partial close): Tiếp tục gọi `CloseAndResolveChain(i, "TP")` như bình thường.

---

### Task 5: Biên dịch & Kiểm tra bằng MetaEditor64 CLI

- [x] **Step 1: Xóa compile.log và chạy MetaEditor64 CLI**
- [x] **Step 2: Xác nhận `Result: 0 errors, 0 warnings` và cập nhật file `Yoogi 1FA.ex5`**

---

### Task 6: Commit và Push lên GitHub

- [x] **Step 1: Tạo commit với thông điệp chuẩn**
  `git add . ; git commit -m "feat(exit): implement Hybrid Scalp-and-Run TP, breathing space trailing and FT partial close" ; git push origin master`
