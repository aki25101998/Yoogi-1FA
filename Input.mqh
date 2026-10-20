//+------------------------------------------------------------------+
//|                                                    Input.mqh     |
//|                                                Yoogi Trading     |
//|      Tệp chứa tham số đầu vào                                    |
//|      (ĐÃ XÓA TOÀN BỘ INPUT GIAO DIỆN THEO YÊU CẦU)               |
//+------------------------------------------------------------------+
#property strict

// ================================================================
// USER INPUTS
// Chỉ giữ lại các tham số người dùng được phép tùy chỉnh.
// Các cấu hình chiến lược khác được cố định nội bộ.
// ================================================================

input group "=== TÙY CHỈNH CHUNG ==="
input double InpSetBalance = 0.0; // Balance tham chiếu để tính lot (0 = dùng ACCOUNT_BALANCE thực tế)
input double InpRiskPercent = 0.5; // % Balance dùng để tính Lot (ví dụ: 0.5 = 0.5%)

input group "=== ENTRY REQUIRED SCORE (COUNTER-TREND) ==="
input double InpEURUSD_CT_Score = 100.0;  // [EURUSD] Counter-Trend Required Score
input double InpAUDUSD_CT_Score = 100.0;  // [AUDUSD] Counter-Trend Required Score
input double InpUSDCAD_CT_Score = 95.0;  // [USDCAD] Counter-Trend Required Score
input double InpGBPUSD_CT_Score = 95.0;  // [GBPUSD] Counter-Trend Required Score
input double InpNZDUSD_CT_Score = 95.0;  // [NZDUSD] Counter-Trend Required Score

input group "=== ENTRY REQUIRED SCORE (TREND-FOLLOWING) ==="
input double InpEURUSD_TF_Score = 100.0; // [EURUSD] Trend-Following Required Score
input double InpAUDUSD_TF_Score = 100.0; // [AUDUSD] Trend-Following Required Score
input double InpUSDCAD_TF_Score = 100.0; // [USDCAD] Trend-Following Required Score
input double InpGBPUSD_TF_Score = 100.0; // [GBPUSD] Trend-Following Required Score
input double InpNZDUSD_TF_Score = 100.0; // [NZDUSD] Trend-Following Required Score
// (Ghi chú: EURGBP là cặp chéo không có DXY bảo vệ nên mặc định điểm luôn luôn là 100.0, không cần input)




//--- Tester Withdrawal Settings ---
input group "--- Tester Withdrawal Settings ---"
input bool   InpTesterWithdrawalEnabled   = false;   // Bật chế độ rút tiền ảo trong Tester
input double InpTesterBaseBalance         = 10000.0; // Số dư gốc mong muốn duy trì ($)
input double InpTesterWithdrawThreshold   = 1000.0;  // Lợi nhuận đạt được để kích hoạt rút ($)
input double InpTesterWithdrawAmount      = 1000.0;  // Số tiền rút mỗi lần (0 = rút toàn bộ phần dư)