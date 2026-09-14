# YOOGI-1FA: HIẾN PHÁP HỆ THỐNG (CONSTITUTION)

Tài liệu này đóng vai trò là "Hiến pháp" cốt lõi của Yoogi-1FA. Mọi bản cập nhật, chỉnh sửa trong tương lai đều phải tuân thủ nghiêm ngặt các nguyên tắc và logic được định nghĩa tại đây.

---

## ĐIỀU 1: LUẬT BACKUP BẮT BUỘC (GIT PUSH RULE)

1. **Bắt buộc**: Bất kỳ thay đổi, cập nhật, hay sửa lỗi nào đối với source code (dù là nhỏ nhất) đều phải được Agent (hệ thống) TỰ ĐỘNG commit và push lên GitHub ngay lập tức sau khi hoàn thành task. Tuyệt đối không cần đợi người dùng nhắc nhở lệnh "push".
2. **Quy trình**: 
   - Sử dụng lệnh Git hoặc workflow `/backup` (đã được cấu hình trong `.agents/workflows/backup.md`) để tự động hóa quá trình này.
   - Message commit phải miêu tả ngắn gọn và chính xác thay đổi.
3. **Mục tiêu**: Đảm bảo source code không bao giờ bị mất, dễ dàng rollback nếu cập nhật gây lỗi, và đồng bộ hóa công việc.

---

## ĐIỀU 2: TRIẾT LÝ HỆ THỐNG (REVERSAL TRADING)

1. **Reversal Engine**: Hệ thống tìm kiếm các điểm đảo chiều có xác suất cao dựa trên sự hội tụ của nhiều nguồn thông tin độc lập (Location, Exhaustion, Sweep, Displacement, Structure, Momentum, DXY).
2. **Khách quan và Đa chiều**: Không đánh đồng các tín hiệu đo lường cùng một hiện tượng. Các tín hiệu phải được nhóm (GROUP) theo bản chất thực sự của chúng.
3. **Master Entry Quality**: Không dùng giới hạn DCA để che đậy điểm yếu của Master Entry. Master Entry phải thật sự chất lượng.
4. **Không giới hạn DCA**: Auto Strategy tuyệt đối không được giới hạn số lượng DCA hay số vòng. DCA là cơ chế gỡ lệnh (Recovery mechanism) chạy độc lập với Entry.

---

## ĐIỀU 3: KIẾN TRÚC REVERSAL ENGINE V2 (4 LAYERS)

Để quyết định một Master Entry, EA phải phân tích thị trường qua 4 tầng (Layers) tuần tự:

### LAYER A: LOCATION (Vị thế)
- *Câu hỏi*: "Giá có đang ở một vùng cực đoan đáng để bắt đảo chiều không?"
- **Extension (Distance from EMA)**: Giá phải vượt ra khỏi mức cân bằng (EMA) một khoảng cách tối thiểu (đo bằng x ATR). Chia làm 3 mức: Normal (5đ), Strong (10đ), Extreme (15đ).
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

### LAYER D: EXTERNAL CONFIRMATION (Bộ lọc bên ngoài)
- *Câu hỏi*: "Các yếu tố ngoại cảnh có ủng hộ không?"
- **Momentum (10đ)**: CCI và Range Filter ủng hộ hướng đảo chiều.
- **DXY Filter**: Chỉ áp dụng cho các cặp có USD (VD: EURUSD, AUDUSD). DXY phải đi ngược chiều setup. Nếu DXY đồng pha (chống lại setup) -> Cấm lệnh (Block). (Các cặp không có USD như EURGBP thì bỏ qua).

---

## ĐIỀU 4: HARD REQUIREMENTS (Điều kiện bắt buộc)

Cho dù tổng điểm (Score) có cao đến đâu, Master Entry **bắt buộc** phải vượt qua 7 vòng kiểm duyệt (Hard Requirements) sau đây. Điểm số KHÔNG THỂ thay thế các chốt chặn này:

1. **HTF Location**: Phải nằm trong vùng Reversal Zone hợp lệ (xu hướng lớn cho phép bắt ngược).
2. **Exhaustion Evidence**: Phải có ít nhất 1 dấu hiệu kiệt sức (Divergence / Rejection / Failed Cont).
3. **Structure Shift (MSS)**: Cấu trúc phải bị phá vỡ (Nếu bật yêu cầu MSS).
4. **Min Score**: Tổng điểm Reversal phải >= `InpReversalMinScore` (mặc định 70).
5. **DXY Alignment**: DXY không được phép chống lại setup (đối với cặp USD).
6. **Bar Closed**: Chỉ sử dụng nến đã đóng (`shift = 1`) để không bao giờ repaint.
7. **Timeout / Invalidation**: Setup chưa quá thời hạn an toàn (Safety Expiration) và chưa bị phá vỡ cấu trúc (Invalidated).

---

## ĐIỀU 5: STATE MACHINE (CỖ MÁY TRẠNG THÁI 8 BƯỚC)

Setup không diễn ra trong 1 nến mà là 1 quá trình tiến triển. Trạng thái (State) được lưu trữ và tiến dần qua các bước:

- **STATE 0 (NO_SETUP)**: Chờ đợi HTF Location.
- **STATE 1 (LOCATION)**: Đã vào vùng cực đoan. Chờ Exhaustion.
- **STATE 2 (EXHAUSTION)**: Đã có dấu hiệu kiệt sức. Chờ Liquidity Sweep.
- **STATE 3 (LIQUIDITY)**: Đã có quét thanh khoản. Chờ Displacement.
- **STATE 4 (REVERSAL_CONF)**: Lực đẩy xuất hiện. Chờ xác nhận MSS.
- **STATE 5 (STRUCTURE_SHIFT)**: MSS thành công. Chờ Retest (nếu bật).
- **STATE 6 (RETEST)**: Retest hoàn tất. Chuẩn bị tính điểm và lọc Hard Requirements.
- **STATE 7 (ENTRY_READY)**: Passed toàn bộ! Bắn lệnh Master Entry.

---

## ĐIỀU 6: QUẢN LÝ SETUP VÀ HỦY BỎ (INVALIDATION)

1. **Không Timeout cứng**: KHÔNG sử dụng các timeout ngắn hạn hạn chế setup (như 25 bars). Một setup đảo chiều tốt có thể tốn nhiều thời gian.
2. **Safety Expiration**: Chỉ sử dụng ngưỡng timeout rất lớn (VD: 150 bars) như một cơ chế "fail-safe" chống kẹt state do bug.
3. **Invalidation (Hủy setup logic)**: Setup bị reset về 0 (NO_SETUP) nếu "Giả thuyết đảo chiều" không còn hợp lệ. Ví dụ: Đang setup BUY (giá đi xuống sâu), nhưng giá tiếp tục giảm cực mạnh, phá thủng luôn swing low được bảo vệ mà không hề có nến rút chân -> Setup BUY thất bại -> Hủy setup.
4. **Không tự xẹp điểm (Decay)**: Không trừ điểm setup chỉ vì thời gian trôi qua.

---

## ĐIỀU 7: KIẾN TRÚC AUTO-ONLY VÀ QUẢN LÝ VỐN

1. **Auto-Only Architecture**: EA hiện tại đã được thiết kế lại thành hệ thống 100% AUTO. Mọi logic, tham số, cấu trúc rẽ nhánh liên quan đến Manual Mode (như `InpStrategyMode`, `MaxOrders`, `Manual TP/SL`...) đã bị loại bỏ vĩnh viễn và **tuyệt đối không được khôi phục lại**.
2. **InpSetBalance**: Bắt buộc phải được giữ nguyên là biến User Input. Hành vi quy định:
   - `InpSetBalance == 0`: Master/DCA lot được tính theo `ACCOUNT_BALANCE` thực tế.
   - `InpSetBalance > 0`: Master/DCA lot được tính theo giá trị tham chiếu mà người dùng thiết lập.
3. **Master Order**: Cố định TP Auto = 60 pips, SL = 0.
4. **Không giới hạn DCA (Unlimited DCA)**: Khẳng định lại lần 2, DCA tuyệt đối không được gài các chốt chặn `MaxOrders`, giới hạn tổng position, giới hạn theo step, hay dùng thủ thuật ẩn để block DCA. Step cố định = 30 pip, Multiplier = 1.3.

---

## TỔNG KẾT

Mọi lập trình viên, AI Assistant hay Sub-agent khi tác động vào Yoogi-1FA đều phải:
1. Đọc và hiểu CONSTITUTION này trước tiên.
2. Code theo định hướng Đa chiều + Hard Requirements.
3. Commit lên Github NGAY LẬP TỨC sau khi sửa đổi code thành công (tuân thủ **Điều 1**).
