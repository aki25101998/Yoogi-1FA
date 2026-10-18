# Optimized Runner Engine: Hybrid Structure & Multi-Tier Trailing Design

> **Tài liệu đặc tả thiết kế kỹ thuật (Design Specification)**  
> **Dự án:** EA Yoogi 1FA  
> **Ngày:** 18/10/2026  
> **Tác giả:** Pair Programming với AI Agent Antigravity  
> **Trạng thái:** Chờ phê duyệt triển khai (Pending Plan & Implementation)

---

## 1. BỐI CẢNH & MỤC TIÊU (CONTEXT & OBJECTIVES)

### 1.1 Phân Tích Thực Trạng Từ Dữ Liệu Backtest Run 4 (20261018.log)
Trong bản backtest gần nhất (Run 4), việc thả lỏng sàn TP xuống 15 pips và áp dụng mô hình Hybrid Scalp-and-Run đã mang lại thành công lớn:
* **Tỷ lệ cắt 50% tiền tươi tại TP1**: Kích hoạt thành công **63 lần** (trung bình chốt lời chính xác ở 15.1 – 15.6 pips).
* **Số lần 50% còn lại chuyển sang Runner**: Kích hoạt tới **74 lần**.
* **Vấn đề cốt lõi phát hiện**:
  * Mặc dù Runner kích hoạt 74 lần, nhưng **trung bình mỗi lệnh Runner chỉ đem lại $19.30** (~15 – 18 pips).
  * **Nguyên nhân kỹ thuật**: Khoảng đệm Trailing Stop hiện tại dựa vào $2.0 \times \text{ATR}_{\text{M15}}$ (~16 pips). Khi giá bứt phá lên vùng 25 – 30 pips, các nhịp rung lắc, hồi sóng kỹ thuật (pullback) bình thường 10 – 12 pips trên khung M5 đã vô tình quét trúng Trailing Stop.
  * Hậu quả là 50% khối lượng Runner bị ép thoát non, hoàn toàn bỏ lỡ cơ hội gồng trọn các con sóng trend H1/H4 dài **50 – 100+ pips**.

### 1.2 Mục Tiêu Thiết Kế
1. **Giải phóng không gian thở cho Runner**: Ngăn chặn hoàn toàn việc râu nến M5 quét trúng Trailing Stop trong khoảng 15 – 30 pips.
2. **Tịnh tiến Stop Loss theo Cấu Trúc Kỹ Thuật (Structure-Based Trailing)**: Thay vì bám cứng theo giá thả trôi (Price-based ATR), Stop Loss của Runner sẽ bám theo **đáy Swing Low M15** (đối với BUY) và **đỉnh Swing High M15** (đối với SELL), đảm bảo chỉ thoát lệnh khi xu hướng thực sự bị gãy.
3. **Bổ sung Mục Tiêu Chốt Lời Mở Rộng TP2 (Extended Target TP2)**: Đặt mốc chốt lời chủ động tại cản cứng H1 hoặc biên độ **50 – 85 pips**, giúp bỏ túi trọn vẹn đỉnh sóng khi thị trường bứt phá mạnh, tránh tình trạng giá chạm đỉnh rồi quay đầu rút râu.

---

## 2. KIẾN TRÚC VẬN HÀNH 3 GIAI ĐOẠN CỦA RUNNER

```
                [ TP1 Hit (15 - 18 pips) / Lãi ≥ 18 pips ]
                                    │
                  ExecuteFTPartialClose (Chốt 50% Tiền Tươi)
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 1: VÙNG ĐỆM THỞ TỰ DO (Breathing Buffer: 15 – 30 pips)        │
│ • Stop Loss neo cứng tại: Entry ± 3.0 pips (Free Trade tuyệt đối)       │
│ • TUYỆT ĐỐI KHÔNG DỜI SL SÁT GIÁ trong vùng này!                        │
│ • Giá thoải mái Retest đỉnh/đáy cũ mà không bị quét out sớm.            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Giá bứt phá ≥ 30 pips
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 2: BÁM THEO CẤU TRÚC SWING M15 (Structure Trailing: 30–55 pips│
│ • BUY: Dời SL tịnh tiến dưới đáy Swing Low M15 gần nhất - 0.5x ATR M15 │
│ • SELL: Dời SL tịnh tiến trên đỉnh Swing High M15 gần nhất + 0.5x ATR  │
│ • Quy tắc 1 chiều: SL chỉ dời theo chiều có lợi, không bao giờ lùi.     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Giá đạt cản H1 hoặc ≥ 50 - 85 pips
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 3: CHỐT LỜI MỞ RỘNG TP2 (Target TP2 Harvest: 50 – 85 pips)   │
│ • Chạm mục tiêu cản kỹ thuật H1 (runner_tp2_price)                     │
│ • Đóng 100% phần Runner còn lại, ghi nhận lý do: RUNNER_TP2             │
│ • Bỏ túi trọn vẹn siêu lợi nhuận con sóng dài (Amortize nợ nếu có).    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. THIẾT KẾ CHI TIẾT CÁC THÀNH PHẦN

### 3.1 Tham Số Cấu Hình Mới Trong `Globals.mqh`
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

### 3.2 Cập Nhật Struct `TradeProfile` Trong `DynamicExitEngine.mqh`
Bổ sung trường lưu trữ giá mục tiêu TP2:
```mql5
struct TradeProfile
{
   ...
   // Runner Engine State
   bool     runner_active;
   double   runner_trail_price;
   datetime runner_activation_time;
   double   runner_tp2_price;     // [MỚI] Mức giá mục tiêu TP2 cho Runner (cản H1)
   double   runner_tp2_pips;      // [MỚI] Khoảng cách pips tới TP2
   int      runner_stage;         // [MỚI] 1 = Breathing, 2 = Structure Trailing, 3 = Harvested
   ...
};
```
Đồng bộ lưu/đọc qua Global Variables:
* `Yoogi_RunnerTP2_{symbol}_{chain_id}`
* `Yoogi_RunnerStage_{symbol}_{chain_id}`

### 3.3 Thuật Toán Tính Cản H1 Làm Mục Tiêu TP2 (`CalcH1TargetTP2`)
Khi vị thế bước vào Runner Mode, hàm này sẽ xác định mục tiêu cản tiếp theo trên khung H1:
1. **Tìm kiếm cản Swing H1**:
   * Đối với **BUY**: Quét 40 nến H1 gần nhất tìm Swing High cao hơn Entry ít nhất `TF_RUNNER_TP2_MIN_PIPS` (50 pips).
   * Đối với **SELL**: Quét 40 nến H1 gần nhất tìm Swing Low thấp hơn Entry ít nhất `TF_RUNNER_TP2_MIN_PIPS`.
2. **Kiểm tra cản động EMA50 H1**:
   * Nếu có EMA50 H1 cản đường phía trước và cách Entry từ 50 đến 85 pips, lấy EMA50 H1 làm mục tiêu TP2.
3. **Kẹp dải an toàn (Clamping)**:
   * Nếu tìm thấy cản: `tp2_pips = Clamp(obstacle_pips, TF_RUNNER_TP2_MIN_PIPS, TF_RUNNER_TP2_MAX_PIPS)`.
   * Nếu không có cản rõ ràng trong phạm vi: `tp2_pips = 60.0` (mốc mặc định 60 pips).
4. **Quy đổi ra giá**:
   * BUY: `runner_tp2_price = entry + PipsToPrice(idx, tp2_pips);`
   * SELL: `runner_tp2_price = entry - PipsToPrice(idx, tp2_pips);`

### 3.4 Thuật Toán Dời Stop Loss Theo Cấu Trúc M15 (`CalcM15SwingTrailingStop`)
Khi lợi nhuận đạt $\ge 30\text{ pips}$ (bước vào Giai đoạn 2):
1. Đọc dữ liệu High/Low của 35 nến M15 gần nhất (`ReadHighLow_Generic`).
2. Dò tìm đỉnh/đáy swing hợp lệ:
   * **BUY (Tìm Higher Lows)**:
     * Dò đáy Swing Low gần nhất (với `left = 3, right = 1`) nằm cao hơn `Entry + 5 pips`.
     * Điểm Stop đề xuất: $\text{Candidate Stop} = \text{Swing Low} - (0.5 \times \text{ATR}_{\text{M15}})$.
   * **SELL (Tìm Lower Highs)**:
     * Dò đỉnh Swing High gần nhất nằm thấp hơn `Entry - 5 pips`.
     * Điểm Stop đề xuất: $\text{Candidate Stop} = \text{Swing High} + (0.5 \times \text{ATR}_{\text{M15}})$.
3. **Fallback An Toàn**: Nếu chưa hình thành Swing mới, duy trì mức Stop Loss cũ hoặc dùng đệm rộng $2.5 \times \text{ATR}_{\text{M15}}$ từ giá cao/thấp nhất đạt được.
4. **Quy tắc bảo toàn một chiều (Ratchet Rule)**:
   * BUY: `new_stop = MathMax(current_runner_trail, candidate_stop);`
   * SELL: `new_stop = MathMin(current_runner_trail, candidate_stop);`

### 3.5 Nâng Cấp Logic Thoát Lệnh Trong `Corelogic.mqh`
Tại vòng lặp quản lý cặp tiền `ManagePairs`:
```mql5
// --- XỬ LÝ THOÁT LỆNH RUNNER (GIAI ĐOẠN 2 & 3) ---
if(G_TradeProfile[i].runner_active)
{
   // 1. Kiểm tra chạm mục tiêu TP2 mở rộng (Giai đoạn 3: Siêu Lợi Nhuận)
   bool tp2_hit = false;
   if(basket_dir == 1 && current_price >= G_TradeProfile[i].runner_tp2_price && G_TradeProfile[i].runner_tp2_price > 0.0) tp2_hit = true;
   if(basket_dir == -1 && current_price <= G_TradeProfile[i].runner_tp2_price && G_TradeProfile[i].runner_tp2_price > 0.0) tp2_hit = true;

   if(tp2_hit)
   {
      PrintFormat("[%s] >>> RUNNER TP2 HIT: Current=%.5f TargetTP2=%.5f (Lãi ~%.1f pips). Chốt hạ đỉnh sóng...",
                  sym, current_price, G_TradeProfile[i].runner_tp2_price, G_TradeProfile[i].runner_tp2_pips);
      CloseAndResolveChain(i, "RUNNER_TP2");
      continue;
   }

   // 2. Kiểm tra cắn Trailing Stop theo cấu trúc M15 (Giai đoạn 2: Bảo Toàn Lợi Nhuận)
   if(IsRunnerStopped(i))
   {
      PrintFormat("[%s] >>> RUNNER EXIT: Giá chạm Stop cấu trúc M15 (Current=%.5f Stop=%.5f). Đóng lệnh...",
                  sym, current_price, G_TradeProfile[i].runner_trail_price);
      CloseAndResolveChain(i, "RUNNER");
      continue;
   }
}
```

---

## 4. XỬ LÝ CÁC TÌNH HUỐNG BIÊN (EDGE CASES & SAFETY)

1. **Thị trường đảo chiều gắt ngay sau TP1 (Vùng 15 – 25 pips)**:
   * Nhờ có **Giai đoạn 1**, SL được khóa chắc ở `Entry + 3 pips`. Nếu giá sập, lệnh đóng ở +3 pips.
   * Kết hợp với 50% tiền tươi đã chốt trước đó tại TP1 (+15 pips), tổng lệnh vẫn là một **chiến thắng ròng vẻ vang**.
2. **Khối lượng 0.01 lot (không thể chia đôi)**:
   * Đã có cơ chế Failsafe: Khóa bảo toàn 50% TP1 và chuyển 100% vị thế sang Runner với target TP2.
3. **Khoảng trống giá (Price Gap) / Tin tức mạnh**:
   * Cơ chế Stop ảo trong `IsRunnerStopped` và `tp2_hit` luôn so sánh trực tiếp giá Bid/Ask thực tế với mức Stop, đảm bảo đóng lệnh ngay lập tức khi giá vượt qua mức quy định bất kể có trượt giá hay gap.
4. **Hạch toán Nợ (Debt Recovery Integration)**:
   * Lý do đóng `RUNNER_TP2` được tích hợp vào `ResolveClosedChainFromHistory` tương đương như `TP` và `RUNNER`. Toàn bộ lợi nhuận thu được đều được trừ thẳng vào quỹ nợ `System Debt`.

---

## 5. DỰ KIẾN KẾT QUẢ VÀ TÁC ĐỘNG TỚI PERFORMANCE

* **Số lệnh Runner chốt non (+18 pips)**: Dự kiến giảm từ 80% xuống dưới 25%.
* **Tỷ lệ lệnh Runner gồng được 40 – 70 pips**: Dự kiến đạt từ 30% đến 45% tổng số lệnh Runner.
* **Tác động tới Net Profit**: Với khoảng 25 – 35 lệnh Runner ăn trọn con sóng 50 – 80 pips, lợi nhuận ròng 3 năm dự kiến sẽ tăng thêm từ **+$1,800 đến +$2,500**, đưa tổng Net Profit vượt mốc **$5,500 – $6,000+** mà không hề làm tăng Drawdown!
