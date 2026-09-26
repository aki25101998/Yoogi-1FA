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
const bool   InpAllowBuy          = true;
const bool   InpAllowSell         = true;

const double InpHeSoLot           = 1.3;
const int    InpKhoangMoPip       = 30;
const int    InpMasterTPPips      = 60;

// DCA & Dynamic TP (Hardcoded)
const int    InpMaxDCAPerChain        = 3;
const int    InpDCA_MinStepPips       = 30;
const int    InpDCA_MaxStepPips       = 60;
const double InpDCA_Step_ATRMultiplier = 1.0;
const int    InpDynamicTP_MinPips        = 15;
const int    InpDynamicTP_MaxPips        = 90;
const double InpDynamicTP_ATRMultiplier  = 2.0;

// System Flags (Hardcoded)
const bool InpEnableCounterTrend      = true;
const bool InpEnableTrendFollowing    = true;
const bool InpEnableDynamicTP         = true;
const bool InpEnableTPCompression     = true;
const bool InpEnableRunnerMode        = true;
const bool   InpUseSmartTrim      = false; // Tạm thời disable trimming của Yoogi Bleed cũ theo spec Section 26
const int    InpTrimTriggerOrders = 3;
const double InpTrimPercentage    = 100.0;

//==================================================
// INTERNAL REVERSAL ENGINE CONFIGURATION
// DO NOT EXPOSE TO USER
//==================================================
const bool   InpEnableBalanceLimit = true;

const bool   InpUseDXYReference = true;
const bool   InpUseReversalEngine = true;
const int    InpReversal_ATR_Period = 14;
const int    InpReversal_EquilibriumPeriod = 50;
const double InpReversal_Extension_Normal = 1.0;
const double InpReversal_Extension_Strong = 1.5;
const double InpReversal_Extension_Extreme = 2.0;
const int    InpReversal_SwingLeft = 2;
const int    InpReversal_SwingRight = 2;
const int    InpReversal_LookbackBars = 100;
const bool   InpReversal_RequireStructureShift = true;
const bool   InpReversal_RequireClosedBars = true;
const bool   InpEnableLiquiditySweep = true;
const int    InpLiquiditySweepLookback = 50;
const double InpLiquiditySweepToleranceATR = 0.1;
const bool   InpEnableDisplacement = true;
const double InpDisplacementMinBodyATR = 0.8;
const double InpDisplacementClosePercent = 70.0;
const double InpMSSMinBreakATR = 0.2;
const bool   InpEnableRetest = true;
const bool   InpRequireRetest = false;
const double InpRetestToleranceATR = 0.5;
const int    InpRetestMaxBars = 10;
const double InpMinSwingDistanceATR = 0.5;
const int    InpSafetyMaxSetupBars = 150;
const double ENTRY_REQUIRED_SCORE = 100.0; // Hard requirement - Score phải đạt 100/100 để entry
const int    InpExhaustionMaxAgeBars = 10;
const int    InpSweepMaxAgeBars = 10;
const int    InpDisplacementMaxAgeBars = 5;
const int    InpMSSMaxAgeBars = 15;
const bool   InpReversalDebug = false;
const double CT_MAX_ENTRY_DISTANCE_ATR = 3.0;  // CT: Don't entry if price moved > 3x LTF ATR from MSS break level
const int    CT_MAX_EVENT_SPREAD_BARS  = 12;   // CT: Sweep→Displacement→MSS must complete within 12 LTF bars

// ==================================================================
// STRUCT QUẢN LÝ TRẠNG THÁI TỪNG CẶP
// ==================================================================
#define STATE_NO_SETUP        0
#define STATE_HTF_LOCATION    1
#define STATE_EXHAUSTION      2
#define STATE_LIQUIDITY       3
#define STATE_REVERSAL_CONF   4
#define STATE_STRUCTURE_SHIFT 5
#define STATE_RETEST          6
#define STATE_ENTRY_READY     7

enum ENUM_MARKET_REGIME { 
   REGIME_UNKNOWN = 0, 
   REGIME_TREND_BULL, 
   REGIME_TREND_BEAR, 
   REGIME_SIDEWAY, 
   REGIME_EXHAUSTION 
};

struct PairContext
{
   // --- Reversal Engine V2 State ---
   ENUM_MARKET_REGIME regime;
   double           htf_ext;
   bool             htf_div;
   bool             htf_exh;
   bool             htf_reversal_zone;
   bool             htf_conflict;
   
   bool             ltf_divergence;
   bool             ltf_mss;
   bool             ltf_exh;
   int              ltf_cci_recov;
   int              ltf_rf_state;
   
   double           reversal_score;
   int              state_machine;
   string           rev_status;
   double           last_swing_high;
   double           last_swing_low;
   
   // --- Reversal Engine V2 New Fields ---
   int              setup_direction;      // 1=BUY, -1=SELL, 0=NONE
   int              setup_start_bar;      // Bar index when setup started
   int              setup_bar_count;      // LTF bars since setup began
   
   // Layer B - Exhaustion
   bool             exh_divergence;       // Divergence detected
   bool             exh_rejection;        // Candle rejection detected
   bool             exh_failed_cont;      // Failed continuation detected
   int              exh_divergence_age;
   int              exh_rejection_age;
   int              exh_failed_cont_age;
   
   // Layer C - Confirmation
   bool             conf_sweep;           // Liquidity sweep detected
   bool             conf_displacement;    // Displacement detected
   bool             conf_mss;             // Structure shift confirmed (quality)
   bool             conf_retest;          // Retest confirmed
   int              conf_sweep_age;
   int              conf_displacement_age;
   int              conf_mss_age;
   double           sweep_level;          // Swing level that was swept
   double           mss_break_level;      // Swing level that was broken (MSS)
   int              retest_bar_count;     // Bars waited for retest
   
   // Qualified Swings
   double           qual_swing_high;      // Qualified swing high (filtered)
   double           qual_swing_low;       // Qualified swing low (filtered)
   double           prev_swing_high;      // Previous valid swing high (for MSS context)
   double           prev_swing_low;       // Previous valid swing low (for MSS context)
   
   int              qual_swing_high_idx;  // Bar index (shift) of qual_swing_high
   int              qual_swing_low_idx;   // Bar index (shift) of qual_swing_low
   int              prev_swing_high_idx;  // Bar index (shift) of prev_swing_high
   int              prev_swing_low_idx;   // Bar index (shift) of prev_swing_low
   
   // Score Breakdown
   double           score_location;
   double           score_exhaustion;
   double           score_sweep;
   double           score_displacement;
   double           score_mss;
   double           score_momentum;
   

   string           symbol;       // Tên thực tế (VD: EURUSD.pro)
   string           base_name;    // Tên chuẩn (VD: EURUSD)
   ENUM_TIMEFRAMES  htf;          // Timeframe lớn (xu hướng)
   ENUM_TIMEFRAMES  ltf;          // Timeframe nhỏ (entry)
   int              digits;
   double           point;
   double           pip_value;

   // --- Cấu hình Risk (Gán cứng trong Init) ---
   double           risk_percent;
   bool             enabled;       // Bật/Tắt cặp tiền

   // --- LTF Indicator (Entry - logic gốc) ---
   int      handle_cci;
   bool     isReadyForBuy;
   bool     isReadyForSell;
   datetime cci_signal_time;

   // --- LTF Filter State ---
   bool     g_inited_filt;
   double   filt_prev;
   double   filt_prev_for_calc;
   int      upCount;
   int      dnCount;
   int      lastCond;
   datetime rf_signal_time;

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

   // --- Persistence (Bộ nhớ) - Legacy per-strategy (backward compat only) ---
   double   ct_realized_bleed_loss;
   double   ft_realized_bleed_loss;
   double   dual_realized_bleed_loss;
   
   int      ct_recovery_level;
   int      ft_recovery_level;
   int      dual_recovery_level;
   
   int      ct_dca_sequence;
   int      ft_dca_sequence;
   int      dual_dca_sequence;
   
   // --- SYSTEM-LEVEL Recovery State (AUTHORITATIVE per symbol) ---
   double   system_debt;              // Unified debt across all strategies
   int      system_recovery_level;    // Recovery level counter
   int      system_dca_sequence;      // Global DCA sequence across strategies
   bool     system_recovery_active;   // true when system_debt > 0
   bool     system_debt_partially_recovered; // true after first partial recovery (next chain targets 100%)
   
   // --- Active Chain Context (Reset mỗi chain) ---
   string   active_chain_strategy; // "CT", "FT", or "DUAL"
   double   locked_balance;        // Balance dùng để tính lot (nếu cần)
   int      chain_position_count;  // Số position hiện tại trong active chain (1..InpMaxDCAPerChain)
   int      chain_start_dca_seq;   // Global DCA sequence của position đầu tiên trong active chain
   int      chain_end_dca_seq;     // Global DCA sequence của position mới nhất trong active chain
   int      chain_step_pips;       // Dynamic Step (pips) cố định cho toàn bộ chuỗi
   ulong    active_chain_id;       // ID chuỗi đang chạy (0 nếu không có chuỗi)
};

PairContext G_Pairs[TOTAL_PAIRS];

// ==================================================================
// TREND-FOLLOWING ENGINE CONTEXT
// ==================================================================

// --- Trend-Following Engine States ---
#define TF_STATE_NONE                 0
#define TF_STATE_H1_TREND             1
#define TF_STATE_M15_PULLBACK         2
#define TF_STATE_M5_WAIT_SWEEP        3
#define TF_STATE_M5_WAIT_DISPLACEMENT 4
#define TF_STATE_M5_WAIT_MSS          5
#define TF_STATE_ENTRY_READY          6

// --- Trend-Following Internal Constants ---
const int    TF_MAX_EVENT_BARS         = 5;     // Sweep→Displacement→MSS must be within 5 M5 bars
const double TF_MAX_ENTRY_DISTANCE_ATR = 2.0;   // Don't chase price beyond 2x M5 ATR
const int    TF_MAX_SETUP_BARS         = 100;   // Setup timeout in M5 bars
const int    TF_MOMENTUM_MAX_BARS      = 10;    // Momentum timeout in M5 bars (max window, entry on first PASS)
const int    TF_PULLBACK_MAX_BARS      = 30;    // M15 pullback max age
const double TF_PULLBACK_MIN_DEPTH_ATR = 0.3;   // Min pullback depth (ATR)
const double TF_PULLBACK_MAX_DEPTH_ATR = 3.0;   // Max pullback depth before reversal
const int    TF_SLOPE_LOOKBACK         = 5;     // Bars to measure EMA slope
const double TF_SIDEWAY_ATR_RATIO      = 0.5;   // Below this = sideway
const bool   TF_REQUIRE_RETEST         = false; // Module ready, default OFF
const int    TF_DXY_MAX_AGE_BARS_HTF   = 48;    // DXY HTF signal max age (bars)
const int    TF_DXY_MAX_AGE_BARS_LTF   = 288;   // DXY LTF signal max age (bars)

// --- Internal Constants for DXY TF Engine Freshness ---
const int    DXY_TF_H1_MAX_AGE_BARS    = 3;
const int    DXY_TF_M15_MAX_AGE_BARS   = 4;
const int    DXY_TF_M5_MAX_AGE_BARS    = 3;

struct TrendFollowingContext
{
   // H1 Trend Regime
   int    h1_trend_direction;     // 1=BUY, -1=SELL, 0=NONE
   double h1_trend_quality;       // 0-20
   bool   h1_ema_aligned;         // EMA20 > EMA50 (BUY) or EMA20 < EMA50 (SELL)
   bool   h1_slope_positive;      // EMA50 slope > 0 (BUY) or < 0 (SELL)
   bool   h1_price_above_ema;     // Price above EMA50 (BUY) or below (SELL)
   bool   h1_structure_valid;     // HH/HL or LL/LH
   bool   h1_not_sideway;         // Not in sideway range

   // M15 Pullback
   bool   m15_pullback_valid;
   double m15_pullback_quality;   // 0-20
   int    m15_pullback_bar_count;
   double m15_pullback_depth;     // In ATR units
   double m15_ema_distance;       // Distance to EMA in ATR units
   datetime m15_pullback_start_time;
   double m15_impulse_high;
   double m15_impulse_low;
   datetime m15_impulse_start_time;
   datetime m15_impulse_end_time;
   datetime m15_protected_time;
   datetime m15_protected_confirmed_time;

   // M5 Entry Evidence
   bool   m5_sweep;
   bool   m5_displacement;
   bool   m5_mss;
   bool   m5_momentum_cci;
   bool   m5_momentum_rf;
   bool   m5_momentum_pc;
   
   // Real timestamp tracking for chronological validation
   datetime m5_sweep_time;
   datetime m5_displacement_time;
   datetime m5_mss_time;
   datetime m5_momentum_time;
   datetime m5_momentum_start_time;
   datetime m5_momentum_cci_time;
   datetime m5_momentum_rf_time;
   datetime m5_momentum_pc_time;
   
   double m5_sweep_price;
   double m5_displacement_price;
   
   int    m5_sweep_age;
   int    m5_displacement_age;
   int    m5_mss_age;
   int    m5_momentum_bars_elapsed; // Closed M5 bars since MSS (incremented only on new closed bar)
   datetime m5_momentum_last_closed_time; // Last processed closed M5 candle time for momentum tracking
   double m5_mss_break_level;
   double m5_sweep_level;

   // Score Breakdown
   double score_h1_trend;         // max 20
   double score_m15_pullback;     // max 20
   double score_sweep;            // max 10
   double score_displacement;     // max 10
   double score_mss;              // max 10
   double score_event_coherence;  // max 10
   double score_momentum;         // max 10
   double score_entry_distance;   // max 10
   double total_score;            // must be exactly 100

   // State Machine
   int    setup_state;            // TF_STATE_*
   int    setup_bar_count;        // Total bars since setup started
   string status;                 // Human-readable status

   // Invalidation
   double h1_protected_structure; // Level that invalidates H1 trend
   double m15_protected_low;      // For BUY pullback invalidation
   double m15_protected_high;     // For SELL pullback invalidation

   // New bar tracking
   datetime m15_last_bar_time;
   datetime m5_last_bar_time_tf;  // Separate from Counter-Trend's M5 tracking
};

TrendFollowingContext G_TF[TOTAL_PAIRS];
CTrade  trade;

// --- DXY GLOBALS (DUAL TF) ---
PairContext G_DXY_HTF[DXY_CONTEXTS];     // DXY context trên TF lớn
PairContext G_DXY_LTF[DXY_CONTEXTS];     // DXY context trên TF nhỏ
int         G_DXY_TrapSignal_HTF[DXY_CONTEXTS]; // DXY trap signal HTF
int         G_DXY_TrapSignal_LTF[DXY_CONTEXTS]; // DXY trap signal LTF
datetime    G_DXY_TrapSignalTime_HTF[DXY_CONTEXTS]; // Time when HTF signal was generated
datetime    G_DXY_TrapSignalTime_LTF[DXY_CONTEXTS]; // Time when LTF signal was generated

struct DXYTrendContext
{
    string symbol;

    ENUM_TIMEFRAMES htf;
    ENUM_TIMEFRAMES mtf;
    ENUM_TIMEFRAMES ltf;

    int h1_direction;
    bool h1_structure_valid;
    bool h1_ema_aligned;
    bool h1_slope_valid;
    bool h1_price_position_valid;
    bool h1_not_sideway;

    int m15_direction;
    bool m15_structure_valid;
    bool m15_aligned;

    int m5_direction;
    bool m5_continuation;
    bool m5_displacement;
    bool m5_momentum;
    bool m5_structure_valid;

    double protected_high;
    double protected_low;

    datetime h1_last_confirmed_time;
    datetime m15_last_confirmed_time;
    datetime m5_last_confirmed_time;

    string status;
    string reject_reason;
};

DXYTrendContext G_DXY_TF[DXY_CONTEXTS]; // DXY context cho Trend Following

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
// FORWARD DECLARATIONS
// ==================================================================
string DetectChainStrategy(int idx, ulong chain_id);
int    ExtractDCASeqFromComment(string comment);

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

      // --- CHE DO TU DONG (DUY NHAT): Mac dinh H1/M5, Risk 0.5% cho tat ca ---
      G_Pairs[i].htf = PERIOD_H1;
      G_Pairs[i].ltf = PERIOD_M5;
      G_Pairs[i].risk_percent = 0.5;
      G_Pairs[i].enabled = true;

      // Reset LTF State
      G_Pairs[i].handle_cci = INVALID_HANDLE;
      G_Pairs[i].isReadyForBuy = false;
      G_Pairs[i].isReadyForSell = false;
      G_Pairs[i].g_inited_filt = false;
      G_Pairs[i].last_bar_time = 0;
      
      // Reset Reversal Engine State
      G_Pairs[i].regime = REGIME_UNKNOWN;
      G_Pairs[i].htf_ext = 0.0;
      G_Pairs[i].htf_div = false;
      G_Pairs[i].htf_exh = false;
      G_Pairs[i].htf_reversal_zone = false;
      G_Pairs[i].htf_conflict = false;
      G_Pairs[i].ltf_divergence = false;
      G_Pairs[i].ltf_mss = false;
      G_Pairs[i].ltf_exh = false;
      G_Pairs[i].ltf_cci_recov = 0;
      G_Pairs[i].ltf_rf_state = 0;
      G_Pairs[i].reversal_score = 0.0;
      G_Pairs[i].state_machine = STATE_NO_SETUP;
      G_Pairs[i].rev_status = "NO SETUP";
      G_Pairs[i].last_swing_high = 0.0;
      G_Pairs[i].last_swing_low = 0.0;
      
      // Reset Reversal Engine V2 fields
      G_Pairs[i].setup_direction = 0;
      G_Pairs[i].setup_start_bar = 0;
      G_Pairs[i].setup_bar_count = 0;
      G_Pairs[i].exh_divergence = false;
      G_Pairs[i].exh_rejection = false;
      G_Pairs[i].exh_failed_cont = false;
      G_Pairs[i].exh_divergence_age = 0;
      G_Pairs[i].exh_rejection_age = 0;
      G_Pairs[i].exh_failed_cont_age = 0;
      G_Pairs[i].conf_sweep = false;
      G_Pairs[i].conf_displacement = false;
      G_Pairs[i].conf_mss = false;
      G_Pairs[i].conf_retest = false;
      G_Pairs[i].conf_sweep_age = 0;
      G_Pairs[i].conf_displacement_age = 0;
      G_Pairs[i].conf_mss_age = 0;
      G_Pairs[i].sweep_level = 0.0;
      G_Pairs[i].mss_break_level = 0.0;
      G_Pairs[i].retest_bar_count = 0;
      G_Pairs[i].qual_swing_high = 0.0;
      G_Pairs[i].qual_swing_low = 0.0;
      G_Pairs[i].prev_swing_high = 0.0;
      G_Pairs[i].prev_swing_low = 0.0;
      G_Pairs[i].qual_swing_high_idx = -1;
      G_Pairs[i].qual_swing_low_idx = -1;
      G_Pairs[i].prev_swing_high_idx = -1;
      G_Pairs[i].prev_swing_low_idx = -1;
      G_Pairs[i].score_location = 0.0;
      G_Pairs[i].score_exhaustion = 0.0;
      G_Pairs[i].score_sweep = 0.0;
      G_Pairs[i].score_displacement = 0.0;
      G_Pairs[i].score_mss = 0.0;
      G_Pairs[i].score_momentum = 0.0;


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

      // Load Persistent State (Debt and Recovery Level) to survive restarts
      // --- Load Legacy per-strategy state (for backward compatibility / migration) ---
      // --- CT ---
      if(GlobalVariableCheck("Yoogi_CT_Debt_" + G_Pairs[i].symbol)) 
         G_Pairs[i].ct_realized_bleed_loss = GlobalVariableGet("Yoogi_CT_Debt_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].ct_realized_bleed_loss = 0.0;

      if(GlobalVariableCheck("Yoogi_CT_RecLvl_" + G_Pairs[i].symbol)) 
         G_Pairs[i].ct_recovery_level = (int)GlobalVariableGet("Yoogi_CT_RecLvl_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].ct_recovery_level = 0;
         
      if(GlobalVariableCheck("Yoogi_CT_DCASeq_" + G_Pairs[i].symbol)) 
         G_Pairs[i].ct_dca_sequence = (int)GlobalVariableGet("Yoogi_CT_DCASeq_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].ct_dca_sequence = 0;
         
      // --- FT ---
      if(GlobalVariableCheck("Yoogi_FT_Debt_" + G_Pairs[i].symbol)) 
         G_Pairs[i].ft_realized_bleed_loss = GlobalVariableGet("Yoogi_FT_Debt_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].ft_realized_bleed_loss = 0.0;

      if(GlobalVariableCheck("Yoogi_FT_RecLvl_" + G_Pairs[i].symbol)) 
         G_Pairs[i].ft_recovery_level = (int)GlobalVariableGet("Yoogi_FT_RecLvl_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].ft_recovery_level = 0;
         
      if(GlobalVariableCheck("Yoogi_FT_DCASeq_" + G_Pairs[i].symbol)) 
         G_Pairs[i].ft_dca_sequence = (int)GlobalVariableGet("Yoogi_FT_DCASeq_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].ft_dca_sequence = 0;
         
      // --- DUAL ---
      if(GlobalVariableCheck("Yoogi_DUAL_Debt_" + G_Pairs[i].symbol)) 
         G_Pairs[i].dual_realized_bleed_loss = GlobalVariableGet("Yoogi_DUAL_Debt_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].dual_realized_bleed_loss = 0.0;

      if(GlobalVariableCheck("Yoogi_DUAL_RecLvl_" + G_Pairs[i].symbol)) 
         G_Pairs[i].dual_recovery_level = (int)GlobalVariableGet("Yoogi_DUAL_RecLvl_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].dual_recovery_level = 0;

      if(GlobalVariableCheck("Yoogi_DUAL_DCASeq_" + G_Pairs[i].symbol)) 
         G_Pairs[i].dual_dca_sequence = (int)GlobalVariableGet("Yoogi_DUAL_DCASeq_" + G_Pairs[i].symbol);
      else 
         G_Pairs[i].dual_dca_sequence = 0;

      // --- SYSTEM-LEVEL Recovery State (AUTHORITATIVE) ---
      // Check if System State already persisted
      string sys_debt_gv  = "Yoogi_SystemDebt_" + G_Pairs[i].symbol;
      string sys_reclvl_gv = "Yoogi_SystemRecLvl_" + G_Pairs[i].symbol;
      string sys_dcaseq_gv = "Yoogi_SystemDCASeq_" + G_Pairs[i].symbol;
      
      bool has_debt   = GlobalVariableCheck(sys_debt_gv);
      bool has_reclvl = GlobalVariableCheck(sys_reclvl_gv);
      bool has_dcaseq = GlobalVariableCheck(sys_dcaseq_gv);
      
      if(has_debt && has_reclvl && has_dcaseq)
      {
         // System state is complete - load directly
         G_Pairs[i].system_debt = GlobalVariableGet(sys_debt_gv);
         G_Pairs[i].system_recovery_level = (int)GlobalVariableGet(sys_reclvl_gv);
         G_Pairs[i].system_dca_sequence = (int)GlobalVariableGet(sys_dcaseq_gv);
         G_Pairs[i].system_recovery_active = (G_Pairs[i].system_debt > 0.001);
         
         // Load partial recovery flag
         string sys_partial_gv = "Yoogi_SystemPartialRec_" + G_Pairs[i].symbol;
         if(GlobalVariableCheck(sys_partial_gv))
            G_Pairs[i].system_debt_partially_recovered = ((int)GlobalVariableGet(sys_partial_gv) == 1);
         else
            G_Pairs[i].system_debt_partially_recovered = false;
         
         PrintFormat("[SYSTEM-STATE-LOAD] %s: Debt=%.2f RecLvl=%d DCASeq=%d Recovery=%s PartialRec=%s",
                     G_Pairs[i].symbol, G_Pairs[i].system_debt, G_Pairs[i].system_recovery_level,
                     G_Pairs[i].system_dca_sequence, G_Pairs[i].system_recovery_active ? "ACTIVE" : "NORMAL",
                     G_Pairs[i].system_debt_partially_recovered ? "YES" : "NO");
      }
      else
      {
         // MIGRATION / RECONCILIATION: Safely merge if System State is incomplete or missing
         double total_legacy_debt = G_Pairs[i].ct_realized_bleed_loss 
                                  + G_Pairs[i].ft_realized_bleed_loss 
                                  + G_Pairs[i].dual_realized_bleed_loss;
         
         int max_legacy_seq = MathMax(G_Pairs[i].ct_dca_sequence,
                              MathMax(G_Pairs[i].ft_dca_sequence,
                                      G_Pairs[i].dual_dca_sequence));
         
         int max_legacy_lvl = MathMax(G_Pairs[i].ct_recovery_level,
                              MathMax(G_Pairs[i].ft_recovery_level,
                                      G_Pairs[i].dual_recovery_level));
         
         if(has_debt) G_Pairs[i].system_debt = GlobalVariableGet(sys_debt_gv);
         else         G_Pairs[i].system_debt = total_legacy_debt;
         
         if(has_reclvl) G_Pairs[i].system_recovery_level = (int)GlobalVariableGet(sys_reclvl_gv);
         else           G_Pairs[i].system_recovery_level = max_legacy_lvl;
         
         if(has_dcaseq) G_Pairs[i].system_dca_sequence = (int)GlobalVariableGet(sys_dcaseq_gv);
         else           G_Pairs[i].system_dca_sequence = max_legacy_seq;
         
         G_Pairs[i].system_recovery_active = (G_Pairs[i].system_debt > 0.001);
         G_Pairs[i].system_debt_partially_recovered = false; // Migration: assume first recovery
         
         // Persist the migrated/reconciled system state
         GlobalVariableSet(sys_debt_gv, G_Pairs[i].system_debt);
         GlobalVariableSet(sys_reclvl_gv, (double)G_Pairs[i].system_recovery_level);
         GlobalVariableSet(sys_dcaseq_gv, (double)G_Pairs[i].system_dca_sequence);
         
         if(!has_debt && !has_reclvl && !has_dcaseq)
         {
            if(total_legacy_debt > 0.001 || max_legacy_seq > 0)
            {
               PrintFormat("[STATE-MIGRATION]\nSYMBOL=%s\nLEGACY_CT_DEBT=%.2f\nLEGACY_FT_DEBT=%.2f\nLEGACY_DUAL_DEBT=%.2f\nSYSTEM_DEBT=%.2f\nLEGACY_CT_DCA=%d\nLEGACY_FT_DCA=%d\nLEGACY_DUAL_DCA=%d\nSYSTEM_DCA=%d\nACTION=MIGRATED",
                           G_Pairs[i].symbol,
                           G_Pairs[i].ct_realized_bleed_loss, G_Pairs[i].ft_realized_bleed_loss, G_Pairs[i].dual_realized_bleed_loss,
                           total_legacy_debt, 
                           G_Pairs[i].ct_dca_sequence, G_Pairs[i].ft_dca_sequence, G_Pairs[i].dual_dca_sequence,
                           max_legacy_seq);
            }
         }
         else
         {
            PrintFormat("[STATE-RECONCILE]\nSYMBOL=%s\nSYSTEM_DEBT_EXISTING=%.2f\nLEGACY_DEBT=%.2f\nSYSTEM_DEBT_FINAL=%.2f\nSYSTEM_DCA_FINAL=%d\nACTION=RECONCILED",
                        G_Pairs[i].symbol, has_debt ? GlobalVariableGet(sys_debt_gv) : 0.0, total_legacy_debt, G_Pairs[i].system_debt, G_Pairs[i].system_dca_sequence);
         }
      }

      G_Pairs[i].locked_balance = 0.0;
      G_Pairs[i].chain_position_count = 0;
      G_Pairs[i].chain_start_dca_seq = 0;
      G_Pairs[i].chain_end_dca_seq = 0;
      G_Pairs[i].chain_step_pips = 0;
      if(GlobalVariableCheck("Yoogi_ActiveChainID_" + G_Pairs[i].symbol))
         G_Pairs[i].active_chain_id = (ulong)GlobalVariableGet("Yoogi_ActiveChainID_" + G_Pairs[i].symbol);
      else
         G_Pairs[i].active_chain_id = 0;

      if(G_Pairs[i].active_chain_id > 0)
      {
         G_Pairs[i].active_chain_strategy = DetectChainStrategy(i, G_Pairs[i].active_chain_id);
      }
      else
      {
         G_Pairs[i].active_chain_strategy = "";
      }

      // Reset Trend-Following Context
      G_TF[i].h1_trend_direction = 0;
      G_TF[i].h1_trend_quality = 0.0;
      G_TF[i].h1_ema_aligned = false;
      G_TF[i].h1_slope_positive = false;
      G_TF[i].h1_price_above_ema = false;
      G_TF[i].h1_structure_valid = false;
      G_TF[i].h1_not_sideway = false;
      G_TF[i].m15_pullback_valid = false;
      G_TF[i].m15_pullback_quality = 0.0;
      G_TF[i].m15_pullback_bar_count = 0;
      G_TF[i].m15_pullback_depth = 0.0;
      G_TF[i].m15_ema_distance = 0.0;
      G_TF[i].m15_pullback_start_time = 0;
      G_TF[i].m15_impulse_high = 0.0;
      G_TF[i].m15_impulse_low = 0.0;
      G_TF[i].m15_impulse_start_time = 0;
      G_TF[i].m15_impulse_end_time = 0;
      G_TF[i].m15_protected_time = 0;
      G_TF[i].m15_protected_confirmed_time = 0;
      G_TF[i].m5_sweep = false;
      G_TF[i].m5_displacement = false;
      G_TF[i].m5_mss = false;
      G_TF[i].m5_momentum_cci = false;
      G_TF[i].m5_momentum_rf = false;
      G_TF[i].m5_momentum_pc = false;
      G_TF[i].m5_sweep_time = 0;
      G_TF[i].m5_displacement_time = 0;
      G_TF[i].m5_mss_time = 0;
      G_TF[i].m5_momentum_time = 0;
      G_TF[i].m5_momentum_start_time = 0;
      G_TF[i].m5_momentum_cci_time = 0;
      G_TF[i].m5_momentum_rf_time = 0;
      G_TF[i].m5_momentum_pc_time = 0;
      G_TF[i].m5_sweep_price = 0.0;
      G_TF[i].m5_displacement_price = 0.0;
      G_TF[i].m5_sweep_age = 0;
      G_TF[i].m5_displacement_age = 0;
      G_TF[i].m5_mss_age = 0;
      G_TF[i].m5_momentum_bars_elapsed = 0;
      G_TF[i].m5_momentum_last_closed_time = 0;
      G_TF[i].m5_mss_break_level = 0.0;
      G_TF[i].m5_sweep_level = 0.0;
      G_TF[i].score_h1_trend = 0.0;
      G_TF[i].score_m15_pullback = 0.0;
      G_TF[i].score_sweep = 0.0;
      G_TF[i].score_displacement = 0.0;
      G_TF[i].score_mss = 0.0;
      G_TF[i].score_event_coherence = 0.0;
      G_TF[i].score_momentum = 0.0;
      G_TF[i].score_entry_distance = 0.0;
      G_TF[i].total_score = 0.0;
      G_TF[i].setup_state = TF_STATE_NONE;
      G_TF[i].setup_bar_count = 0;
      G_TF[i].status = "NO SETUP";
      G_TF[i].h1_protected_structure = 0.0;
      G_TF[i].m15_protected_low = 0.0;
      G_TF[i].m15_protected_high = 0.0;
      G_TF[i].m15_last_bar_time = 0;
      G_TF[i].m5_last_bar_time_tf = 0;

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
         G_DXY_TrapSignalTime_HTF[i] = 0;

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
         G_DXY_TrapSignalTime_LTF[i] = 0;

         // --- DXY TF Context ---
         G_DXY_TF[i].symbol = dxy_broker;
         G_DXY_TF[i].htf = PERIOD_H1;
         G_DXY_TF[i].mtf = PERIOD_M15;
         G_DXY_TF[i].ltf = PERIOD_M5;
         G_DXY_TF[i].h1_direction = 0;
         G_DXY_TF[i].m15_direction = 0;
         G_DXY_TF[i].m5_direction = 0;
         G_DXY_TF[i].h1_last_confirmed_time = 0;
         G_DXY_TF[i].m15_last_confirmed_time = 0;
         G_DXY_TF[i].m5_last_confirmed_time = 0;
         G_DXY_TF[i].status = "INIT";
         G_DXY_TF[i].reject_reason = "";
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

   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      debt += G_Pairs[i].system_debt;
   }

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

// Logic tính Lot theo Global DCA Sequence (DCA 1 = BaseLot, DCA N = Previous DCA Lot * InpHeSoLot)
double CalculateDCALot(int idx, int dca_seq, double balance)
{
   string sym = G_Pairs[idx].symbol;
   double base_lot = CalculateAutoLot(idx, balance);
   if(base_lot <= 0.0) return 0.0;
   if(dca_seq <= 1) return base_lot;
   
   double cur_lot = base_lot;
   for(int s = 2; s <= dca_seq; s++)
   {
      cur_lot = NormalizeLot(sym, cur_lot * InpHeSoLot);
   }
   return cur_lot;
}

// ======================================================================
// SYSTEM-LEVEL Recovery State Accessors (AUTHORITATIVE for all Recovery logic)
// ======================================================================
double GetSystemDebt(int idx)
{
   return G_Pairs[idx].system_debt;
}

void SetSystemDebt(int idx, double debt)
{
   if(debt < 0.00001) debt = 0.0;
   G_Pairs[idx].system_debt = debt;
   G_Pairs[idx].system_recovery_active = (debt > 0.001);
   GlobalVariableSet("Yoogi_SystemDebt_" + G_Pairs[idx].symbol, debt);
}

int GetSystemDCASeq(int idx)
{
   return G_Pairs[idx].system_dca_sequence;
}

void SetSystemDCASeq(int idx, int seq)
{
   if(seq < 0) seq = 0;
   G_Pairs[idx].system_dca_sequence = seq;
   GlobalVariableSet("Yoogi_SystemDCASeq_" + G_Pairs[idx].symbol, (double)seq);
}

int GetSystemRecLvl(int idx)
{
   return G_Pairs[idx].system_recovery_level;
}

void SetSystemRecLvl(int idx, int lvl)
{
   if(lvl < 0) lvl = 0;
   G_Pairs[idx].system_recovery_level = lvl;
   GlobalVariableSet("Yoogi_SystemRecLvl_" + G_Pairs[idx].symbol, (double)lvl);
}

bool IsSystemInRecovery(int idx)
{
   return (G_Pairs[idx].system_debt > 0.001);
}

// ======================================================================
// Legacy Strategy State Accessors (BACKWARD COMPATIBILITY ONLY - metadata/stats)
// These are NO LONGER authoritative for Recovery decisions.
// ======================================================================
double GetStrategyDebt(int idx, string strat)
{
   // REDIRECT: Return system debt (unified across strategies)
   return G_Pairs[idx].system_debt;
}

void SetStrategyDebt(int idx, string strat, double debt)
{
   // REDIRECT: Set system debt (unified)
   SetSystemDebt(idx, debt);
}

int GetStrategyDCASeq(int idx, string strat)
{
   // REDIRECT: Return system DCA sequence (unified)
   return G_Pairs[idx].system_dca_sequence;
}

void SetStrategyDCASeq(int idx, string strat, int seq)
{
   // REDIRECT: Set system DCA sequence (unified)
   SetSystemDCASeq(idx, seq);
}

int GetStrategyRecLvl(int idx, string strat)
{
   // REDIRECT: Return system recovery level (unified)
   return G_Pairs[idx].system_recovery_level;
}

void SetStrategyRecLvl(int idx, string strat, int lvl)
{
   // REDIRECT: Set system recovery level (unified)
   SetSystemRecLvl(idx, lvl);
}

bool IsStrategyInRecovery(int idx, string strat)
{
   // REDIRECT: Use system-level recovery check
   return IsSystemInRecovery(idx);
}

// Persistence names
string GetVarName_Step(string sym, ulong chain_id)      { return "Yoogi_Step_" + sym + "_" + IntegerToString(chain_id); }
string GetVarName_LockedBal(string sym, ulong chain_id) { return "Yoogi_Bal_" + sym + "_" + IntegerToString(chain_id); }
string GetVarName_StartSeq(string sym, ulong chain_id)  { return "Yoogi_StartSeq_" + sym + "_" + IntegerToString(chain_id); }
string GetVarName_EndSeq(string sym, ulong chain_id)    { return "Yoogi_EndSeq_" + sym + "_" + IntegerToString(chain_id); }

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

// Generate unique, strictly monotonic chain ID for each new chain
ulong GenerateUniqueChainID(int idx)
{
   string sym = G_Pairs[idx].symbol;
   datetime now = TimeCurrent();
   ulong base_id = (ulong)EA_MAGIC_NUMBER * 100000000000ULL + (ulong)now * 10ULL + (ulong)idx;
   
   ulong last_id = 0;
   string gv_last = "Yoogi_LastChainID_" + sym;
   if(GlobalVariableCheck(gv_last))
      last_id = (ulong)GlobalVariableGet(gv_last);
      
   if(base_id <= last_id)
   {
      base_id = last_id + 10ULL;
   }
   
   GlobalVariableSet(gv_last, (double)base_id);
   return base_id;
}

// Check if a magic number belongs to pair idx's chain
bool IsPairChainMagic(int idx, ulong magic)
{
   if(magic == 0) return false;
   if(G_Pairs[idx].active_chain_id != 0 && magic == G_Pairs[idx].active_chain_id) return true;
   if(magic == (ulong)(EA_MAGIC_NUMBER * 1000 + idx)) return true;
   if(magic / 100000000000ULL == (ulong)EA_MAGIC_NUMBER && (magic % 10ULL) == (ulong)idx) return true;
   return false;
}

// Extract DCA sequence number from order/deal comment e.g. "CT | DCA 3" -> 3
int ExtractDCASeqFromComment(string comment)
{
   int pos = StringFind(comment, "DCA ");
   if(pos >= 0)
   {
      string num_str = StringSubstr(comment, pos + 4);
      return (int)StringToInteger(num_str);
   }
   return 0;
}

// Authoritative multi-source strategy detector (CT, FT, DUAL)
// Guarantees strategy persistence across restarts and history resolution
string DetectChainStrategy(int idx, ulong chain_id)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return "CT";
   string sym = G_Pairs[idx].symbol;

   // PRIORITY 1 to 4: Chain-specific data
   if(chain_id > 0)
   {
      // PRIORITY 1: Chain-specific persistent strategy
      // Yoogi_Strat_<symbol>_<chain_id> (1 = CT, 2 = FT, 3 = DUAL)
      string n_strat = "Yoogi_Strat_" + sym + "_" + IntegerToString(chain_id);
      if(GlobalVariableCheck(n_strat))
      {
         int sv = (int)GlobalVariableGet(n_strat);
         if(sv == 1) return "CT";
         if(sv == 2) return "FT";
         if(sv == 3) return "DUAL";
      }

      // PRIORITY 2: Chain-specific Dynamic TP strategy
      // Yoogi_DynTP_Strat_<symbol>_<chain_id> (1 = CT, 2 = FT, 3 = DUAL)
      string n_dyn = "Yoogi_DynTP_Strat_" + sym + "_" + IntegerToString(chain_id);
      if(GlobalVariableCheck(n_dyn))
      {
         int dsv = (int)GlobalVariableGet(n_dyn);
         if(dsv == 1) return "CT";
         if(dsv == 2) return "FT";
         if(dsv == 3) return "DUAL";
      }

      // PRIORITY 3: Open positions of this EXACT chain_id
      // symbol == current symbol AND POSITION_MAGIC == chain_id
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong t = PositionGetTicket(i);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym &&
               (ulong)PositionGetInteger(POSITION_MAGIC) == chain_id)
            {
               string cmt = PositionGetString(POSITION_COMMENT);
               if(StringFind(cmt, "FT") == 0) return "FT";
               if(StringFind(cmt, "DUAL") == 0) return "DUAL";
               if(StringFind(cmt, "CT") == 0) return "CT";
            }
         }
      }

      // PRIORITY 4: History deals of this EXACT chain_id
      // symbol == current symbol AND DEAL_MAGIC == chain_id
      datetime from_date = TimeCurrent() - 90 * 24 * 60 * 60;
      if(HistorySelect(from_date, TimeCurrent() + 86400))
      {
         int deals = HistoryDealsTotal();
         for(int d = deals - 1; d >= 0; --d)
         {
            ulong dticket = HistoryDealGetTicket(d);
            if(dticket > 0)
            {
               if(HistoryDealGetString(dticket, DEAL_SYMBOL) == sym &&
                  (ulong)HistoryDealGetInteger(dticket, DEAL_MAGIC) == chain_id)
               {
                  string dcmt = HistoryDealGetString(dticket, DEAL_COMMENT);
                  if(StringFind(dcmt, "FT") == 0) return "FT";
                  if(StringFind(dcmt, "DUAL") == 0) return "DUAL";
                  if(StringFind(dcmt, "CT") == 0) return "CT";
               }
            }
         }
      }
   }

   // PRIORITY 5: Recovery state fallback
   // Only if completely unable to determine from chain-specific data:
   // If exactly one strategy has Debt > 0 on this pair, attribute to that strategy
   bool ct_in_rec   = (G_Pairs[idx].ct_realized_bleed_loss > 0.001);
   bool ft_in_rec   = (G_Pairs[idx].ft_realized_bleed_loss > 0.001);
   bool dual_in_rec = (G_Pairs[idx].dual_realized_bleed_loss > 0.001);

   int rec_count = (ct_in_rec ? 1 : 0) + (ft_in_rec ? 1 : 0) + (dual_in_rec ? 1 : 0);
   if(rec_count == 1)
   {
      if(ft_in_rec)   return "FT";
      if(dual_in_rec) return "DUAL";
      if(ct_in_rec)   return "CT";
   }

   // PRIORITY 6: Active pair context (ONLY as fallback)
   // TUYET DOI KHONG dat active_chain_strategy truoc chain-specific persistent data
   if(G_Pairs[idx].active_chain_strategy == "CT" || 
      G_Pairs[idx].active_chain_strategy == "FT" || 
      G_Pairs[idx].active_chain_strategy == "DUAL")
   {
      return G_Pairs[idx].active_chain_strategy;
   }

   // PRIORITY 7: Ultimate fallback
   return "CT";
}
//+------------------------------------------------------------------+
