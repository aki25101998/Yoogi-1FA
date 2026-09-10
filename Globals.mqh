//+------------------------------------------------------------------+
//|                                                      Globals.mqh |
//|                                                    Yoogi Trading |
//|   Biến toàn cục & Cấu hình hệ thống (v14.0 - MTF Dual Signal)   |
//|   (Multi-Timeframe: HTF + LTF Signal Confirmation)               |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

// ==================================================================
// HẰNG SỐ & CẤU HÌNH GIỚI HẠN
// ==================================================================
#define TOTAL_PAIRS 5   // Tổng cộng 5 cặp tiền
#define DXY_CONTEXTS 5 // So luong DXY context dong bo voi 5 cap
#define EA_MAGIC_NUMBER 1

// --- GIỚI HẠN HOẠT ĐỘNG (Dựa trên Virtual Balance) ---
#define LIMIT_MIN_VIRTUAL 10000.0   // Tối thiểu 10k để kích hoạt
#define LIMIT_MAX_VIRTUAL 500000.0  // Max limit an toàn

// ==================================================================
// --- CẤU HÌNH CHIẾN LƯỢC (HARD-CODED CONSTANTS) ---
// ==================================================================
// Các thông số này được cố định, người dùng không thể chỉnh sửa
const bool   InpAutoSignalTrading = true;
const bool   InpAutoManualTrading = true;
const bool   InpAllowBuy          = true;
const bool   InpAllowSell         = true;

const double InpHeSoLot           = 1.3;
const int    InpKhoangMoPip       = 30;
const int    InpMasterTPPips      = 60;

const bool   InpUseSmartTrim      = true;
const int    InpTrimTriggerOrders = 3;
const double InpTrimPercentage    = 100.0;

// ==================================================================
// STRUCT QUẢN LÝ TRẠNG THÁI TỪNG CẶP
// ==================================================================
enum ENUM_MARKET_REGIME { 
   REGIME_UNKNOWN = 0, 
   REGIME_TREND_BULL, 
   REGIME_TREND_BEAR, 
   REGIME_SIDEWAY, 
   REGIME_EXHAUSTION 
};

struct PairContext
{
   // --- Reversal Engine State ---
   ENUM_MARKET_REGIME regime;
   bool             htf_reversal_zone;
   bool             ltf_divergence;
   bool             ltf_mss;
   double           reversal_score;
   int              state_machine;
   double           last_swing_high;
   double           last_swing_low;
   

   string           symbol;       // Tên thực tế (VD: EURUSD.pro)
   string           base_name;    // Tên chuẩn (VD: EURUSD)
   ENUM_TIMEFRAMES  htf;          // Timeframe lớn (xu hướng)
   ENUM_TIMEFRAMES  ltf;          // Timeframe nhỏ (entry)
   int              digits;
   double           point;
   double           pip_value;

   // --- Cấu hình Risk (Gán cứng trong Init) ---
   double           risk_percent;
   bool             enabled;       // Bật/Tắt cặp tiền (Manual mode)

   // --- LTF Indicator (Entry - logic gốc) ---
   int      handle_cci;
   bool     isReadyForBuy;
   bool     isReadyForSell;

   // --- LTF Filter State ---
   bool     g_inited_filt;
   double   filt_prev;
   double   filt_prev_for_calc;
   int      upCount;
   int      dnCount;
   int      lastCond;

   datetime last_bar_time;

   // --- HTF Signal State (bộ indicator riêng cho TF lớn) ---
   int      htf_handle_cci;           // CCI handle cho HTF
   bool     htf_isReadyForBuy;        // CCI Trap BUY trên HTF
   bool     htf_isReadyForSell;       // CCI Trap SELL trên HTF
   bool     htf_g_inited_filt;        // Range Filter đã init trên HTF?
   double   htf_filt_prev;
   double   htf_filt_prev_for_calc;
   int      htf_upCount;
   int      htf_dnCount;
   int      htf_lastCond;
   datetime htf_last_bar_time;        // New bar tracking cho HTF
   int      htf_trap_signal;          // Bẫy HTF: 1(BUY), -1(SELL), 0(NONE)

   // --- DXY TRAP STATE ---
   int      trapSignal;       // Tín hiệu bẫy: 1(BUY), -1(SELL), 0(NONE)
   bool     isUSDPair;        // Cặp tiền có chứa USD?
   bool     isUSDFirst;       // USD nằm đầu? (USDCAD)
   bool     isUSDSecond;      // USD nằm sau? (EURUSD)
   int      dxy_map_index;    // Index vào G_DXY[] (-1 nếu không dùng)

   // --- Persistence (Bộ nhớ) ---
   double   realized_bleed_loss; // Nợ tích lũy
   double   locked_balance;      // Balance dùng để tính lot (nếu cần)
   int      virtual_step;        // Bước DCA hiện tại
   ulong    active_chain_id;     // ID chuỗi đang chạy
};

PairContext G_Pairs[TOTAL_PAIRS];
CTrade  trade;

// --- DXY GLOBALS (DUAL TF) ---
PairContext G_DXY_HTF[DXY_CONTEXTS];     // DXY context trên TF lớn
PairContext G_DXY_LTF[DXY_CONTEXTS];     // DXY context trên TF nhỏ
int         G_DXY_TrapSignal_HTF[DXY_CONTEXTS]; // DXY trap signal HTF
int         G_DXY_TrapSignal_LTF[DXY_CONTEXTS]; // DXY trap signal LTF
string DXY_SYMBOL = "DXY";             // Se duoc tu dong phat hien boi AutoDetectDXY()
bool   g_dxy_available = false;         // True neu DXY duoc tim thay tren san

// UI State
int     activeChainsCount = 0;

// ==================================================================
// DANH SÁCH TÊN CHUẨN (5 CẶP)
// ==================================================================
string StandardBaseNames[TOTAL_PAIRS] = {
   "EURUSD", "AUDUSD", "USDCAD", "EURGBP", "USDCHF"
};

// ==================================================================
// AUTO-DETECT SUFFIX (HỖ TRỢ MỌI CHART)
// ==================================================================
string GetBrokerSymbol(string std_name)
{
   // 1. Nếu tên chuẩn chạy được ngay
   if(SymbolSelect(std_name, true)) return std_name;

   // 2. Nếu không, tìm quy luật từ chart hiện tại
   string current_chart_sym = _Symbol;

   // List base để detect suffix
   string CommonBases[] = {
      "EURUSD", "AUDUSD", "USDCAD", "EURGBP", "USDCHF"
   };

   string prefix = "";
   string suffix = "";
   bool   detected = false;

   for(int i = 0; i < ArraySize(CommonBases); i++)
   {
      string base = CommonBases[i];
      int pos = StringFind(current_chart_sym, base);

      if(pos >= 0)
      {
         prefix = StringSubstr(current_chart_sym, 0, pos);
         suffix = StringSubstr(current_chart_sym, pos + StringLen(base));
         detected = true;
         break;
      }
   }

   if(detected)
   {
      string candidate = prefix + std_name + suffix;
      if(SymbolSelect(candidate, true)) return candidate;
   }

   // Fallback: Quét Market Watch
   for(int i = 0; i < SymbolsTotal(false); i++)
   {
      string s = SymbolName(i, false);
      if(StringFind(s, std_name) >= 0) return s;
   }

   return std_name;
}

// ==================================================================
// TU DONG PHAT HIEN SYMBOL DXY TREN SAN
// ==================================================================
string AutoDetectDXY()
{
   // Danh sach cac ten DXY pho bien
   string candidates[] = {
      "DXY", "USDX", "USDIndex", "DX", "DOLLAR_INDX", "US_Dollar"
   };

   // 1. Thu truc tiep ten chuan (co the co suffix cua san)
   for(int c = 0; c < ArraySize(candidates); c++)
   {
      string result = GetBrokerSymbol(candidates[c]);
      if(SymbolSelect(result, true))
      {
         PrintFormat("DXY Auto-Detect: Tim thay '%s' (tu '%s')", result, candidates[c]);
         return result;
      }
   }

   // 2. Quet toan bo Market Watch tim symbol chua tu khoa
   string keywords[] = { "DXY", "USDX", "DOLLAR", "USDIndex" };

   for(int i = 0; i < SymbolsTotal(false); i++)
   {
      string sym = SymbolName(i, false);
      string sym_upper = sym;
      StringToUpper(sym_upper);

      for(int k = 0; k < ArraySize(keywords); k++)
      {
         string kw = keywords[k];
         StringToUpper(kw);

         if(StringFind(sym_upper, kw) >= 0)
         {
            if(SymbolSelect(sym, true))
            {
               PrintFormat("DXY Auto-Detect: Tim thay '%s' (keyword '%s')", sym, keywords[k]);
               return sym;
            }
         }
      }
   }

   // 3. Fallback
   Print("DXY Auto-Detect: KHONG TIM THAY! Bo loc DXY se duoc TAT.");
   return "";
}

// ==================================================================
// KHỞI TẠO GLOBAL
// ==================================================================
void InitGlobals()
{
   Print(">>> KHOI TAO YOOGI ONE FOR ALL (MODE: MTF DUAL SIGNAL + DXY FILTER)...");

   for(int i=0; i<TOTAL_PAIRS; i++)
   {
      G_Pairs[i].base_name = StandardBaseNames[i];
      G_Pairs[i].symbol    = GetBrokerSymbol(G_Pairs[i].base_name);

      if(!SymbolSelect(G_Pairs[i].symbol, true))
         PrintFormat("LOI: Khong tim thay cap %s!", G_Pairs[i].symbol);

      G_Pairs[i].digits    = (int)SymbolInfoInteger(G_Pairs[i].symbol, SYMBOL_DIGITS);
      G_Pairs[i].point     = SymbolInfoDouble(G_Pairs[i].symbol, SYMBOL_POINT);

      if (G_Pairs[i].digits == 5 || G_Pairs[i].digits == 3)
         G_Pairs[i].pip_value = 10.0 * G_Pairs[i].point;
      else
         G_Pairs[i].pip_value = 1.0 * G_Pairs[i].point;

      if(InpStrategyMode == STRATEGY_MANUAL)
      {
         // --- CHE DO THU CONG: Doc HTF/LTF tu Input ---
         if(G_Pairs[i].base_name == "EURUSD")      { G_Pairs[i].risk_percent = InpEURUSD_Risk; G_Pairs[i].htf = InpEURUSD_HTF; G_Pairs[i].ltf = InpEURUSD_LTF; G_Pairs[i].enabled = InpEURUSD_On; }
         else if(G_Pairs[i].base_name == "AUDUSD") { G_Pairs[i].risk_percent = InpAUDUSD_Risk; G_Pairs[i].htf = InpAUDUSD_HTF; G_Pairs[i].ltf = InpAUDUSD_LTF; G_Pairs[i].enabled = InpAUDUSD_On; }
         else if(G_Pairs[i].base_name == "USDCAD") { G_Pairs[i].risk_percent = InpUSDCAD_Risk; G_Pairs[i].htf = InpUSDCAD_HTF; G_Pairs[i].ltf = InpUSDCAD_LTF; G_Pairs[i].enabled = InpUSDCAD_On; }
         else if(G_Pairs[i].base_name == "EURGBP") { G_Pairs[i].risk_percent = InpEURGBP_Risk; G_Pairs[i].htf = InpEURGBP_HTF; G_Pairs[i].ltf = InpEURGBP_LTF; G_Pairs[i].enabled = InpEURGBP_On; }
         else if(G_Pairs[i].base_name == "USDCHF") { G_Pairs[i].risk_percent = InpUSDCHF_Risk; G_Pairs[i].htf = InpUSDCHF_HTF; G_Pairs[i].ltf = InpUSDCHF_LTF; G_Pairs[i].enabled = InpUSDCHF_On; }
         else { G_Pairs[i].risk_percent = 0.0; G_Pairs[i].htf = PERIOD_H1; G_Pairs[i].ltf = PERIOD_M5; G_Pairs[i].enabled = false; }
      }
      else
      {
         // --- CHE DO TU DONG: Mac dinh H1/M5 cho tat ca, doc HTF/LTF tu Input ---
         G_Pairs[i].htf = InpEURUSD_HTF;  // Mac dinh lay tu EURUSD input
         G_Pairs[i].ltf = InpEURUSD_LTF;
         
         // Override neu user set rieng cho tung cap
         if(G_Pairs[i].base_name == "EURUSD")      { G_Pairs[i].htf = InpEURUSD_HTF; G_Pairs[i].ltf = InpEURUSD_LTF; }
         else if(G_Pairs[i].base_name == "AUDUSD") { G_Pairs[i].htf = InpAUDUSD_HTF; G_Pairs[i].ltf = InpAUDUSD_LTF; }
         else if(G_Pairs[i].base_name == "USDCAD") { G_Pairs[i].htf = InpUSDCAD_HTF; G_Pairs[i].ltf = InpUSDCAD_LTF; }
         else if(G_Pairs[i].base_name == "EURGBP") { G_Pairs[i].htf = InpEURGBP_HTF; G_Pairs[i].ltf = InpEURGBP_LTF; }
         else if(G_Pairs[i].base_name == "USDCHF") { G_Pairs[i].htf = InpUSDCHF_HTF; G_Pairs[i].ltf = InpUSDCHF_LTF; }

         if(G_Pairs[i].base_name == "EURUSD")      G_Pairs[i].risk_percent = 0.4;
         else if(G_Pairs[i].base_name == "AUDUSD") G_Pairs[i].risk_percent = 0.6;
         else if(G_Pairs[i].base_name == "EURGBP") G_Pairs[i].risk_percent = 0.5;
         else if(G_Pairs[i].base_name == "USDCAD") G_Pairs[i].risk_percent = 0.4;
         else if(G_Pairs[i].base_name == "USDCHF") G_Pairs[i].risk_percent = 0.3;
         else G_Pairs[i].risk_percent = 0.0;
         G_Pairs[i].enabled = true; // Auto mode: tat ca cap deu bat
      }

      // Reset LTF State
      G_Pairs[i].handle_cci = INVALID_HANDLE;
      G_Pairs[i].isReadyForBuy = false;
      G_Pairs[i].isReadyForSell = false;
      G_Pairs[i].g_inited_filt = false;
      G_Pairs[i].last_bar_time = 0;
      
      // Reset Reversal Engine State
      G_Pairs[i].regime = REGIME_UNKNOWN;
      G_Pairs[i].htf_reversal_zone = false;
      G_Pairs[i].ltf_divergence = false;
      G_Pairs[i].ltf_mss = false;
      G_Pairs[i].reversal_score = 0.0;
      G_Pairs[i].state_machine = 0;
      G_Pairs[i].last_swing_high = 0.0;
      G_Pairs[i].last_swing_low = 0.0;


      // Reset HTF State
      G_Pairs[i].htf_handle_cci = INVALID_HANDLE;
      G_Pairs[i].htf_isReadyForBuy = false;
      G_Pairs[i].htf_isReadyForSell = false;
      G_Pairs[i].htf_g_inited_filt = false;
      G_Pairs[i].htf_filt_prev = 0.0;
      G_Pairs[i].htf_filt_prev_for_calc = 0.0;
      G_Pairs[i].htf_upCount = 0;
      G_Pairs[i].htf_dnCount = 0;
      G_Pairs[i].htf_lastCond = 0;
      G_Pairs[i].htf_last_bar_time = 0;
      G_Pairs[i].htf_trap_signal = 0;

      // Reset Persistence
      G_Pairs[i].realized_bleed_loss = 0.0;
      G_Pairs[i].locked_balance = 0.0;
      G_Pairs[i].virtual_step = 0;
      G_Pairs[i].active_chain_id = 0;

      // --- PHAT HIEN USD & MAP DXY ---
      G_Pairs[i].trapSignal = 0;
      G_Pairs[i].dxy_map_index = -1;
      string bn = G_Pairs[i].base_name;

      if(StringFind(bn, "USD") == 0)
      {
         // USDxxx (VD: USDCAD)
         G_Pairs[i].isUSDPair  = true;
         G_Pairs[i].isUSDFirst = true;
         G_Pairs[i].isUSDSecond = false;
      }
      else if(StringFind(bn, "USD") > 0)
      {
         // xxxUSD (VD: EURUSD, AUDUSD, USDCHF)
         G_Pairs[i].isUSDPair  = true;
         G_Pairs[i].isUSDFirst = false;
         G_Pairs[i].isUSDSecond = true;
      }
      else
      {
         G_Pairs[i].isUSDPair  = false;
         G_Pairs[i].isUSDFirst = false;
         G_Pairs[i].isUSDSecond = false;
      }

      // Map DXY context 1:1 theo index cua cap tien
      if(G_Pairs[i].isUSDPair)
      {
         G_Pairs[i].dxy_map_index = i;
      }

      PrintFormat("   + Load Pair [%d]: %s (Risk: %.1f%%) - HTF: %s / LTF: %s - USD: %s",
                  i, G_Pairs[i].symbol, G_Pairs[i].risk_percent,
                  EnumToString(G_Pairs[i].htf), EnumToString(G_Pairs[i].ltf),
                  (G_Pairs[i].isUSDPair ? (G_Pairs[i].isUSDFirst ? "USDxxx" : "xxxUSD") : "No"));
   }

   // --- TU DONG PHAT HIEN VA KHOI TAO DXY (DUAL TF) ---
   DXY_SYMBOL = AutoDetectDXY();

   if(DXY_SYMBOL == "")
   {
      g_dxy_available = false;
      Print("DXY Filter: TAT (Broker khong co DXY). Tat ca cap tien se trade binh thuong.");
   }
   else
   {
      g_dxy_available = true;
      string dxy_broker = DXY_SYMBOL;

      for (int i = 0; i < DXY_CONTEXTS; i++)
      {
         // --- DXY HTF Context ---
         G_DXY_HTF[i].symbol = dxy_broker;
         G_DXY_HTF[i].base_name = DXY_SYMBOL;
         G_DXY_HTF[i].htf = G_Pairs[i].htf;
         G_DXY_HTF[i].ltf = G_Pairs[i].htf; // DXY HTF dung TF lon cua cap tien
         G_DXY_HTF[i].handle_cci = INVALID_HANDLE;
         G_DXY_HTF[i].isReadyForBuy = false;
         G_DXY_HTF[i].isReadyForSell = false;
         G_DXY_HTF[i].g_inited_filt = false;
         G_DXY_HTF[i].last_bar_time = 0;
         G_DXY_TrapSignal_HTF[i] = 0;

         // --- DXY LTF Context ---
         G_DXY_LTF[i].symbol = dxy_broker;
         G_DXY_LTF[i].base_name = DXY_SYMBOL;
         G_DXY_LTF[i].htf = G_Pairs[i].ltf;
         G_DXY_LTF[i].ltf = G_Pairs[i].ltf; // DXY LTF dung TF nho cua cap tien
         G_DXY_LTF[i].handle_cci = INVALID_HANDLE;
         G_DXY_LTF[i].isReadyForBuy = false;
         G_DXY_LTF[i].isReadyForSell = false;
         G_DXY_LTF[i].g_inited_filt = false;
         G_DXY_LTF[i].last_bar_time = 0;
         G_DXY_TrapSignal_LTF[i] = 0;
      }

      Print("DXY Filter: Symbol = ", dxy_broker, " | Contexts: 5 (Dual TF per pair)");
   }

   activeChainsCount = 0;
}

// ==================================================================
// HÀM HELPER TÍNH TOÁN
// ==================================================================

// Tính tổng nợ toàn hệ thống (Dùng để check điều kiện vào lệnh)
double GetTotalSystemDebt()
{
   double debt = 0.0;
   for(int i=0; i<TOTAL_PAIRS; i++)
      debt += G_Pairs[i].realized_bleed_loss;
   return debt;
}

bool SymbolHas(string symbol_chart, string check)
{
   if (StringFind(symbol_chart, check) >= 0) return true;
   return false;
}

double NormalizeLot(string sym, double v)
{
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   if (step <= 0.0) step = 0.01;
   v = MathMax(vmin, MathMin(v, vmax));
   return round(v / step) * step;
}

// Tính TP
double CalculateAutoTP(string sym, double balance)
{
   string s = sym;
   StringToUpper(s);
   double percentage = 0.005; // Mặc định chung

   // Nhóm biến động thấp/trung bình
   if(SymbolHas(s, "EURUSD") || SymbolHas(s, "USDCHF"))
      percentage = 0.004;

   // Nhóm biến động khác
   else if(SymbolHas(s, "AUDUSD"))
      percentage = 0.006;

   // Các nhóm còn lại giữ 0.005 (USDCAD, EURGBP...)
   else
      percentage = 0.005;

   return balance * percentage;
}

// [QUAN TRỌNG] Logic tính Lot mới (Hỗ trợ tắt Risk = 0)
double CalculateAutoLot(int idx, double balance)
{
   // 1. Lấy thông tin từ struct đã map
   string sym      = G_Pairs[idx].symbol;
   string base     = G_Pairs[idx].base_name;
   double risk_pct = G_Pairs[idx].risk_percent;

   // --- NẾU RISK <= 0, TRẢ VỀ 0 ĐỂ KHÔNG MỞ LỆNH ---
   if(risk_pct <= 0.00001) return 0.0;

   // 2. Xác định Divisor
   double divisor = 6.0; // Mặc định an toàn

   if(base == "USDCAD")      divisor = 4.48;
   else if(base == "EURGBP") divisor = 7.64;

   // 3. Tính toán: (Balance * (Risk% / 100)) / Divisor
   double raw_lot = (balance * (risk_pct / 100.0)) / (divisor * 100.0);

   // Nếu kết quả tính toán quá nhỏ (gần như bằng 0), cũng trả về 0
   if(raw_lot <= 0.0) return 0.0;

   return NormalizeLot(sym, raw_lot);
}

// Persistence names
string GetVarName_Bleed(string sym, ulong chain_id) { return "Yoogi_Bleed_" + sym + "_" + IntegerToString(chain_id); }
string GetVarName_Step(string sym, ulong chain_id)  { return "Yoogi_Step_" + sym + "_" + IntegerToString(chain_id); }
string GetVarName_LockedBal(string sym, ulong chain_id) { return "Yoogi_Bal_" + sym + "_" + IntegerToString(chain_id); }

// Position Helpers
bool SelectPosByTicket(ulong ticket)
{
   if (ticket == 0) return false;
   return PositionSelectByTicket(ticket);
}
ulong GetPositionMagic(ulong ticket)
{
   if(!SelectPosByTicket(ticket)) return 0;
   return (ulong)PositionGetInteger(POSITION_MAGIC);
}
bool IsTradable(string sym)
{
   long mode = 0;
   if (!SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, mode)) return false;
   bool trade_allowed = (mode != SYMBOL_TRADE_MODE_DISABLED);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   return (trade_allowed && bid > 0.0 && ask > 0.0);
}
double ProfitOf(ulong ticket)
{
   if (!SelectPosByTicket(ticket)) return 0.0;
   return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
}
//+------------------------------------------------------------------+
