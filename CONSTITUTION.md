# YOOGI-1FA: HIẾN PHÁP HỆ THỐNG (CONSTITUTION)

> **Phiên bản**: 2.0 — Cập nhật ngày 13/10/2026
> **Build**: TF_MOMENTUM_10BAR | Version 33.00

Tài liệu này đóng vai trò là "Hiến pháp" cốt lõi của Yoogi-1FA. Mọi bản cập nhật, chỉnh sửa trong tương lai đều phải tuân thủ nghiêm ngặt các nguyên tắc và logic được định nghĩa tại đây.

---

## ĐIỀU 1: LUẬT BACKUP BẮT BUỘC (GIT PUSH RULE)

1. **Bắt buộc**: Bất kỳ thay đổi, cập nhật, hay sửa lỗi nào đối với source code (dù là nhỏ nhất) đều phải được Agent (hệ thống) TỰ ĐỘNG commit và push lên GitHub ngay lập tức sau khi hoàn thành task. Tuyệt đối không cần đợi người dùng nhắc nhở lệnh "push".
2. **Quy trình**: 
   - Sử dụng lệnh `run_command` trên PowerShell để chạy: `git add . ; git commit -m "Tóm tắt ngắn gọn" ; git push`
   - Hoặc có thể sử dụng workflow `/backup`.
   - Message commit phải miêu tả ngắn gọn và chính xác thay đổi.
3. **Mục tiêu**: Đảm bảo source code không bao giờ bị mất, dễ dàng rollback nếu cập nhật gây lỗi, và đồng bộ hóa công việc.

---

## ĐIỀU 2: TRIẾT LÝ HỆ THỐNG (DUAL ENGINE TRADING)

1. **Dual Entry Architecture**: Hệ thống sử dụng **2 engine vào lệnh song song**:
   - **Counter-Trend (CT)**: Tìm kiếm các điểm đảo chiều có xác suất cao (Reversal Engine V2).
   - **Trend-Following (TF)**: Tìm kiếm các điểm entry thuận xu hướng sau pullback (TF Engine Phase 3).
2. **Signal Manager**: Khi cả 2 engine cùng phát tín hiệu, áp dụng quy tắc:
   - Cùng chiều → **DUAL entry** (xác nhận mạnh nhất).
   - Ngược chiều → **CONFLICT → KHÔNG vào lệnh**.
   - Chỉ 1 engine → entry theo engine đó (CT hoặc FT).
3. **Khách quan và Đa chiều**: Không đánh đồng các tín hiệu đo lường cùng một hiện tượng. Các tín hiệu phải được nhóm (GROUP) theo bản chất thực sự của chúng.
4. **Master Entry Quality**: Master Entry phải thật sự chất lượng. Cả CT và TF đều yêu cầu scoring system ≥ 75 điểm VÀ phải vượt qua tất cả Hard Requirements.
5. **DCA là Recovery Mechanism**: DCA chạy độc lập với Entry Engine. Khi chain DCA đạt giới hạn mà vẫn lỗ, hệ thống ghi nhận nợ (Debt) và chuyển sang chế độ Recovery.

---

## ĐIỀU 3: KIẾN TRÚC COUNTER-TREND ENGINE (REVERSAL ENGINE V2 — 4 LAYERS)

Để quyết định một CT Master Entry, EA phải phân tích thị trường qua 4 tầng (Layers) tuần tự:

### LAYER A: LOCATION (Vị thế)
- *Câu hỏi*: "Giá có đang ở một vùng cực đoan đáng để bắt đảo chiều không?"
- **Extension (Distance from EMA)**: Giá phải vượt ra khỏi mức cân bằng (EMA50) một khoảng cách tối thiểu (đo bằng x ATR). Chia làm 3 mức: Normal (1.0 ATR), Strong (1.5 ATR), Extreme (2.0 ATR).
- *Lưu ý*: Location chỉ là điều kiện CẦN, không bao giờ là tín hiệu vào lệnh.

### LAYER B: EXHAUSTION (Kiệt sức)
- *Câu hỏi*: "Xu hướng hiện tại có đang mất đà không?"
- Gồm 3 thành phần (tối đa 15 điểm cho toàn group):
  1. **Divergence**: Sự phân kỳ giữa giá (Price) và động lượng (CCI). (8đ)
  2. **Candle Rejection**: Nến từ chối mạnh (Râu nến/wick lớn so với body, đóng cửa ở nửa ngược lại). (6đ)
  3. **Failed Continuation**: Giá cố gắng phá vỡ đỉnh/đáy tiếp diễn nhưng thất bại và đóng cửa bật ngược trở lại. (6đ)
- *Lưu ý*: Bắt buộc phải có ít nhất 1 tín hiệu Exhaustion.

### LAYER C: REVERSAL CONFIRMATION (Xác nhận đảo chiều)
- *Câu hỏi*: "Đã có bằng chứng cấu trúc thực sự đảo chiều chưa?"
- Bao gồm các chốt chặn:
  1. **Liquidity Sweep (20đ)**: Quét thanh khoản (giá phá Swing Low/High nhưng không giữ được và đóng cửa quay đầu). Bắt buộc phải có reject rõ ràng (Break + Reject + Close Back).
  2. **Displacement (15đ)**: Lực đẩy mạnh (Nến đảo chiều có thân nến lớn > 0.8 ATR và đóng cửa ở mức 70% của nến).
  3. **Structure Shift / MSS (25đ)**: Thay đổi cấu trúc thị trường (Phá vỡ swing gần nhất với khoảng cách break rõ ràng > 0.2 ATR, không chấp nhận wick break).
  4. **Retest (Optional)**: Giá quay lại test vùng vừa phá vỡ và trụ lại được.
- **Event Coherence**: Sweep → Displacement → MSS phải hoàn tất trong 12 LTF bars.
- **Entry Distance**: Giá không được trôi quá 3x LTF ATR so với MSS break level.

### LAYER D: EXTERNAL CONFIRMATION (Bộ lọc bên ngoài)
- *Câu hỏi*: "Các yếu tố ngoại cảnh có ủng hộ không?"
- **Momentum (10đ)**: CCI và Range Filter ủng hộ hướng đảo chiều.
- **DXY Filter (Dual TF)**: Chỉ áp dụng cho các cặp có USD. DXY HTF + LTF phải đồng pha, sau đó kiểm tra hợp lưu với cặp tiền (xxxUSD: ngược chiều DXY, USDxxx: cùng chiều DXY). Nếu xung đột → Cấm lệnh (Block). Cặp không có USD (EURGBP) bỏ qua filter này.

### CT Hard Requirements (7 chốt chặn)
Cho dù tổng điểm có cao đến đâu, CT Entry **bắt buộc** phải pass:
1. **HTF Location**: Nằm trong vùng Reversal Zone hợp lệ.
2. **Exhaustion Evidence**: Ít nhất 1 dấu hiệu kiệt sức.
3. **Structure Shift (MSS)**: Cấu trúc phải bị phá vỡ.
4. **Min Score**: Tổng điểm ≥ `InpCT_RequiredScore` (mặc định 75).
5. **DXY Alignment**: DXY không được chống lại setup (cặp USD).
6. **Bar Closed**: Chỉ sử dụng nến đã đóng (`shift = 1`) — không repaint.
7. **Timeout / Invalidation**: Setup chưa quá 150 bars (safety) và chưa bị phá vỡ cấu trúc.

### CT State Machine (8 bước)
- **STATE 0 (NO_SETUP)**: Chờ HTF Location.
- **STATE 1 (LOCATION)**: Đã vào vùng cực đoan. Chờ Exhaustion.
- **STATE 2 (EXHAUSTION)**: Đã có dấu hiệu kiệt sức. Chờ Liquidity Sweep.
- **STATE 3 (LIQUIDITY)**: Đã có quét thanh khoản. Chờ Displacement.
- **STATE 4 (REVERSAL_CONF)**: Lực đẩy xuất hiện. Chờ xác nhận MSS.
- **STATE 5 (STRUCTURE_SHIFT)**: MSS thành công. Chờ Retest (nếu bật).
- **STATE 6 (RETEST)**: Retest hoàn tất. Chuẩn bị tính điểm.
- **STATE 7 (ENTRY_READY)**: Passed toàn bộ! Bắn lệnh Master Entry.

---

## ĐIỀU 4: KIẾN TRÚC TREND-FOLLOWING ENGINE (TF ENGINE PHASE 3 — 3 LAYERS)

Để quyết định một TF Master Entry, EA phải phân tích thị trường qua 3 tầng Multi-Timeframe:

### LAYER 1: H1 TREND REGIME (Xác định xu hướng chính)
- *Câu hỏi*: "H1 có đang trong xu hướng rõ ràng không?"
- **EMA Alignment**: EMA20 > EMA50 (BUY) hoặc EMA20 < EMA50 (SELL).
- **EMA50 Slope**: Độ dốc EMA50 phải dương (BUY) hoặc âm (SELL).
- **Price Position**: Giá phải ở phía trên (BUY) hoặc dưới (SELL) EMA50.
- **Structure**: HH/HL (BUY) hoặc LL/LH (SELL).
- **Not Sideway**: ATR ratio phải > 0.5 (không phải thị trường phẳng).
- **Quality Score**: Tối đa 20 điểm. Strong = 20đ (tất cả 5 điều kiện), Base = 15đ (4/5 điều kiện).

### LAYER 2: M15 PULLBACK DETECTION (Phát hiện điều chỉnh)
- *Câu hỏi*: "Giá có đang pullback về vùng giá trị không?"
- **Pullback Depth**: Trong khoảng [0.3 ATR, 3.0 ATR] (đủ sâu nhưng chưa reversal).
- **EMA Distance**: Giá không vượt quá 1.5 ATR phía bên kia EMA50.
- **Pullback Duration**: Tối đa 30 M15 bars.
- **Protected Structure**: Impulse high/low phải còn nguyên vẹn (không bị phá).
- **Quality Score**: Tối đa 20 điểm.

### LAYER 3: M5 ENTRY TRIGGER (Tín hiệu vào lệnh)
- *Câu hỏi*: "Có bằng chứng trên M5 rằng pullback đã kết thúc không?"
- **Sweep**: Giá quét qua pullback swing extremity.
- **Displacement**: Nến M5 đã đóng có range ≥ 0.60 ATR (bonus nếu ≥ 1.20 ATR).
- **MSS (Market Structure Shift)**: Phá vỡ swing gần nhất, break distance ≥ 0.10 ATR (bonus ≥ 0.50 ATR).
- **Momentum Window**: Tối đa 10 M5 bars sau MSS để indicator xác nhận (CCI + Range Filter + Price Confirmation).
- **Event Coherence**: Sweep → Displacement trong 5 M5 bars, Displacement → MSS trong 15 M5 bars.

### Phase 3 Quality Filters (Bộ lọc chất lượng nâng cao)
- **ATR Ratio**: Current ATR / Baseline ATR trong [0.50, 2.50] (tránh flat và news spike).
- **Entry Candle Quality**: Body ≥ 30% range, close location ≥ 55% phía thuận.
- **Rejection Wick**: Wick ngược ≤ 45% range.
- **Spread Filter**: ≤ 0.80 ATR VÀ ≤ 50 points (5.0 pips).
- **Entry Distance**: Distance from MSS ≤ 2.50 ATR VÀ ≤ 2.50× displacement candle range.
- **Post-MSS Adverse**: Max adverse excursion ≤ 1.30 ATR.

### TF Hard Requirements
1. **H1 Trend**: Phải có xu hướng rõ ràng (direction ≠ 0).
2. **M15 Pullback**: Phải có pullback hợp lệ.
3. **M5 SMC Sequence**: Sweep → Displacement → MSS phải hoàn tất đúng trình tự.
4. **Momentum Confirmation**: Ít nhất 1 indicator (CCI/RF/PC) xác nhận trong window.
5. **Min Score**: Tổng điểm ≥ `InpTF_RequiredScore` (mặc định 75).
6. **Phase 3 Filters**: Tất cả quality filters phải pass.
7. **Bar Closed**: Chỉ sử dụng nến đã đóng — không repaint.

### TF State Machine (7 bước)
- **TF_STATE_NONE**: Chờ H1 xác lập trend.
- **TF_STATE_H1_TREND**: H1 trend confirmed. Chờ M15 pullback.
- **TF_STATE_M15_PULLBACK**: Pullback detected. Chờ M5 sweep.
- **TF_STATE_M5_WAIT_SWEEP**: Chờ liquidity sweep trên M5.
- **TF_STATE_M5_WAIT_DISPLACEMENT**: Chờ displacement candle.
- **TF_STATE_M5_WAIT_MSS**: Chờ market structure shift.
- **TF_STATE_ENTRY_READY**: Passed toàn bộ! Bắn lệnh Master Entry.

---

## ĐIỀU 5: DXY FILTER (DUAL TIMEFRAME CONVERGENCE)

1. **Auto-Detect**: EA tự động tìm symbol DXY trên broker (DXY, USDX, USDIndex, DX, DOLLAR_INDX, US_Dollar). Nếu không tìm thấy → DXY filter tự tắt, EA vẫn trade bình thường.
2. **Dual TF Signal**: DXY được phân tích trên cả HTF (H1) và LTF (M5) sử dụng CCI Trap + Range Filter.
3. **Convergence Rule**: DXY HTF và LTF phải cùng chiều. Nếu xung đột → reset DXY signal.
4. **Pair Mapping**:
   - **xxxUSD** (EURUSD, AUDUSD): Hợp lưu khi DXY **ngược chiều** cặp tiền.
   - **USDxxx** (USDCAD, USDCHF): Hợp lưu khi DXY **cùng chiều** cặp tiền.
   - **Non-USD** (EURGBP): Bỏ qua DXY filter.
5. **Signal Freshness**: DXY HTF signal tối đa 48 H1 bars, DXY LTF signal tối đa 288 M5 bars.

---

## ĐIỀU 6: QUẢN LÝ SETUP VÀ HỦY BỎ (INVALIDATION)

Áp dụng cho cả CT và TF:

1. **Không Timeout cứng ngắn hạn**: KHÔNG sử dụng các timeout ngắn hạn hạn chế setup (như 25 bars). Một setup đảo chiều tốt có thể tốn nhiều thời gian.
2. **Safety Expiration**: 
   - CT: 150 bars (fail-safe chống kẹt state).
   - TF: 100 M5 bars cho setup, 30 M15 bars cho pullback.
3. **Invalidation (Hủy setup logic)**: Setup bị reset nếu giả thuyết không còn hợp lệ:
   - CT: Giá phá thủng swing được bảo vệ mà không reject.
   - TF: H1 protected structure bị phá, M15 impulse bị phá, H1 trend mất.
4. **Không tự xẹp điểm (Decay)**: Không trừ điểm setup chỉ vì thời gian trôi qua.
5. **Diagnostics (Rejection Funnels)**: Cả CT và TF đều có hệ thống ghi nhận chi tiết tại sao setup bị reject ở bước nào, bao nhiêu lần, để phục vụ tối ưu hóa.

---

## ĐIỀU 7: KIẾN TRÚC AUTO-ONLY VÀ QUẢN LÝ VỐN

1. **Auto-Only Architecture**: EA là hệ thống 100% AUTO. Mọi logic liên quan đến Manual Mode đã bị loại bỏ vĩnh viễn và **tuyệt đối không được khôi phục lại**.
2. **Multi-Symbol**: EA gắn trên chart EURUSD H1, trade 5 cặp: EURUSD, AUDUSD, USDCAD, EURGBP, USDCHF. Auto-detect broker suffix.
3. **Timeframe chuẩn**: HTF = H1, LTF = M5. TF Engine thêm MTF = M15 cho pullback detection.

### 7.1 Tính Lot (Risk-Based)

| Tham số | Giá trị | Mô tả |
|---|---|---|
| `InpRiskPercent` | User Input (mặc định 0.5%) | % Balance dùng tính lot |
| `InpSetBalance` | User Input (mặc định 0) | Balance tham chiếu (0 = dùng thực tế) |
| `InpHeSoLot` | 1.3 (hardcoded) | Hệ số nhân DCA (progressive) |
| Divisor | 6.0 mặc định (USDCAD=4.48, EURGBP=7.64) | Chia theo đặc thù cặp tiền |

- Công thức: `Lot = (Balance × Risk% / 100) / (Divisor × 100)`
- DCA Lot: `Previous DCA Lot × 1.3` (hoặc `CalculateDCALot()` nếu chưa có previous).
- Risk = 0 → Lot = 0 → KHÔNG mở lệnh (kill switch an toàn).
- `InpSetBalance` bắt buộc phải được giữ nguyên là biến User Input.

### 7.2 DCA Chain Management

| Tham số | Giá trị | Mô tả |
|---|---|---|
| `InpMaxDCAPerChain` | 3 (hardcoded) | Giới hạn số position trong 1 chain |
| `InpDCA_MinStepPips` | 30 pips | Step tối thiểu |
| `InpDCA_MaxStepPips` | 60 pips | Step tối đa |
| `InpDCA_Step_ATRMultiplier` | 1.0 | Hệ số ATR cho dynamic step |

- **Dynamic Step**: Tính từ ATR(14) M15 × multiplier, clamp trong [30, 60] pips. Step được **cố định tại thời điểm mở Master** và áp dụng cho toàn bộ chain.
- **Chain Limit**: Khi đạt `InpMaxDCAPerChain` (3 positions) mà giá vẫn đi ngược, toàn bộ chain bị đóng (reason: MAX_DCA). Phần lỗ được ghi thành **System Debt** và hệ thống chuyển sang Recovery Mode.
- **Chain ID**: Mỗi chain có ID unique (monotonic), lưu persistent qua GlobalVariable, survive EA restart.
- **Strategy Attribution**: Mỗi chain gắn tag CT/FT/DUAL, lưu persistent, detect qua 7-priority fallback chain.

### 7.3 Stop Loss

- **SL = 0** trên tất cả lệnh (Master + DCA) — By design.
- Quản lý rủi ro thay thế bằng: DCA chain → MAX_DCA close → Debt Recovery.

---

## ĐIỀU 8: DYNAMIC EXIT ENGINE (QUẢN LÝ THOÁT LỆNH ĐỘNG)

### 8.1 TP Calculation (Natural TP)

TP được tính động dựa trên 4 yếu tố, **không cố định 60 pips**:

| # | Candidate | Nguồn | Mô tả |
|---|---|---|---|
| 1 | ATR Target | ATR(14) M15 × 2.0 | Scale: CT ×0.8, FT ×1.2, DUAL ×1.0 |
| 2 | Structure Target | Swing High/Low M15 | Nearest swing trong direction |
| 3 | Available Space | EMA50 obstacle M15+H1 | Khoảng cách tới EMA50 hợp lệ |
| 4 | Momentum Factor | CCI + Range Filter | STRONG ×1.2, NEUTRAL ×1.0, WEAK ×0.8 |

- **Ưu tiên**: CT lấy MIN(Structure, ATR). FT/DUAL lấy Weighted Average (60% Structure + 40% ATR).
- **Available Space Limiter**: TP không vượt quá 85% available space (trong Normal mode).
- **Final Clamp**: TP kẹp trong [`InpDynamicTP_MinPips`, `InpDynamicTP_MaxPips`] = [15, 90] pips.
- **Fallback**: Nếu Dynamic Engine fail → dùng `InpMasterTPPips` = 60 pips.

### 8.2 TP Compression

Khi conditions xấu đi, TP được giảm xuống (chỉ giảm, không tăng):

- **Triggers**: Momentum yếu đi (×0.75), Structure target gần hơn, Available space thu hẹp.
- **Anti-Jitter**: Thay đổi tối thiểu 5 pips, rate limit 1 lần/5 phút, chỉ khi profit ≥ 10 pips.

### 8.3 Runner Mode (FT Only)

- **Activation**: Profit ≥ 80% target TP VÀ Momentum = STRONG VÀ M15 protected structure intact.
- **Trailing**: ATR(14) M15 × 1.5, chỉ trail theo hướng có lợi.
- **Exit**: Khi trailing stop bị hit.
- **Scope**: Chỉ áp dụng cho strategy FT và DUAL, KHÔNG áp dụng cho CT.

### 8.4 Recovery-Aware TP & Dynamic Ceiling

Khi hệ thống có Debt > 0, TP được tính toán để cover nợ:

| Trạng thái | TP Target |
|---|---|
| Normal (Debt = 0) | Natural TP |
| Recovery, ≤2 positions, chưa partial | Debt × 50% + Normal Profit |
| Recovery, 3+ positions, chưa partial | Debt × 100% + Normal Profit |
| Recovery, đã partial trước đó | Debt × 100% + Normal Profit |

- Recovery TP KHÔNG BAO GIỜ thấp hơn Natural TP (khi Natural TP nằm dưới trần).
- **Dynamic Ceiling (Trần Khống Chế Động)**: Tránh bẫy "Gánh nặng TP" khi nợ lớn. TP không bao giờ được vượt quá `Available Space × 0.85` (vùng cản kỹ thuật EMA50 M15/H1) hoặc `Structure Target × 1.05`, và bị chặn trần tối đa bởi `InpDynamicTP_MaxPips = 90` pips.
- **Amortization (Khấu trừ trả góp dần)**: Khi chuỗi chạm trần TP hoặc Break-Even chốt lời, toàn bộ lợi nhuận thực tế đạt được (`Realized Profit`) sẽ được trừ thẳng vào `$Debt` (`Debt_After = Debt_Before - Realized_Profit`), phần dôi dư mới tính vào lãi ròng. Các chuỗi tiếp theo sẽ trả nốt phần nợ còn lại thay vì cố ép 1 chuỗi phải gánh hết nợ bất khả thi.

### 8.5 Dynamic Break-Even & Trailing Lock (Bảo Vệ Hòa Vốn 2 Nấc)

- **Nấc 1 (Khóa hòa vốn)**: Khi giá chạy được ≥ 75% Natural TP (hoặc ≥ 0.8× ATR M15, tối thiểu 10 pips) → Kích hoạt Break-Even, dời Stop ảo về `AvgEntry ± 2 pips` (`InpBreakEven_OffsetPips`).
- **Nấc 2 (Trailing Lock)**: Khi giá vượt qua 100% Natural TP (đang rướn lên vùng Recovery TP) → Khóa bảo toàn tối thiểu 50% Natural TP hoặc Trailing theo sau giá 1.2× ATR M15. Stop chỉ dời theo hướng có lợi.
- **Thoát lệnh**: Khi giá chạm Stop bảo vệ → đóng toàn bộ chuỗi với reason `BREAK_EVEN`, bảo toàn vốn và lấy lợi nhuận đạt được khấu trừ nợ.

### 8.6 Basket TP

- TP tính trên **Weighted Average Entry** của toàn bộ chain (không phải master entry).
- TP Price = AvgEntry ± Required Distance.
- Failsafe: TP phải ở phía đúng (BUY: TP > AvgEntry, SELL: TP < AvgEntry).

---

## ĐIỀU 9: SYSTEM-LEVEL DEBT & RECOVERY (QUẢN LÝ NỢ & PHỤC HỒI)

### 9.1 System Debt

- **Unified per Symbol**: Nợ được gộp chung cho mỗi symbol, **không tách theo strategy** (CT/FT/DUAL).
- **Debt Source**: Khi chain bị đóng do MAX_DCA (hoặc lý do khác) với loss < 0 → `Debt += |Loss|`.
- **Authoritative Resolution**: PnL được tính từ lịch sử deals (DEAL_ENTRY_OUT), **không dùng floating PnL**.
- **Idempotency**: Mỗi chain chỉ được resolve 1 lần (marker: `Yoogi_Resolved_{symbol}_{chain_id}`).

### 9.2 Tiered Recovery

| Lần recovery | Chain size | % Debt trả |
|---|---|---|
| Lần đầu | ≤ 2 positions | 50% |
| Lần đầu | 3+ positions | 100% |
| Đã partial trước đó | Bất kỳ | 100% |

- Nếu trả hết debt → **Full Recovery**: Reset Debt = 0, DCA Seq = 0, Recovery Level = 0.
- Nếu chưa hết → **Partial Recovery**: Ghi nhận flag, lock DCA level (lặp lại chain cũ).

### 9.3 DCA Sequence (Global Counter)

- DCA Sequence là counter toàn cục per symbol, **tăng liên tục** qua các chain.
- Normal mode: Chain mới bắt đầu từ DCA 1.
- Recovery mode: Chain mới tiếp tục từ DCA Seq hiện tại + 1.
- Lot tính theo DCA Seq: `Lot = BaseLot × 1.3^(seq-1)`.
- Reset về 0 khi Full Recovery hoàn tất.

### 9.4 State Persistence

Toàn bộ state critical được lưu qua GlobalVariable để survive EA restart:
- System Debt, Recovery Level, DCA Sequence per symbol.
- Active Chain ID, Chain Position Count, Chain Step Pips.
- Strategy Attribution per chain.
- Dynamic Exit TradeProfile (TP, Runner state, Compression state).
- Legacy per-strategy state (backward compatibility + migration logic).

---

## ĐIỀU 10: MULTI-SYMBOL ARCHITECTURE

1. **5 Cặp tiền**: EURUSD, AUDUSD, USDCAD, EURGBP, USDCHF.
2. **Chart host**: Bắt buộc gắn trên EURUSD H1.
3. **Auto Suffix Detection**: Tự động detect broker suffix (VD: `.pro`, `m`, `#`) từ chart hiện tại.
4. **DXY Mapping**: 5 DXY contexts (1:1 với 5 pairs), chỉ active cho pairs có USD.
5. **Timer Architecture**: 
   - `OnTick()`: Chạy ManagePairs() — logic giao dịch cốt lõi.
   - `OnTimer()` (3s): Cập nhật Dashboard — không ảnh hưởng trade logic.
6. **Single Magic per Chain**: Mỗi chain dùng chain_id làm magic number (không dùng fixed magic per pair).

---

## ĐIỀU 11: DIAGNOSTICS & MONITORING

1. **Rejection Funnels**: Cả CT (ReversalDiagnostics.mqh) và TF (TrendFollowingDiagnostics.mqh) đều ghi nhận:
   - Setup nào bị reject ở bước nào.
   - Lý do reject cụ thể.
   - Tổng số reject theo từng layer/step.
   - In summary khi EA tắt (OnDeinit).
2. **State Transition Logging**: Mọi chuyển đổi state đều được log với reason.
3. **Build Diagnostic**: In đầy đủ cấu hình khi EA khởi động (version, constants, settings).
4. **Trade Logging**: Mọi DCA-OPEN, CHAIN-CLOSE, DEBT-ADD, RECOVERY đều có structured log format.
5. **Dashboard (InfoDisplay)**: Hiển thị real-time trạng thái 5 pairs, active chains, scores.

---

## TỔNG KẾT

Mọi lập trình viên, AI Assistant hay Sub-agent khi tác động vào Yoogi-1FA đều phải:
1. Đọc và hiểu CONSTITUTION này trước tiên.
2. Code theo định hướng Dual Engine + Scoring + Hard Requirements.
3. KHÔNG sửa đổi hardcoded constants (InpMaxDCAPerChain, InpHeSoLot, InpKhoangMoPip, ...) trừ khi có sự đồng ý rõ ràng từ người dùng.
4. Đảm bảo mọi state critical đều được persist qua GlobalVariable.
5. Commit lên Github NGAY LẬP TỨC sau khi sửa đổi code thành công (tuân thủ **Điều 1**).
