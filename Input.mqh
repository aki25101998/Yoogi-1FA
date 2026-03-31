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

input group "=== CÀI ĐẶT THỦ CÔNG (MANUAL MODE) ==="
input int    InpManual_TP_Pips = 0;  // Take Profit (pips, 0 = không dùng)
input int    InpManual_StepPips = 0; // Khoảng cách nhồi DCA (pips, 0 = dùng mặc định 30)

// Cặp 1: EURUSD
input bool   InpEURUSD_On   = true; // EURUSD Bật/Tắt
input double InpEURUSD_Risk = 0.4; // EURUSD % Lot
input ENUM_TIMEFRAMES InpEURUSD_TF = PERIOD_H4; // EURUSD Timeframe

// Cặp 2: AUDUSD
input bool   InpAUDUSD_On   = true; // AUDUSD Bật/Tắt
input double InpAUDUSD_Risk = 0.6; // AUDUSD % Lot
input ENUM_TIMEFRAMES InpAUDUSD_TF = PERIOD_H4; // AUDUSD Timeframe

// Cặp 3: USDCAD
input bool   InpUSDCAD_On   = true; // USDCAD Bật/Tắt
input double InpUSDCAD_Risk = 0.4; // USDCAD % Lot
input ENUM_TIMEFRAMES InpUSDCAD_TF = PERIOD_H2; // USDCAD Timeframe

// Cặp 4: EURGBP
input bool   InpEURGBP_On   = true; // EURGBP Bật/Tắt
input double InpEURGBP_Risk = 0.5; // EURGBP % Lot
input ENUM_TIMEFRAMES InpEURGBP_TF = PERIOD_H4; // EURGBP Timeframe

// Cặp 5: USDCHF
input bool   InpUSDCHF_On   = true; // USDCHF Bật/Tắt
input double InpUSDCHF_Risk = 0.3; // USDCHF % Lot
input ENUM_TIMEFRAMES InpUSDCHF_TF = PERIOD_H4; // USDCHF Timeframe