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
input double InpCT_RequiredScore         = 100.0;  // Counter-Trend Required Score
input double InpTF_RequiredScore         = 100.0;  // Trend-Following Required Score

input int  InpMaxDCAPerChain        = 3;      // Max DCA per chain (0 = no DCA)
input int  InpDCA_MinStepPips       = 30;     // Min Dynamic Step (pips)
input int  InpDCA_MaxStepPips       = 60;     // Max Dynamic Step (pips)
input double InpDCA_Step_ATRMultiplier = 1.0; // ATR Multiplier cho Dynamic Step

input group "=== DYNAMIC EXIT ENGINE ==="
input int    InpDynamicTP_MinPips        = 15;     // Min TP (pips)
input int    InpDynamicTP_MaxPips        = 90;     // Max TP (pips)
input double InpDynamicTP_ATRMultiplier  = 2.0;    // ATR Multiplier for TP

// Cố định các cờ hệ thống luôn bật
bool InpEnableCounterTrend      = true;
bool InpEnableTrendFollowing    = true;
bool InpEnableDynamicTP         = true;
bool InpEnableTPCompression     = true;
bool InpEnableRunnerMode        = true;

//--- Tester Withdrawal Settings ---
input group "--- Tester Withdrawal Settings ---"
input bool   InpTesterWithdrawalEnabled   = false;   // Bật chế độ rút tiền ảo trong Tester
input double InpTesterBaseBalance         = 10000.0; // Số dư gốc mong muốn duy trì ($)
input double InpTesterWithdrawThreshold   = 1000.0;  // Lợi nhuận đạt được để kích hoạt rút ($)
input double InpTesterWithdrawAmount      = 1000.0;  // Số tiền rút mỗi lần (0 = rút toàn bộ phần dư)