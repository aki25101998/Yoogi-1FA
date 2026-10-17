# YOOGI 1FA: ĐẶC TẢ THIẾT KẾ (DESIGN SPECIFICATION)
## Hybrid Scalp-and-Run Engine: Strategy-Aware TP, Breathing Space Trailing & FT Partial Close

> **Ngày tạo**: 17/10/2026  
> **Trạng thái**: Draft / In Review  
> **Áp dụng cho**: Yoogi-1FA (Dual Engine: Counter-Trend & Trend-Following)

---

## 1. BỐI CẢNH & MỤC TIÊU (CONTEXT & OBJECTIVES)

### 1.1 Vấn đề phát hiện từ Backtest 3 năm (2023 - 2026)
Sau khi nâng cấp thành công bộ lọc Chống quá mức H1 (`TF_MAX_H1_EXTENSION_ATR = 2.0`) và Bắt buộc quét thanh khoản M5:
- **Gross Loss** đã giảm sốc 82.8% (từ -$38,995 xuống -$6,702).
- **Max Equity Drawdown** giảm ngoạn mục từ 27.05% xuống **11.09%**.
- **Tỷ lệ thắng (Win Rate)** đạt **71.71%** (327 thắng / 129 thua).
- Tuy nhiên, phân tích sâu 218 chuỗi lệnh thắng bình thường (`NORMAL-EXIT`) phát hiện điểm nghẽn lớn về hiệu suất:
  1. **47.2% lệnh thắng (103/218 chuỗi) bị chốt non ở trạng thái `BREAK_EVEN` (+2 pips)**: Do cơ chế Trailing Stop kích hoạt quá sớm (ngay khi đạt 10 pips hoặc 60% TP), khiến khoảng đệm Stop ảo kéo quá sát giá. Một nhịp rung lắc râu nến bình thường trên khung M5 đã chạm +2 pips, ép lệnh đóng hòa vốn/lãi mỏng trước khi giá kịp chạm TP.
  2. **Biên độ TP của Trend-Following (FT) bị bó hẹp**: FT đang bị cùm chung công thức Natural TP ngắn như Counter-Trend (15 - 25 pips). Với một lệnh thuận xu hướng H1/H4 mạnh, mức TP này quá ngắn, không tương xứng với tiềm năng sóng.
  3. **Lợi nhuận trung bình mỗi lệnh thắng thấp**: `Average profit trade` chỉ đạt **$29**, trong khi `Average loss trade` là -$52.
  4. **Tỷ lệ kích hoạt Runner Mode cực thấp**: Chỉ có 14 chuỗi (6.4%) được kích hoạt Runner Mode do vướng điều kiện khắt khe của CCI M5 ngắn hạn.

### 1.2 Mục tiêu cải tiến (Design Goals)
1. **Phân tách mục tiêu Take Profit (TP) theo Chiến Lược**:
   - **Counter-Trend (CT)**: Giữ nguyên tính chất scalp đảo chiều nhanh (`Min 15 pips, Max 40 pips, 1.5x ATR M15`).
   - **Trend-Following (FT)**: Mở rộng biên độ TP theo xung lực sóng H1/H4 (`Min 25 pips, Max 100 pips, 3.0x ATR M15`).
2. **Nới lỏng không gian thở cho Trailing Stop (Pre-TP Breathing Space)**:
   - Nâng ngưỡng kích hoạt Trailing Stop/BE từ 60% lên **$\ge 75\%$ Natural TP** (tối thiểu 18 pips, thay vì 10 pips).
   - Nâng khoảng đệm Trailing Stop từ $1.5 \times \text{ATR}$ lên **$2.0 \times \text{ATR}_{\text{M15}}$** để giá không bị quét bởi nhiễu M5.
   - Bậc thang khóa lợi nhuận: Khi đạt 75% TP khóa +30% TP; khi đạt 90% TP khóa +60% TP (thay vì chỉ ép về +2 pips).
3. **Mô hình Chốt Lời Đa Tầng "Hybrid Scalp-and-Run" (Partial Close 50/50)**:
   - Dành riêng cho **Lệnh đơn FT (Order 1)**: Khi chạm TP1 (Natural TP mở rộng), đóng **50% khối lượng** (`PositionClosePartial`) bỏ túi tiền tươi.
   - 50% khối lượng còn lại dời Stop ảo về **Entry + 3 pips** và kích hoạt **Runner Trailing Stop $2.0 \times \text{ATR}_{\text{M15}}$** để gồng trọn con sóng H1/H4 (50 - 100+ pips).
4. **Bảo toàn an toàn cho DCA & Debt Recovery**:
   - Lệnh Counter-Trend (CT) và các chuỗi đã nhồi DCA (DCA 2, DCA 3) **luôn đóng 100% Full Close** tại TP để giải phóng Margin và thoát hiểm an toàn.

---

## 2. QUY TẮC PHÂN ĐỊNH THOÁT LỆNH (EXIT MATRIX)

| Chiến lược | Loại chuỗi | Khối lượng | Cơ chế TP & Thoát lệnh | Trailing Stop |
| :--- | :---: | :---: | :--- | :--- |
| **Trend-Following (FT)** | **Lệnh đơn (Order 1)** | $\ge 0.02$ lot | **Partial Close 50/50**:<br>• 50% đóng tại TP1 (25-35 pips).<br>• 50% thả Runner gồng sóng lớn. | Trail $2.0 \times \text{ATR}_{\text{M15}}$ cho 50% còn lại, SL tối thiểu Entry + 3 pips. |
| **Trend-Following (FT)** | **Lệnh đơn (Order 1)** | $= 0.01$ lot | **Full Runner**:<br>Chạm TP1 khóa bảo toàn 50% TP1, thả toàn bộ lệnh chạy theo Trailing Stop. | Trail $2.0 \times \text{ATR}_{\text{M15}}$, SL tối thiểu +50% TP1. |
| **Trend-Following (FT)** | **Chuỗi DCA (2 - 3 lệnh)** | Mọi volume | **Full Basket Close 100%**:<br>Đóng toàn bộ rổ lệnh tại Basket TP. | Không áp dụng partial close, ưu tiên thu hồi vốn. |
| **Counter-Trend (CT)** | **Mọi chuỗi (1 - 3 lệnh)** | Mọi volume | **Full Close 100%**:<br>Đóng toàn bộ tại TP cấu trúc / Basket TP. | Trail $2.0 \times \text{ATR}_{\text{M15}}$ (chỉ kích hoạt khi $\ge 75\%$ TP). |

---

## 3. THIẾT KẾ CHI TIẾT CÁC THÀNH PHẦN

### 3.1 Mở Rộng Take Profit Theo Chiến Lược (`CalculateNaturalTP`)
Trong `DynamicExitEngine.mqh`:
1. **Tham số mới trong `Globals.mqh`**:
   ```mql5
   const int    TF_DYNAMIC_TP_MIN_PIPS      = 15;    // Min TP cho FT (15 pips - bám sát cản M15)
   const int    TF_DYNAMIC_TP_MAX_PIPS      = 100;   // Max TP cho FT (100 pips)
   const double TF_DYNAMIC_TP_ATR_MULT      = 2.0;   // FT ATR Multiplier (2.0x ATR M15 ~ 16-20 pips)
   
   const int    CT_DYNAMIC_TP_MIN_PIPS      = 15;    // Min TP cho CT (15 pips)
   const int    CT_DYNAMIC_TP_MAX_PIPS      = 40;    // Max TP cho CT (40 pips)
   const double CT_DYNAMIC_TP_ATR_MULT      = 1.5;   // CT ATR Multiplier (1.5x ATR M15)

   const double TF_BE_TRIGGER_RATIO         = 0.70;  // Ngưỡng kích hoạt BE/Trailing (70% TP)
   const double TF_BE_MIN_PIPS              = 15.0;  // Ngưỡng tối thiểu pips kích hoạt BE (15 pips)
   const double TF_TRAILING_ATR_MULT        = 2.0;   // Khoảng đệm trailing động (2.0x ATR M15)
   ```
2. **Logic tính toán phân nhánh**:
   - Khi `strategy_type == STRATEGY_FT`:
     - Ưu tiên cản kỹ thuật M15 (`struct_tp * 0.8 + atr_tp * 0.2`), không vượt quá cản M15.
     - `atr_tp = atr_pips * TF_DYNAMIC_TP_ATR_MULT;`
     - Kẹp trong dải `[TF_DYNAMIC_TP_MIN_PIPS, TF_DYNAMIC_TP_MAX_PIPS]`.
   - Khi `strategy_type == STRATEGY_CT`:
     - `atr_tp = atr_pips * CT_DYNAMIC_TP_ATR_MULT;`
     - Kẹp trong dải `[CT_DYNAMIC_TP_MIN_PIPS, CT_DYNAMIC_TP_MAX_PIPS]`.

### 3.2 Nâng Cấp Ngưỡng Kích Hoạt Trailing Stop & Break-Even (`UpdateBreakEvenState`)
1. **Ngưỡng kích hoạt mới**:
   ```mql5
   // Chỉ kích hoạt khi giá chạy được ≥ 70% Natural TP (hoặc ≥ 1.5x ATR M15, tối thiểu 15 pips)
   double be_threshold_pips = MathMax(atr_pips * 1.5, natural_tp_pips * TF_BE_TRIGGER_RATIO);
   if(be_threshold_pips < TF_BE_MIN_PIPS) be_threshold_pips = TF_BE_MIN_PIPS;
   
   if(pips_run < be_threshold_pips) return; // Cho lệnh thở tự do
   ```
2. **Khoảng đệm Trailing Stop**:
   ```mql5
   double trail_pips = (atr_pips > 0.0) ? (atr_pips * 2.0) : 25.0;
   ```
3. **Khóa bảo toàn lợi nhuận theo nấc (Tiered Profit-Protection)**:
   - Thay vì ép cứng về `Entry + 2 pips`:
   - Nếu `pips_run >= natural_tp_pips * 0.90`: Khóa tối thiểu **+60% Natural TP**.
   - Ngược lại (`pips_run >= 75%`): Khóa tối thiểu **+30% Natural TP**.
   - Điều này đảm bảo khi lệnh đã đi được 75% quãng đường, nếu thị trường đảo chiều, EA sẽ bỏ túi ít nhất 30% - 60% lợi nhuận, hoàn toàn chấm dứt tình trạng ăn +2 pips bèo bọt!

### 3.3 Động Cơ Chốt Lời Từng Phần Cho Lệnh FT Đơn (`ExecuteFTPartialClose`)
Tích hợp trong `DynamicExitEngine.mqh` và `Corelogic.mqh`:
1. **Cập nhật `TradeProfile`**:
   - Thêm cờ `bool ft_partial_closed` và `double ft_partial_profit`.
2. **Điều kiện kích hoạt Partial Close**:
   - `strategy_type == STRATEGY_FT`
   - Số vị thế của chuỗi `pos_count == 1` (Lệnh đơn)
   - Chưa từng partial close (`!G_TradeProfile[idx].ft_partial_closed`)
   - Giá hiện tại chạm ngưỡng TP1 (`tp_hit == true`)
3. **Thao tác thực thi**:
   - Tính toán khối lượng đóng 50%:
     ```mql5
     double total_vol = PositionGetDouble(POSITION_VOLUME);
     double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
     double half_vol = MathFloor((total_vol * 0.5) / step) * step;
     ```
   - Nếu `half_vol >= SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN)`:
     - Gọi `trade.PositionClosePartial(ticket, half_vol)`.
     - Ghi nhận `ft_partial_closed = true`.
     - Nếu đang có Debt (`debt > 0`): Khấu trừ ngay lợi nhuận của 50% này vào Debt Pool (`Debt_After = Debt_Before - partial_profit`).
     - Dời Stop ảo của 50% còn lại lên `Entry + 3 pips`.
     - Kích hoạt `runner_active = true` cho phần còn lại, bám theo Trailing Stop $2.0 \times \text{ATR}_{\text{M15}}$.

---

## 4. QUY TRÌNH HẠCH TOÁN NỢ (DEBT RECOVERY AUDIT)

Khi tài khoản đang trong chế độ Phục hồi nợ (`Recovery Mode`):
1. **Pha 1 (Partial Close 50%)**:
   - Lợi nhuận thực tế đạt được từ 50% khối lượng: `realized_pnl_1`.
   - `Debt_Reduction_1 = MathMin(debt_before, realized_pnl_1);`
   - `Debt_After_1 = debt_before - Debt_Reduction_1;`
   - Ghi log `[RECOVERY PARTIAL CLOSED]`.
2. **Pha 2 (Runner Close 50% còn lại)**:
   - Khi trailing stop bị chạm hoặc giá chạm trần: `realized_pnl_2`.
   - `Debt_Reduction_2 = MathMin(Debt_After_1, realized_pnl_2);`
   - `Debt_Final = Debt_After_1 - Debt_Reduction_2;`
   - Nếu `Debt_Final <= 0.00001`: Hoàn tất thu hồi nợ (Full Recovery Complete), Reset DCA sequence về 0!
   - Ghi log `[RECOVERY FINAL CLOSED]`.

Toàn bộ quy trình tuân thủ nghiêm ngặt Điều 9 của Hiến pháp EA Yoogi 1FA (Amortization Rule).

---

## 5. DỰ KIẾN KẾT QUẢ & TIÊU CHÍ NGHIỆM THU

1. **Số lệnh đóng ở `BREAK_EVEN` (+2 pips)**: Dự kiến giảm từ **103 lần xuống < 25 lần**.
2. **Tỷ lệ Runner Mode**: Dự kiến tăng từ **6.4% lên > 30%** đối với các lệnh FT.
3. **Average Profit Trade**: Tăng từ **$29 lên $45 - $60** (+50% đến +100%).
4. **Max Drawdown**: Duy trì ổn định dưới **13%**.
5. **Biên dịch MQL5**: 0 errors, 0 warnings.
