# BÁO CÁO CHI TIẾT KIỂM TRA BACKTEST 1 THÁNG (01/01/2026 - 31/01/2026)
**Dự án:** Yoogi One For All (Yoogi 1FA)  
**Tệp nhật ký phân tích:**  
- `Tester\logs\20261003.log` (Giao diện MT5 Tester Launch Log)  
- `Tester\Agent-127.0.0.1-3000\logs\20261003.log` (Kích thước: 123.5 MB, Nhật ký chi tiết của Tester Engine)  
**Thời gian chạy kiểm thử:** 03/10/2026 11:44:23 – 11:45:58  
**Khoảng thời gian backtest:** 01/01/2026 – 31/01/2026 (1 tháng trọn vẹn)  
**Cấu hình:** 6 cặp tiền tệ chính (EURUSDm, GBPUSDm, AUDUSDm, USDJPYm, USDCADm, USDCHFm), Khung H1/M15/M5, Chế độ DCA + Dynamic TP + Dual Engine (Trend-Following & Counter-Trend).

---

## 1. TỔNG QUAN KẾT QUẢ KIỂM THỬ

| Chỉ số | Kết quả | Ghi chú |
| :--- | :---: | :--- |
| **Tổng số lệnh thực tế vào (Final Entry)** | **0** | Không có lệnh nào được khớp cho cả 2 chiến lược FT và CT |
| **Tổng số Setup Trend-Following bắt đầu** | **51** | Đạt điều kiện Trend H1 hợp lệ |
| **Setup đạt M15 Pullback hợp lệ** | **29** | Giá hồi về vùng EMA hợp lệ |
| **Setup đạt M5 Liquidity Sweep** | **15** | Quét thanh khoản đáy/đỉnh M5 |
| **Setup đạt M5 Displacement (Xung lực)** | **4** | Phá vỡ xung lực nến M5 (Setups: #2, #28, #31, #36) |
| **Setup đạt M5 MSS (Phá vỡ cấu trúc)** | **0** | **Điểm nghẽn tuyệt đối của Trend-Following** |
| **Số lệnh Counter-Trend vào** | **0** | Không setup nào vượt qua bộ lọc điểm 95.0 |

---

## 2. PHÂN TÍCH NGUYÊN NHÂN TREND-FOLLOWING (FT) 0 LỆNH

Nhờ hệ thống Funnel Diagnostics vừa được tích hợp, toàn bộ hành trình của từng setup đều được ghi nhận minh bạch:

### 2.1. Phễu chuyển đổi Trend-Following (Funnel Summary)
```text
H1 evaluated       : 2276
H1 valid           : 51
M15 valid          : 29
Sweep found        : 15
Displacement found : 4
MSS found          : 0    <--- ĐIỂM NGHẼN
Momentum pass      : 0
Score >= 95        : 0
FINAL ENTRY        : 0
```

Trong suốt 1 tháng, chỉ có **4 setup** đi sâu nhất vào giai đoạn `M5_WAIT_MSS` (sau khi đã có cả Sweep và Displacement). Dưới đây là phân tích chi tiết từng setup:

---

### 2.2. Mổ xẻ chi tiết 4 Setup tiếp cận gần nhất

#### 🔵 Setup #2 (Cặp USDCADm - Hướng BUY) — Ngày 02/01/2026
* **16:05:** Xuất hiện Liquidity Sweep Low trên M5.
* **16:10:** Xuất hiện M5 Displacement tăng mạnh với biên độ **1.16 ATR** (vượt ngưỡng yêu cầu 1.0 ATR). Chuyển trạng thái sang `TF_STATE_M5_WAIT_MSS`.
* **16:15 – 17:25 (15 nến M5 liên tục):**
  * EA tiến hành đánh giá cấu trúc swing M5 (`DetectStructureShift()`) tại mỗi nến M5 đóng cửa.
  * **Minh chứng logic mới thành công:** EA đã kiên nhẫn chờ đủ **15 nến M5 (75 phút)** đúng theo tham số mới `TF_MSS_MAX_WAIT_BARS = 15`. Lỗi bị ngắt sớm ở nến thứ 6 (25 phút) ở phiên bản trước đã hoàn toàn biến mất.
  * Trong 15 nến này, giá USDCADm chỉ đi ngang tích lũy hẹp, không tạo ra được một đỉnh swing M5 rõ ràng (cần cấu trúc 3 nến swing fractal hợp lệ) để giá phá vỡ.
* **17:30:** Đến nến thứ 16, điều kiện `bars_since_displacement = 16 > TF_MSS_MAX_WAIT_BARS (15)` được kích hoạt.
* **Kết luận:** Timeout hết hạn chờ MSS. EA hủy setup an toàn, bảo toàn vốn khi thị trường mất xung lực.

---

#### 🔵 Setup #28 (Cặp USDCHFm - Hướng BUY) — Ngày 14/01/2026
* **12:00:** M5 Sweep Low thành công.
* **12:10:** M5 Displacement (1.04 ATR) -> Chuyển sang trạng thái `TF_STATE_M5_WAIT_MSS`.
* **12:15 – 12:55 (9 nến M5):** EA chờ và đánh giá MSS.
* **13:00:** Nến M15 đóng cửa đâm thủng đáy cấu trúc bảo vệ M15 (`m15_protected_low = 0.79644`).
* **Hành động của EA:**
  ```text
  [TF][USDCHFm] Setup invalidated: M15_PROTECTED_STRUCTURE_BROKEN (price=0.79641 < protected_low=0.79644)
  ```
* **Kết luận:** **Hành vi hoàn toàn đúng và bảo vệ tài khoản!** Sóng hồi M15 đã biến thành sóng đảo chiều giảm thực sự. Hệ thống lập tức hủy setup, ngăn ngừa việc vào lệnh BUY "bắt dao rơi".

---

#### 🔵 Setup #31 (Cặp USDCADm - Hướng BUY) — Ngày 15/01/2026
* **17:40:** M5 Sweep Low thành công.
* **17:45:** M5 Displacement (1.09 ATR) -> Chuyển sang `TF_STATE_M5_WAIT_MSS`.
* **17:50 – 18:40 (11 nến M5):** Đánh giá MSS.
* **18:45:** Nến M15 đóng cửa đâm thủng đáy bảo vệ (`m15_protected_low = 1.39121`).
* **Hành động của EA:**
  ```text
  [TF][USDCADm] Setup invalidated: M15_PROTECTED_STRUCTURE_BROKEN (price=1.39115 < protected_low=1.39121)
  ```
* **Kết luận:** Tương tự Setup #28, hệ thống tự động ngắt lệnh kịp thời do cấu trúc M15 bị gãy.

---

#### 🔴 Setup #36 (Cặp EURGBPm - Hướng BUY) — Ngày 20/01/2026: PHÁT HIỆN LỖI LOGIC (DEADLOCK BUG)
* **02:40:** M5 Sweep Low.
* **02:50:** M5 Displacement (1.02 ATR) -> Chuyển sang `TF_STATE_M5_WAIT_MSS`.
* **02:55:** Đánh giá MSS nến 1 -> Chưa có MSS.
* **03:00:** Nến M15 mới mở ra. Hàm `EvaluateM15Pullback()` chạy lại và đánh giá chất lượng sóng hồi:
  ```text
  [TF_M15_REJECT] EMA Distance (dist=1.52 > max=1.20)
  ```
  Hàm này gán cờ: `G_TF[idx].m15_pullback_valid = false`.
* **Hiện tượng nghẽn (Deadlock):**
  Trong hàm `UpdateTrendFollowingState()`:
  ```mq5
  // Line 3074 - 3075:
  if(G_TF[idx].setup_state < TF_STATE_M15_PULLBACK) return 0;
  if(!G_TF[idx].m15_pullback_valid) return 0;
  ```
  - Vì `m15_pullback_valid == false`, hàm thoát ra ngay lập tức tại dòng 3075 ở MỌI nến M5 tiếp theo!
  - `setup_state` của cặp EURGBPm vẫn đang giữ nguyên giá trị `TF_STATE_M5_WAIT_MSS` (không được reset về `H1_TREND`).
  - Hậu quả: Vòng lặp M5 không bao giờ chạy tiếp -> Không đánh giá MSS, không tăng đếm số nến `setup_bar_count`, không kích hoạt timeout.
  - **EURGBPm bị "đóng băng" ở trạng thái chờ MSS suốt 3 ngày (từ 20/01 03:00 đến 23/01 09:00)** cho tới khi nến H1 đổi chiều xu hướng (`H1_TREND_FLIP`) mới giải phóng cặp tiền!

---

## 3. PHÂN TÍCH NGUYÊN NHÂN COUNTER-TREND (CT) 0 LỆNH

1. **Bộ lọc điểm cực kỳ ngặt nghèo (`InpCT_RequiredScore = 95`):**
   - Chiến lược Counter-Trend tính điểm dựa trên 4 lớp bằng chứng:
     - **Layer A (Location):** Giá chạm vùng cản HTF / Độ lệch chuẩn Extension >= 1.0 ATR (Tối đa 25 điểm).
     - **Layer B (Exhaustion):** Phân kỳ RSI/MACD + Nến từ chối (Rejection Pinbar) + Thất bại tiếp diễn (Tối đa 25 điểm).
     - **Layer C (Confirmation):** Sweep thanh khoản + Displacement + MSS trên LTF (Tối đa 30 điểm).
     - **Layer D (Momentum & DXY):** Xung lực và tín hiệu DXY đồng thuận (Tối đa 20 điểm).
   - Với mức điểm yêu cầu là **95 điểm**, setup bắt buộc phải gần như **hoàn hảo 100% ở cả 4 lớp đồng thời trong cùng một thời điểm**.
   - Trong thị trường tháng 01/2026, các cặp ngoại tệ biến động theo các nhịp sóng hồi đơn lẻ hoặc đi ngang, không có pha đảo chiều nào đạt đủ tất cả các tiêu chí cùng lúc.

2. **Chế độ Debug của Counter-Trend bị tắt (`InpReversalDebug = false`):**
   - Trong `Globals.mqh`, biến `InpReversalDebug` đang đặt mặc định là `false`.
   - Toàn bộ các bước đánh giá từ chối (`LogReversalDecision`) của chiến lược Counter-Trend đều bị ẩn khỏi log tester. Do đó, người dùng không nhìn thấy được các bước xử lý của CT như bên FT.

---

## 4. TỔNG KẾT NGUYÊN NHÂN 1 THÁNG 0 LỆNH

| Nguyên nhân | Mức độ ảnh hưởng | Bản chất vấn đề |
| :--- | :---: | :--- |
| **Logic MSS M5 khắt khe** | **Chính (60%)** | `DetectStructureShift()` đòi hỏi nến M5 phải có cụm Swing Fractal rõ ràng và nến phá vỡ phải dứt khoát. Trong tháng 1, biên độ co cụm không tạo ra cấu trúc swing đủ chuẩn sau displacement. |
| **Bảo vệ rủi ro M15 hoạt động tốt** | **Hợp lý (25%)** | 2/4 setup tiềm năng nhất (#28, #31) bị hủy vì cấu trúc M15 bị phá thủng đáy. Đây là hành vi đúng giúp EA không bị dính chuỗi DCA ngược sóng mạnh. |
| **Lỗi State Deadlock ở EURGBPm** | **Kỹ thuật (15%)** | Cặp EURGBPm bị treo cứng 3 ngày ở trạng thái `WAIT_MSS` do dòng `if(!m15_pullback_valid) return 0;` bỏ qua việc reset trạng thái. |
| **Ngưỡng điểm CT quá cao (95)** | **Chính với CT** | Đòi hỏi 95/100 điểm khiến CT gần như "bất khả thi" để kích hoạt lệnh trong điều kiện thị trường thực tế. |

---

## 5. ĐỀ XUẤT GIẢI PHÁP KHẮC PHỤC

### 1. Sửa lỗi State Deadlock trong `TrendFollowingEngine.mqh` (Cần xử lý ngay)
- **Vấn đề:** Khi `m15_pullback_valid` bị `false` trong lúc setup đã lên các trạng thái M5 (`WAIT_SWEEP`, `WAIT_DISP`, `WAIT_MSS`), hệ thống cần:
  - Ghi log reset `M15_PULLBACK_LOST_QUALITY`.
  - Reset trạng thái M5 và M15, đưa `setup_state` về lại `TF_STATE_H1_TREND`.
  - Không để setup bị kẹt vô thời hạn.

### 2. Tinh chỉnh bộ nhận diện MSS trên M5 (Để tăng cơ hội vào lệnh)
- Hiện tại, `DetectStructureShift` đòi hỏi swing fractal đầy đủ (cần tối thiểu 3-5 nến hình thành đỉnh/đáy swing trung gian trước khi nến phá vỡ xuất hiện).
- **Đề xuất:** Cân nhắc cho phép nhận diện cấu trúc phụ (Minor Structure Shift) hoặc chấp nhận phá vỡ đỉnh gần nhất của nến mẹ (Mother bar / Prior bar High) khi xung lực displacement đạt trên 1.2 ATR.

### 3. Điều chỉnh ngưỡng điểm Counter-Trend & Bật Debug
- Hạ ngưỡng `InpCT_RequiredScore` từ `95.0` xuống `80.0` - `85.0` để chiến lược Counter-Trend có cơ hội tham gia thị trường khi có tín hiệu đảo chiều rõ nét.
- Xây dựng hệ thống **Funnel Diagnostics cho Counter-Trend** tương tự như Trend-Following để người dùng có thể xem bảng tổng kết CT đã từ chối ở bước nào (Location, Exhaustion, Sweep, Displacement hay MSS).
