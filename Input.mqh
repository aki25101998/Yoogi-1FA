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

input group "=== ENTRY ENGINE ==="
input bool InpEnableCounterTrend    = true;   // Counter-Trend Engine (ON/OFF)
input bool InpEnableTrendFollowing  = true;   // Trend-Following Engine (ON/OFF)
input bool InpEnableDCA             = true;   // Enable DCA = true / false

input group "=== DYNAMIC EXIT ENGINE ==="
input bool   InpEnableDynamicTP          = true;   // Dynamic TP (false = fixed 60 pip)
input int    InpDynamicTP_MinPips        = 15;     // Min TP (pips)
input int    InpDynamicTP_MaxPips        = 120;    // Max TP (pips)
input double InpDynamicTP_ATRMultiplier  = 2.0;    // ATR Multiplier for TP
input bool   InpEnableTPCompression      = true;   // TP Compression (adapt TP mid-trade)
input bool   InpEnableRunnerMode         = true;   // Runner Mode (FT only, trail profits)

//--- Tester Withdrawal Settings ---
input group "--- Tester Withdrawal Settings ---"
input bool   InpTesterWithdrawalEnabled   = false;   // Bật chế độ rút tiền ảo trong Tester
input double InpTesterBaseBalance         = 10000.0; // Số dư gốc mong muốn duy trì ($)
input double InpTesterWithdrawThreshold   = 1000.0;  // Lợi nhuận đạt được để kích hoạt rút ($)
input double InpTesterWithdrawAmount      = 1000.0;  // Số tiền rút mỗi lần (0 = rút toàn bộ phần dư)