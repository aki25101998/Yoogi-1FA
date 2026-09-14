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

// Khai báo kiểu lựa chọn Auto/Manual
enum ENUM_STRATEGY_MODE {
   STRATEGY_AUTO,   // Tự động (Mặc định)
   STRATEGY_MANUAL  // Thủ công (Tuỳ chỉnh bên dưới)
};

input ENUM_STRATEGY_MODE InpStrategyMode = STRATEGY_AUTO; // Chọn chế độ chiến thuật
input bool InpUseDXYReference = true; // Sử dụng lọc tham chiếu DXY
input bool InpEnableBalanceLimit = true; // Giới hạn Balance (10k-500k) để vào lệnh

input group "=== CÀI ĐẶT THỦ CÔNG (MANUAL MODE) ==="
input double InpManual_Balance  = 0.0;   // Set Balance tính Lot (0 = Auto)
input bool   InpManual_DCA      = true;  // Bật/tắt DCA
input int    InpManual_MaxOrders= 0;     // Giới hạn số lệnh của chuỗi (Vd 2 = 1 Master + 1 DCA), 0 = Không giới hạn
input int    InpManual_SL_Pips  = 0;     // SL Pips (0 = Tắt tính năng)
input int    InpManual_TP_Pips  = 0;     // Take Profit (pips, 0 = không dùng)
input int    InpManual_StepPips = 0;     // Khoảng cách nhồi DCA (pips, 0 = dùng mặc định 30)

// Cặp 1: EURUSD
input bool   InpEURUSD_On   = true; // EURUSD Bật/Tắt
input double InpEURUSD_Risk = 0.4; // EURUSD % Lot
input ENUM_TIMEFRAMES InpEURUSD_HTF = PERIOD_H1; // EURUSD TF Lớn (Xu hướng)
input ENUM_TIMEFRAMES InpEURUSD_LTF = PERIOD_M5; // EURUSD TF Nhỏ (Entry)

// Cặp 2: AUDUSD
input bool   InpAUDUSD_On   = true; // AUDUSD Bật/Tắt
input double InpAUDUSD_Risk = 0.6; // AUDUSD % Lot
input ENUM_TIMEFRAMES InpAUDUSD_HTF = PERIOD_H1; // AUDUSD TF Lớn (Xu hướng)
input ENUM_TIMEFRAMES InpAUDUSD_LTF = PERIOD_M5; // AUDUSD TF Nhỏ (Entry)

// Cặp 3: USDCAD
input bool   InpUSDCAD_On   = true; // USDCAD Bật/Tắt
input double InpUSDCAD_Risk = 0.4; // USDCAD % Lot
input ENUM_TIMEFRAMES InpUSDCAD_HTF = PERIOD_H1; // USDCAD TF Lớn (Xu hướng)
input ENUM_TIMEFRAMES InpUSDCAD_LTF = PERIOD_M5; // USDCAD TF Nhỏ (Entry)

// Cặp 4: EURGBP
input bool   InpEURGBP_On   = true; // EURGBP Bật/Tắt
input double InpEURGBP_Risk = 0.5; // EURGBP % Lot
input ENUM_TIMEFRAMES InpEURGBP_HTF = PERIOD_H1; // EURGBP TF Lớn (Xu hướng)
input ENUM_TIMEFRAMES InpEURGBP_LTF = PERIOD_M5; // EURGBP TF Nhỏ (Entry)

// Cặp 5: USDCHF
input bool   InpUSDCHF_On   = true; // USDCHF Bật/Tắt
input double InpUSDCHF_Risk = 0.3; // USDCHF % Lot
input ENUM_TIMEFRAMES InpUSDCHF_HTF = PERIOD_H1; // USDCHF TF Lớn (Xu hướng)
input ENUM_TIMEFRAMES InpUSDCHF_LTF = PERIOD_M5; // USDCHF TF Nhỏ (Entry)

//--- Reversal Engine V2 Settings ---
input group "=== REVERSAL ENGINE V2 ==="
input bool   InpUseReversalEngine = true;           // Bật/tắt Reversal Engine
input int    InpReversal_ATR_Period = 14;            // ATR Period
input int    InpReversal_EquilibriumPeriod = 50;     // EMA Period (Equilibrium)
input double InpReversal_Extension_Normal = 1.0;     // Extension Level: Normal (x ATR)
input double InpReversal_Extension_Strong = 1.5;     // Extension Level: Strong (x ATR)
input double InpReversal_Extension_Extreme = 2.0;    // Extension Level: Extreme (x ATR)
input int    InpReversal_SwingLeft = 2;              // Swing Left Bars
input int    InpReversal_SwingRight = 2;             // Swing Right Bars
input int    InpReversal_LookbackBars = 100;         // Lookback Bars
input bool   InpReversal_RequireStructureShift = true; // Bắt buộc MSS
input bool   InpReversal_RequireClosedBars = true;   // Chỉ dùng candle đã đóng

input group "=== LIQUIDITY SWEEP ==="
input bool   InpEnableLiquiditySweep = true;         // Bật/tắt Liquidity Sweep
input int    InpLiquiditySweepLookback = 50;         // Số bar tìm swing cho sweep
input double InpLiquiditySweepToleranceATR = 0.1;    // Dung sai quét (x ATR)

input group "=== DISPLACEMENT ==="
input bool   InpEnableDisplacement = true;           // Bật/tắt Displacement
input double InpDisplacementMinBodyATR = 0.8;        // Body tối thiểu (x ATR)
input double InpDisplacementClosePercent = 70.0;     // Close position (% range)

input group "=== MSS QUALITY ==="
input double InpMSSMinBreakATR = 0.2;                // Khoảng phá tối thiểu (x ATR)

input group "=== RETEST ==="
input bool   InpEnableRetest = true;                 // Bật/tắt Retest module
input bool   InpRequireRetest = false;               // Bắt buộc Retest trước entry?
input double InpRetestToleranceATR = 0.5;            // Dung sai retest (x ATR)
input int    InpRetestMaxBars = 10;                  // Số bar tối đa chờ retest

input group "=== SWING & SETUP ==="
input double InpMinSwingDistanceATR = 0.5;           // Khoảng cách swing tối thiểu (x ATR)
input int    InpSafetyMaxSetupBars = 150;            // Safety expiration only - not a trading filter

input group "=== SCORE & ENTRY ==="
input double InpReversalMinScore = 70.0;             // Score tối thiểu cho entry
input double InpReversal_HighScore = 80.0;           // Score cao (entry ưu tiên)

input group "=== DEBUG ==="
input bool   InpReversalDebug = false;               // Bật/tắt debug logging chi tiết

//--- Tester Withdrawal Settings ---
input group "--- Tester Withdrawal Settings ---"
input bool   InpTesterWithdrawalEnabled   = false;   // Bật chế độ rút tiền ảo trong Tester
input double InpTesterBaseBalance         = 10000.0; // Số dư gốc mong muốn duy trì ($)
input double InpTesterWithdrawThreshold   = 1000.0;  // Lợi nhuận đạt được để kích hoạt rút ($)
input double InpTesterWithdrawAmount      = 1000.0;  // Số tiền rút mỗi lần (0 = rút toàn bộ phần dư)