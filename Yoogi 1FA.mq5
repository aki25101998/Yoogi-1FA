//+------------------------------------------------------------------+
//|                                                  Yoogi DCA.mq5   |
//|                                                  Yoogi Trading   |
//|                                        https://Bom.so/Yoogi      |
//| (v12.3 - Yoogi One For All - Timer Optimized 3s - No Lag)        |
//+------------------------------------------------------------------+
#property version   "v33.0"
#define YOOGI_BUILD_VERSION "TF_MOMENTUM_10BAR"
#property description "💼 Chào mừng bạn đến với Yoogi One For All – Trade For Living\n\n"
#property description "Thông tin cần biết cho lần đầu sử dụng:\n\n"
#property description "1. Mở Tool > Options > Expert Advisors.\n\n"
#property description "2. Tích vào ô 'Allow WebRequest for listed URL'.\n\n"
#property description "3. Thêm địa chỉ: script.google.com\n\n"
#property description "4. EA chỉ hoạt động khi 10.000$ < Balance < 500.000$\n\n"
#property description "5. Gắn EA vào chart EURUSD để chạy\n\n"
#property description "6. Min balance 10k, max balance 500k để khởi chạy EA\n\n"
#property description "Vui lòng liên hệ Zalo | Telegram: 0346134678 để được kích hoạt\n\n"
#property description "Nhấp vào Bom.so/Yoogi ở trên cùng để truy cập trọn bộ công cụ của Yoogi\n\n";
#property link "Bom.so/Yoogi"

// LIÊN KẾT TỆP
// Lưu ý: Đặt Input.mqh lên trước để load tham số đầu vào
#include "Input.mqh"
#include "Globals.mqh"
#include "Indicators.mqh"
#include "ReversalEngine.mqh"
#include "DXYTrendFollowingEngine.mqh"
#include "TrendFollowingEngine.mqh"
#include "DynamicExitEngine.mqh"
#include "CoreLogic.mqh"
#include "InfoDisplay.mqh"
#include "Security.mqh"

//+------------------------------------------------------------------+
//| Hàm khởi tạo EA                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- 1. CHỐT CHẶN: BẮT BUỘC GẮN VÀO EURUSD ---
   // Kiểm tra xem tên chart hiện tại có chứa chữ "EURUSD" không
   string current_sym = _Symbol;
   StringToUpper(current_sym);

   if(StringFind(current_sym, "EURUSD") < 0)
   {
      // [CẬP NHẬT] Thay đổi nội dung thông báo lỗi
      string msg = "LỖI CÀI ĐẶT:\n\n"
                   " Yoogi One For All yêu cầu phải được gắn trên biểu đồ EURUSD.\n"
                   "(Để đảm bảo nhận diện đúng tên sàn và tối ưu tốc độ xử lý)\n\n"
                   "Vui lòng tắt và gắn lại sang chart EURUSD.";
      MessageBox(msg, "Sai Biểu Đồ", MB_OK|MB_ICONERROR);
      return(INIT_FAILED); // Dừng hoạt động ngay
   }

   // --- 2. KIỂM TRA BẢN QUYỀN ---
   if(!CheckLicense()) { return(INIT_FAILED); }

   // --- 3. KHỞI TẠO LOGIC ĐA CẶP ---
   InitGlobals();    // Khởi tạo 7 cặp tiền và Risk % cứng
   InitIndicators(); // Khởi tạo chỉ báo cho 7 cặp
   InitAllTradeProfiles(); // Khởi tạo Dynamic Exit Profiles
   CreateDisplay();  // Vẽ giao diện Dashboard

   // --- [TỐI ƯU HÓA HIỆU SUẤT] ---
   // Sử dụng Timer 3 giây: Đủ để cập nhật thông tin mà không làm lag máy.
   // Dashboard sẽ tự động làm mới mỗi 3s bất chấp thị trường có chạy hay không.
   EventSetTimer(3);

   // [CẬP NHẬT] Thay đổi nội dung log in ra tab Expert
   Print(">>> Yoogi One For All đã khởi động trên EURUSD.");
   Print(">>> Chế độ: 7 Pairs Fixed - Optimized Timer (3s).");
   
   Print("\n[DXY_TF_INIT]");
   Print("ENGINE=ACTIVE");
   Print("ENGINE_VERSION=TF_DXY_V2\n");

   if(TF_MOMENTUM_MAX_BARS != 10)
   {
      Print("[FATAL] TF_MOMENTUM_MAX_BARS IS NOT 10");
      return(INIT_FAILED);
   }

   Print("==================================================");
   Print("[YOOGI_BUILD_DIAGNOSTIC]");
   Print("==================================================");
   PrintFormat("VERSION=%s", TF_ENGINE_VERSION);
   PrintFormat("TF_MOMENTUM_MAX_BARS=%d", TF_MOMENTUM_MAX_BARS);
   PrintFormat("CT_REQUIRED_SCORE=%.0f", InpCT_RequiredScore);
   PrintFormat("TF_REQUIRED_SCORE=%.0f", InpTF_RequiredScore);
   PrintFormat("TF_MAX_EVENT_BARS=%d", TF_MAX_EVENT_BARS);
   
    Print("[DCA] Mode: ENABLED (ALWAYS ON)");
    PrintFormat("[DCA] Step: %d pips", InpKhoangMoPip);
    
    // --- DYNAMIC EXIT ENGINE DIAGNOSTIC ---
    Print("");
    Print("[DYNAMIC-TP] Mode: ENABLED (ALWAYS ON)");
    PrintFormat("[DYNAMIC-TP] MinTP: %d pips", InpDynamicTP_MinPips);
    PrintFormat("[DYNAMIC-TP] MaxTP: %d pips", InpDynamicTP_MaxPips);
    PrintFormat("[DYNAMIC-TP] ATR_Multiplier: %.2f", InpDynamicTP_ATRMultiplier);
    Print("[DYNAMIC-TP] Compression: ON (ALWAYS)");
    Print("[DYNAMIC-TP] Runner (FT): ON (ALWAYS)");
    PrintFormat("[DYNAMIC-TP] Fallback TP: %d pips", InpMasterTPPips);
    
    Print("==================================================\n");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Hàm hủy EA                                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Hủy Timer để giải phóng tài nguyên CPU
   EventKillTimer();

   DeleteDisplay();
   DeinitIndicators();
   Print(">>> Yoogi DCA đã dừng hoạt động.");
}

//+------------------------------------------------------------------+
//| Hàm xử lý mỗi tick giá mới (Logic Trade)                         |
//+------------------------------------------------------------------+
void OnTick()
{
   // Chỉ chạy logic giao dịch khi có tick mới (để khớp lệnh nhanh nhất)
   // KHÔNG đặt hàm UpdateDisplay() ở đây để tránh vẽ lại quá nhiều lần gây lag.
   ManagePairs();
}

//+------------------------------------------------------------------+
//| Hàm xử lý theo thời gian (Logic Giao Diện)                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Cập nhật giao diện mỗi 3 giây một lần.
   // Giúp Dashboard mượt mà, chính xác mà không tốn tài nguyên.
   UpdateDisplay();
}
//+------------------------------------------------------------------+