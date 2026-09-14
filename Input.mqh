//+------------------------------------------------------------------+
//|                                                    Input.mqh     |
//|                                                Yoogi Trading     |
//|      Tệp chứa tham số đầu vào                                    |
//|      (ĐÃ XÓA TOÀN BỘ INPUT GIAO DIỆN THEO YÊU CẦU)               |
//+------------------------------------------------------------------+
#property strict

// Hiện tại không có Input nào được khai báo.
// Toàn bộ cấu hình giao diện đã được chuyển thành Hằng số (CONST) 
// bên trong file InfoDisplay.mqh

input group "=== TÙY CHỈNH CHUNG ==="
input double InpSetBalance = 0.0; // Balance tham chiếu để tính lot (0 = dùng ACCOUNT_BALANCE thực tế)

input group "=== CHẤT LƯỢNG TÍN HIỆU ==="
input double InpReversalMinScore = 70.0;             // Score tối thiểu cho entry (Reversal Quality)

//--- Tester Withdrawal Settings ---
input group "--- Tester Withdrawal Settings ---"
input bool   InpTesterWithdrawalEnabled   = false;   // Bật chế độ rút tiền ảo trong Tester
input double InpTesterBaseBalance         = 10000.0; // Số dư gốc mong muốn duy trì ($)
input double InpTesterWithdrawThreshold   = 1000.0;  // Lợi nhuận đạt được để kích hoạt rút ($)
input double InpTesterWithdrawAmount      = 1000.0;  // Số tiền rút mỗi lần (0 = rút toàn bộ phần dư)