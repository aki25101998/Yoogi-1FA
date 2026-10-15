# YOOGI 1FA: ĐẶC TẢ THIẾT KẾ (DESIGN SPECIFICATION)
## H4 Trend Alignment Filter & Dynamic ATR Trailing Stop Engine

> **Ngày tạo**: 15/10/2026  
> **Trạng thái**: Approved by User  
> **Áp dụng cho**: Yoogi-1FA (Dual Engine: Counter-Trend & Trend-Following)

---

## 1. BỐI CẢNH & MỤC TIÊU (CONTEXT & OBJECTIVES)

### 1.1 Vấn đề phát hiện từ Backtest 3 năm (2023 - 2026)
Qua việc phân tích 42.7 triệu dòng log từ Strategy Tester:
1. **Trend-Following Engine (FT) là nguồn gây rủi ro chính**:
   - Gây ra **78 trên tổng số 80 lần chạm ngưỡng cắt lỗ chuỗi (MAX_DCA / Margin Exhaustion)**, chiếm **97.5%**.
   - Nguyên nhân: Nhịp điều chỉnh M15 Pullback thường xuyên biến thành cú đảo chiều sâu của khung H4/Daily. Khi đó FT vào lệnh ngược với xu hướng H4 lớn, giá đi ngược liên tục, nhồi 3 lệnh DCA và sập chuỗi.
2. **Cơ chế Break-Even sớm làm suy sút nghiêm trọng tỷ lệ Risk/Reward**:
   - 75.2% số chuỗi trong chế độ Recovery bị đóng ở mức hòa vốn non (+2 pips).
   - Lợi nhuận trung bình chỉ đạt **+$34** trong khi khoản thua lỗ trung bình lên tới **-$78** (Lỗ lớn gấp 2.3 lần Lãi).
   - Dù tỷ lệ thắng đạt gần 70%, kỳ vọng toán học (Expected Payoff) vẫn âm (-$0.89/trade) và toàn bộ tiền thắng chỉ dùng để khấu trừ nợ cũ.

### 1.2 Mục tiêu cải tiến
1. **Thêm bộ lọc H4 EMA Trend Alignment**:
   - Khóa chặt Layer 1 của FT Engine. Bắt buộc xu hướng H1 phải hoàn toàn đồng pha với khung H4 (EMA20 > EMA50, EMA50 Slope, và Price position).
   - Chặn đứng 100% các cú vào lệnh ngược sóng H4.
2. **Nâng cấp Trailing Stop động theo ATR M15**:
   - Bãi bỏ mức chốt non +2 pips cố định.
   - Chuyển sang cơ chế Trailing Stop bám theo giá ở khoảng cách $1.5 \times \text{ATR}_{\text{M15}}$ sau khi giá đã đạt ngưỡng bứt phá tối thiểu $\ge \max(1.0 \times \text{ATR}, 0.60 \times \text{Natural\_TP})$.
   - Đảm bảo lệnh có không gian dao động lành mạnh, tối đa hóa lợi nhuận khi thị trường có sóng dài.

---

## 2. THIẾT KẾ CHI TIẾT: BỘ LỌC XU HƯỚNG CẤP CAO (H4 EMA TREND FILTER)

### 2.1 Vị trí tích hợp
* Tích hợp vào **Layer 1: Trend Regime** trong file `TrendFollowingEngine.mqh` (hàm `EvaluateH1TrendRegime` hoặc tách thành hàm kiểm tra điều kiện H4 độc lập `EvaluateH4TrendFilter`).
* Cập nhật struct `TrendFollowingContext` trong `Globals.mqh` để lưu trữ trạng thái H4.
* Tích hợp thống kê vào `TrendFollowingDiagnostics.mqh`.

### 2.2 Logic tính toán các chỉ báo trên H4 (`PERIOD_H4`)
Sử dụng các hàm Generic đã chuẩn hóa trong `Indicators.mqh`:
1. **H4 EMA20 & EMA50**:
   ```mql5
   double ema20_h4 = CalculateEMA_Generic(sym, PERIOD_H4, 20, 1);
   double ema50_h4 = CalculateEMA_Generic(sym, PERIOD_H4, 50, 1);
   ```
2. **H4 EMA50 Slope**:
   ```mql5
   double ema50_h4_prev = CalculateEMA_Generic(sym, PERIOD_H4, 50, 1 + TF_SLOPE_LOOKBACK);
   bool h4_slope_bull = (ema50_h4 > ema50_h4_prev);
   bool h4_slope_bear = (ema50_h4 < ema50_h4_prev);
   ```
3. **Vị thế giá đóng cửa H4 (Price vs EMA50)**:
   ```mql5
   double close_h4[];
   if(CopyClose(sym, PERIOD_H4, 1, 1, close_h4) < 1) return 0;
   ```

### 2.3 Tiêu chí kiểm duyệt (Hard Gates)
* **Đối với tín hiệu BUY**:
  1. `ema20_h4 > ema50_h4` (EMA đồng pha tăng trên H4).
  2. `h4_slope_bull == true` (Độ dốc EMA50 H4 dương).
  3. `close_h4[0] > ema50_h4` (Giá đóng cửa nến 1 trên H4 nằm trên EMA50 H4).
  *Nếu bất kỳ điều kiện nào sai $\rightarrow$ Return 0 (Không công nhận xu hướng tăng).*
* **Đối với tín hiệu SELL**:
  1. `ema20_h4 < ema50_h4` (EMA đồng pha giảm trên H4).
  2. `h4_slope_bear == true` (Độ dốc EMA50 H4 âm).
  3. `close_h4[0] < ema50_h4` (Giá đóng cửa nến 1 trên H4 nằm dưới EMA50 H4).
  *Nếu bất kỳ điều kiện nào sai $\rightarrow$ Return 0 (Không công nhận xu hướng giảm).*

### 2.4 Diagnostic Tracking
* Thêm biến đếm `h4_trend_reject` trong `TFRejectionFunnel` (`TrendFollowingDiagnostics.mqh`).
* Ghi log khi setup bị từ chối do xung đột H4:
  `[FT_FILTER_REJECT] SYMBOL=... REASON=H4_TREND_CONFLICT H1_DIR=... H4_DIR=...`

---

## 3. THIẾT KẾ CHI TIẾT: TRAILING STOP ĐỘNG THEO ATR M15

### 3.1 Bãi bỏ cơ chế cũ
* Cơ chế cũ: Kích hoạt khi đạt $75\%$ Natural TP hoặc 10 pips $\rightarrow$ Khóa cứng `avg_entry \pm 2.0` pips.
* Nhược điểm: Thị trường giật nhẹ 2-5 pips là dính Stop, làm mất hoàn toàn tiềm năng ăn sóng dài và chốt non ở $2-$10.

### 3.2 Quy tắc Kích hoạt Mới (Dynamic ATR Trailing Activation)
* Không áp dụng mốc cố định 10 pips.
* Ngưỡng kích hoạt:
  $$\text{threshold\_pips} = \max\left(1.0 \times \text{ATR}_{\text{M15}}, 0.60 \times \text{Natural\_TP}\right)$$
  *(Đảm bảo giá đã bứt phá dứt khoát ra khỏi vùng tích lũy ban đầu).*

### 3.3 Khoảng đệm và dời Stop động
* Khoảng đệm trailing:
  $$\text{trail\_dist} = 1.5 \times \text{ATR}_{\text{M15}}$$
* Thuật toán cập nhật `be_stop_price`:
  * **BUY**:
    ```mql5
    double candidate_stop = current_price - trail_dist;
    // Chốt chặn an toàn: không bao giờ để candidate_stop thấp hơn điểm bảo toàn vốn tối thiểu
    double min_be_stop = avg_entry + PipsToPrice(idx, InpBreakEven_OffsetPips);
    if(candidate_stop < min_be_stop) candidate_stop = min_be_stop;

    if(!G_TradeProfile[idx].be_active)
    {
       G_TradeProfile[idx].be_active = true;
       G_TradeProfile[idx].be_stop_price = candidate_stop;
    }
    else if(candidate_stop > G_TradeProfile[idx].be_stop_price)
    {
       G_TradeProfile[idx].be_stop_price = candidate_stop; // Chỉ dời lên
    }
    ```
  * **SELL**:
    ```mql5
    double candidate_stop = current_price + trail_dist;
    // Chốt chặn an toàn: không bao giờ để candidate_stop cao hơn điểm bảo toàn vốn tối thiểu
    double max_be_stop = avg_entry - PipsToPrice(idx, InpBreakEven_OffsetPips);
    if(candidate_stop > max_be_stop) candidate_stop = max_be_stop;

    if(!G_TradeProfile[idx].be_active)
    {
       G_TradeProfile[idx].be_active = true;
       G_TradeProfile[idx].be_stop_price = candidate_stop;
    }
    else if(candidate_stop < G_TradeProfile[idx].be_stop_price)
    {
       G_TradeProfile[idx].be_stop_price = candidate_stop; // Chỉ dời xuống
    }
    ```

### 3.4 Quản lý Thoát lệnh và Lưu trữ Trạng thái (Persistence)
* `IsBreakEvenStopped`: Khi giá chạm hoặc vượt qua `be_stop_price`, trigger đóng chuỗi lệnh.
* Giữ nguyên mã lý do đóng chuỗi là `BREAK_EVEN` (hoặc `RUNNER`) để tương thích hoàn toàn với logic khấu trừ nợ `Debt Amortization` trong `ResolveClosedChainFromHistory`.
* `SaveTradeProfile` & `LoadTradeProfile` tiếp tục lưu trữ `be_stop_price`, `be_active` qua GlobalVariables để bảo toàn trạng thái khi EA restart / chuyển nến.

---

## 4. TÍNH TƯƠNG THÍCH VÀ CÁC CHỈ SỐ KIỂM ĐỊNH (VERIFICATION CRITERIA)

1. **Biên dịch không cảnh báo**: Không phát sinh lỗi hoặc cảnh báo mới trong quá trình compile với MetaEditor64.
2. **Backtest kiểm chứng**:
   - Số lượng lệnh FT giảm bớt nhưng chất lượng tăng vượt bậc.
   - Loại bỏ các chuỗi sập DCA ngược sóng lớn khung H4.
   - Tỷ lệ lợi nhuận trung bình trên mỗi lệnh thắng (`Average profit trade`) tăng từ $34 lên mức cao hơn nhờ Trailing Stop ATR.
   - Tỷ lệ thoát ở mức $2-$10 giảm mạnh, thay vào đó là các lệnh chốt lời từ 15-40 pips.
