# Tích Hợp Cặp Vàng (XAUUSD): Thiết Kế Kiến Trúc & Cấu Hình Chuyên Biệt

> **Tài liệu đặc tả thiết kế kỹ thuật (Design Specification)**  
> **Dự án:** EA Yoogi 1FA  
> **Ngày:** 23/10/2026  
> **Tác giả:** Pair Programming với AI Agent Antigravity  
> **Trạng thái:** Chờ phê duyệt triển khai (Pending Plan & Implementation)

---

## 1. BỐI CẢNH & MỤC TIÊU (CONTEXT & OBJECTIVES)

### 1.1 Bối Cảnh
Hệ thống EA Yoogi 1FA hiện tại vận hành đa cặp đồng thời từ 1 biểu đồ duy nhất (EURUSD H1) với 6 cặp tiền chuẩn (`TOTAL_PAIRS = 6`): EURUSD, AUDUSD, USDCAD, EURGBP, GBPUSD, NZDUSD.
Người dùng có nhu cầu bổ sung cặp **Vàng (XAUUSD)** vào danh mục giao dịch tự động của EA.

Do đặc thù Vàng là hàng hóa kim loại quý có biên độ sóng lớn (Daily ATR có thể lên tới $20 - $50, tương đương 200 - 500 pips), tốc độ trôi giá cao và giá trị hợp đồng (Contract size = 100 oz) khác biệt lớn so với các cặp tiền tệ Forex, việc áp dụng nguyên mẫu các thông số của Forex (Step 30 pips, Min TP 15 pips, Divisor 6.0) sẽ gây ra rủi ro nghiêm trọng:
1. **Lot quá lớn so với biến động giá**: 0.01 lot Vàng chạy $1 biến động $1. Với Divisor 6.0 như Forex, margin và rủi ro sụt giảm tài khoản (Drawdown) sẽ tăng gấp nhiều lần.
2. **Step mở DCA quá ngắn**: Khoảng cách 30 pips tương đương chỉ $3 giá Vàng. Vàng có thể biến động $3 trong vài cây nến M1/M5, khiến chuỗi DCA 3 lệnh bị gom lệnh quá sát và cạn sạch lệnh cứu trợ trong một nhịp sóng bình thường.
3. **TP quá hẹp so với biến động và spread**: Mức Min TP 15 pips của Forex chỉ tương đương $1.5 giá Vàng, rất dễ bị ăn mòn bởi spread giãn và trượt giá của Vàng.

### 1.2 Mục Tiêu Thiết Kế
1. **Mở rộng danh mục lên 7 cặp đồng thời**: Nâng `TOTAL_PAIRS = 7`, bổ sung `XAUUSD` vào danh sách, giữ nguyên toàn vẹn 6 cặp tiền Forex hiện tại.
2. **Tự động nhận diện ký hiệu sàn (Broker Symbol Auto-Detection)**: Nhận diện chính xác tên cặp Vàng trên mọi sàn (`XAUUSD`, `GOLD`, `XAUUSDm`, `GOLD.pro`, v.v.).
3. **Chuẩn hóa Pip Value**: Đảm bảo $1.00 giá vàng = 10 pips = 100 points, đồng nhất trên cả sàn 2 số thập phân và 3 số thập phân.
4. **Kiểm soát rủi ro khối lượng (Lot Divisor = 12.0)**: Giảm 50% khối lượng lot ban đầu của Vàng so với Forex để bảo toàn vốn và margin.
5. **DCA Step chuyên biệt cho Vàng**: Giãn khoảng cách DCA tối thiểu lên 60 pips ($6 giá), tối đa 120 pips ($12 giá), fallback 70 pips ($7 giá).
6. **Dynamic Exit & Trailing phù hợp biên độ Vàng**:
   - Trend-Following (TF) TP: 40 - 150 pips ($4 - $15 giá).
   - Counter-Trend (CT) TP: 30 - 80 pips ($3 - $8 giá).
   - Runner TP2: 70 - 200 pips ($7 - $20 giá), đệm thở tự do (Breathe Buffer) 40 pips ($4 giá).
   - BreakEven offset bảo vệ tại 25 pips ($2.5 giá).
7. **Bổ sung Entry Required Score**: Thêm `InpXAUUSD_CT_Score = 100.0` và `InpXAUUSD_TF_Score = 100.0` vào `Input.mqh` để người dùng có thể tinh chỉnh chất lượng lọc tín hiệu Vàng.

---

## 2. KIẾN TRÚC TỔNG THỂ & QUY TRÌNH XỬ LÝ (SYSTEM ARCHITECTURE)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ONINIT: YOOGI 1FA (EURUSD H1)                   │
├────────────────────────────────────────────────────────────────────────┤
│ TOTAL_PAIRS = 7: [EURUSD, AUDUSD, USDCAD, EURGBP, GBPUSD, NZDUSD, XAUUSD]│
│                                                                        │
│ 1. GetBrokerSymbol("XAUUSD") ──> Check "XAUUSD" / "GOLD" + Prefix/Suffix│
│ 2. InitGlobals()             ──> Point / Digits / PipValue Standardization│
│ 3. InitIndicators()          ──> Handles cho 7 cặp (H1 + M15 + M5)     │
│ 4. InitAllTradeProfiles()    ──> TradeProfile[7] Dynamic Exit Engine   │
│ 5. CreateDisplay()           ──> Dashboard UI mở rộng 7 hàng động       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                    MỖI TICK / TIMER (ONTIMER 3s)
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      DEDICATED PAIR EXECUTION                          │
├────────────────────────────────────────────────────────────────────────┤
│  Cặp Forex (idx 0..5):                                                 │
│    • Divisor = 6.0 (USDCAD: 4.48, EURGBP: 7.64)                        │
│    • DCA Step: [30 - 60 pips]                                          │
│    • TF TP: [15 - 100 pips] | CT TP: [15 - 40 pips]                    │
│                                                                        │
│  Cặp Vàng XAUUSD (idx = 6):                                            │
│    • Divisor = 12.0 (Volume an toàn = 50% Forex)                       │
│    • PipValue = 0.10 USD (1 giá = 10 pips)                             │
│    • DCA Step: [60 - 120 pips], Default: 70 pips                       │
│    • TF TP: [40 - 150 pips] | CT TP: [30 - 80 pips]                    │
│    • Runner TP2: [70 - 200 pips], Breathe: 40 pips                     │
│    • BE Threshold: 25 pips                                             │
│    • DXY Filter: USD-second pair (xxxUSD, ngược chiều DXY)             │
│    • CT Score: InpXAUUSD_CT_Score | TF Score: InpXAUUSD_TF_Score        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. THIẾT KẾ CHI TIẾT CÁC THÀNH PHẦN (COMPONENT SPECIFICATION)

### 3.1 Mở Rộng Danh Sách Cặp & Sửa Hằng Số Trong `Globals.mqh`
```mql5
#define TOTAL_PAIRS 7   // Nâng từ 6 lên 7 cặp
#define DXY_CONTEXTS 7 // Đồng bộ 7 DXY context

string StandardBaseNames[TOTAL_PAIRS] = {
   "EURUSD", "AUDUSD", "USDCAD", "EURGBP", "GBPUSD", "NZDUSD", "XAUUSD"
};
```

### 3.2 Tự Động Nhận Diện Ký Hiệu Sàn (`GetBrokerSymbol`)
Trong `Globals.mqh`, hàm `GetBrokerSymbol` được mở rộng để tự động tìm kiếm cả base `"XAUUSD"` lẫn `"GOLD"`:
- Kiểm tra trực tiếp `SymbolSelect("XAUUSD", true)` hoặc `SymbolSelect("GOLD", true)`.
- Nếu sàn có tiền tố/hậu tố (ví dụ biểu đồ hiện tại là `EURUSDm` hoặc `pro.EURUSD`):
  - Tìm theo quy luật `prefix + "XAUUSD" + suffix`.
  - Nếu không thấy, tìm tiếp `prefix + "GOLD" + suffix`.
- Nếu tìm thấy, gán vào `G_Pairs[idx].symbol` và gọi `SymbolSelect(..., true)`.

### 3.3 Chuẩn Hóa `pip_value` Cho Vàng
Tại `InitGlobals()` trong `Globals.mqh`:
```mql5
if(G_Pairs[i].base_name == "XAUUSD")
{
   if(G_Pairs[i].digits == 2)
      G_Pairs[i].pip_value = 10.0 * G_Pairs[i].point;   // 10 * 0.01 = 0.10
   else if(G_Pairs[i].digits == 3)
      G_Pairs[i].pip_value = 100.0 * G_Pairs[i].point;  // 100 * 0.001 = 0.10
   else
      G_Pairs[i].pip_value = 10.0 * G_Pairs[i].point;
}
else
{
   if(G_Pairs[i].digits == 5 || G_Pairs[i].digits == 3)
      G_Pairs[i].pip_value = 10.0 * G_Pairs[i].point;
   else
      G_Pairs[i].pip_value = 1.0 * G_Pairs[i].point;
}
```
*Kết quả*: 1 pip luôn bằng $0.10 trên mọi sàn, 1 giá vàng ($1.00) = 10 pips = 100 points.

### 3.4 Quản Lý Khối Lượng Lot (`CalculateAutoLot`)
Cập nhật trong `Globals.mqh`:
```mql5
double divisor = 6.0; // Mặc định an toàn cho Forex

if(base == "USDCAD")      divisor = 4.48;
else if(base == "EURGBP") divisor = 7.64;
else if(base == "XAUUSD") divisor = 12.0; // Vàng: 50% volume Forex
```
*Mô phỏng*:
- Balance = $10,000, Risk = 0.5%:
  - EURUSD: 0.08 lot.
  - XAUUSD: 0.04 lot.
- Chuỗi DCA: Lệnh 1 = 0.04 lot, Lệnh 2 = 0.05 lot, Lệnh 3 = 0.07 lot. Tổng khối lượng cả chuỗi = 0.16 lot (đảm bảo an toàn ký quỹ tuyệt đối).

### 3.5 Tham Số Giãn Lệnh DCA (`CoreLogic.mqh`)
Bổ sung các hàm helper xác định biên độ Step theo cặp:
```mql5
int GetPairDCAMinStep(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 60; // 60 pips ($6 giá)
   return InpDCA_MinStepPips; // 30 pips
}

int GetPairDCAMaxStep(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 120; // 120 pips ($12 giá)
   return InpDCA_MaxStepPips; // 60 pips
}

int GetPairDCADefaultStep(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 70; // 70 pips ($7 giá)
   return InpKhoangMoPip; // 30 pips
}
```
Tại các vị trí tính toán `dyn_step` khi mở Master Order hoặc fallback DCA:
- Thay vì kẹp cứng `[InpDCA_MinStepPips, InpDCA_MaxStepPips]`, sử dụng `GetPairDCAMinStep(idx)` và `GetPairDCAMaxStep(idx)`.
- Khi tính toán `dyn_step = (int)MathRound(atr_pips * InpDCA_Step_ATRMultiplier)`, với `pip_value = 0.10`, `atr_pips` của Vàng (~70 - 100 pips) sẽ tự động sinh ra khoảng cách DCA tự nhiên bám sát thị trường.

### 3.6 Tham Số Chốt Lời & Trailing (`DynamicExitEngine.mqh`)
Xây dựng các helper xác định giới hạn TP và Trailing theo cặp:
```mql5
double GetPairDynamicTPMinPips(int idx, int strategy_type)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return (strategy_type == STRATEGY_FT) ? 40.0 : 30.0;
   return (strategy_type == STRATEGY_FT) ? (double)TF_DYNAMIC_TP_MIN_PIPS : (double)CT_DYNAMIC_TP_MIN_PIPS;
}

double GetPairDynamicTPMaxPips(int idx, int strategy_type)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return (strategy_type == STRATEGY_FT) ? 150.0 : 80.0;
   return (strategy_type == STRATEGY_FT) ? (double)TF_DYNAMIC_TP_MAX_PIPS : (double)CT_DYNAMIC_TP_MAX_PIPS;
}

double GetPairRunnerTP2MinPips(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 70.0; // $7 giá
   return TF_RUNNER_TP2_MIN_PIPS; // 50.0 pips
}

double GetPairRunnerTP2MaxPips(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 200.0; // $20 giá
   return TF_RUNNER_TP2_MAX_PIPS; // 85.0 pips
}

double GetPairRunnerBreathePips(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 40.0; // $4 giá
   return TF_RUNNER_BREATHE_PIPS; // 30.0 pips
}

double GetPairBEMinPips(int idx)
{
   if(idx >= 0 && idx < TOTAL_PAIRS && G_Pairs[idx].base_name == "XAUUSD")
      return 25.0; // $2.5 giá
   return TF_BE_MIN_PIPS; // 15.0 pips
}
```
Tại các hàm:
- `CalculateDynamicTP`: sử dụng `GetPairDynamicTPMinPips(idx, strategy_type)` và `GetPairDynamicTPMaxPips(idx, strategy_type)`.
- `CalcH1TargetTP2`: sử dụng `GetPairRunnerTP2MinPips(idx)` và `GetPairRunnerTP2MaxPips(idx)`.
- `UpdateRunnerStage`: kiểm tra `profit_pips < GetPairRunnerBreathePips(idx)`.
- `CheckAndApplyBreakEven`: kiểm tra `profit_pips >= GetPairBEMinPips(idx)`.

### 3.7 Cấu Hình `Input.mqh` & Mapping Required Score
Trong `Input.mqh`:
```mql5
input group "=== ENTRY REQUIRED SCORE (COUNTER-TREND) ==="
input double InpEURUSD_CT_Score = 100.0;  // [EURUSD] Counter-Trend Required Score
input double InpAUDUSD_CT_Score = 100.0;  // [AUDUSD] Counter-Trend Required Score
input double InpUSDCAD_CT_Score = 95.0;  // [USDCAD] Counter-Trend Required Score
input double InpGBPUSD_CT_Score = 95.0;  // [GBPUSD] Counter-Trend Required Score
input double InpNZDUSD_CT_Score = 95.0;  // [NZDUSD] Counter-Trend Required Score
input double InpXAUUSD_CT_Score = 100.0; // [XAUUSD] Counter-Trend Required Score

input group "=== ENTRY REQUIRED SCORE (TREND-FOLLOWING) ==="
input double InpEURUSD_TF_Score = 100.0; // [EURUSD] Trend-Following Required Score
input double InpAUDUSD_TF_Score = 100.0; // [AUDUSD] Trend-Following Required Score
input double InpUSDCAD_TF_Score = 100.0; // [USDCAD] Trend-Following Required Score
input double InpGBPUSD_TF_Score = 100.0; // [GBPUSD] Trend-Following Required Score
input double InpNZDUSD_TF_Score = 100.0; // [NZDUSD] Trend-Following Required Score
input double InpXAUUSD_TF_Score = 100.0; // [XAUUSD] Trend-Following Required Score
```

Trong `Globals.mqh`:
Cập nhật `GetPairCTRequiredScore(int idx)` và `GetPairTFRequiredScore(int idx)`:
- Kiểm tra `base == "XAUUSD"` và `case 6` trả về `InpXAUUSD_CT_Score` và `InpXAUUSD_TF_Score`.

Trong `Yoogi 1FA.mq5`:
Cập nhật chuỗi in chẩn đoán tại `OnInit()`:
```mql5
PrintFormat("CT_REQUIRED_SCORE: EU=%.0f, AU=%.0f, UC=%.0f, GU=%.0f, NU=%.0f, XAU=%.0f | EG=100", 
            InpEURUSD_CT_Score, InpAUDUSD_CT_Score, InpUSDCAD_CT_Score, InpGBPUSD_CT_Score, InpNZDUSD_CT_Score, InpXAUUSD_CT_Score);
PrintFormat("TF_REQUIRED_SCORE: EU=%.0f, AU=%.0f, UC=%.0f, GU=%.0f, NU=%.0f, XAU=%.0f | EG=100", 
            InpEURUSD_TF_Score, InpAUDUSD_TF_Score, InpUSDCAD_TF_Score, InpGBPUSD_TF_Score, InpNZDUSD_TF_Score, InpXAUUSD_TF_Score);
```

### 3.8 Xử Lý DXY Filter Cho Vàng
Do `base_name = "XAUUSD"`, hàm khởi tạo chuỗi phân loại USD:
`StringFind("XAUUSD", "USD") > 0`
→ Tự động kích hoạt:
- `isUSDPair = true`
- `isUSDFirst = false`
- `isUSDSecond = true` (thuộc nhóm `xxxUSD`)
- Tương quan DXY: Ngược chiều DXY (DXY tăng mạnh → chặn BUY Vàng; DXY giảm mạnh → chặn SELL Vàng). Cơ chế này đã có sẵn trong `ReversalEngine.mqh` và `DXYTrendFollowingEngine.mqh` và sẽ tự động bao bọc bảo vệ cặp Vàng mà không cần viết thêm logic đặc thù.

### 3.9 Giao Diện Dashboard (`InfoDisplay.mqh`)
Hàm dựng Dashboard và vẽ bảng tự động co giãn theo hằng số:
`TOTAL_CONTENT_H = ... + (TOTAL_PAIRS * TABLE_ROW_H) ...`
Và duyệt vòng lặp `for(int i = 0; i < TOTAL_PAIRS; i++)`.
Khi `TOTAL_PAIRS = 7`, bảng hiển thị sẽ tự động tạo thêm dòng thứ 7 mang nhãn `XAUUSD`, cập nhật trạng thái Score, Type, Status, Debt hoàn toàn tự động và mượt mà.

---

## 4. KẾ HOẠCH KIỂM THỬ & TIÊU CHÍ HOÀN THÀNH (TESTING & VERIFICATION)

### 4.1 Biên Dịch Command-Line (CLI Compilation)
Sử dụng MetaEditor64 từ terminal PowerShell để xác nhận:
- 0 lỗi (0 errors), 0 cảnh báo (0 warnings).
- File thực thi `Yoogi 1FA.ex5` được sinh mới thành công.

### 4.2 Kiểm Tra Đơn Vị & Khởi Tạo
1. **Kiểm tra khởi tạo 7 cặp**: Log tab Expert phải in ra danh sách đủ 7 cặp với index 0 đến 6 (`XAUUSD` tại index 6).
2. **Kiểm tra nhận diện sàn**: Cặp Vàng được nhận diện đúng dù sàn đặt tên là `XAUUSD`, `GOLD`, hay có hậu tố (`XAUUSDm`, v.v.).
3. **Kiểm tra tính Pip Value**: Log ra `pip_value = 0.10`.
4. **Kiểm tra tính Lot**: Với Balance $10,000, Risk 0.5%, lệnh Forex ra 0.08 lot, lệnh Vàng ra đúng 0.04 lot.
5. **Kiểm tra DCA Step & Dynamic TP**: Step mở DCA cho Vàng dao động 60 - 120 pips ($6 - $12 giá), Dynamic TP 40 - 150 pips.

---

## 5. TỔNG KẾT FILE CẦN CHỈNH SỬA
1. `Input.mqh`: Thêm 2 tham số `InpXAUUSD_CT_Score` và `InpXAUUSD_TF_Score`.
2. `Globals.mqh`: Đổi `TOTAL_PAIRS = 7`, `DXY_CONTEXTS = 7`, thêm `"XAUUSD"` vào `StandardBaseNames`, nâng cấp `GetBrokerSymbol`, chuẩn hóa `pip_value` cho Vàng, đặt `divisor = 12.0` cho `XAUUSD`, map Required Score cho `idx = 6`.
3. `CoreLogic.mqh`: Thêm helper `GetPairDCAMinStep`, `GetPairDCAMaxStep`, `GetPairDCADefaultStep` và áp dụng cho tính toán Step DCA.
4. `DynamicExitEngine.mqh`: Thêm helper `GetPairDynamicTPMinPips`, `GetPairDynamicTPMaxPips`, `GetPairRunnerTP2MinPips`, `GetPairRunnerTP2MaxPips`, `GetPairRunnerBreathePips`, `GetPairBEMinPips` và áp dụng vào Dynamic TP và Runner Trailing.
5. `Yoogi 1FA.mq5`: Cập nhật log diagnostic khởi tạo cho XAUUSD.
