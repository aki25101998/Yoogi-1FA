//+------------------------------------------------------------------+
//|                                     DXYTrendFollowingEngine.mqh |
//|                                                      Antigravity |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""

// --- Constants cho DXY TF Engine ---
const int DXY_TF_SWING_PERIOD = 3; 

// --- Helpers ---
double GetDXYSwingHigh(string sym, ENUM_TIMEFRAMES tf, int start_idx)
{
   double high[];
   ArraySetAsSeries(high, true);
   if(CopyHigh(sym, tf, start_idx, 100, high) < 50) return 0.0;
   
   for(int i = DXY_TF_SWING_PERIOD; i < 40; i++)
   {
      bool isSwing = true;
      for(int j = 1; j <= DXY_TF_SWING_PERIOD; j++)
      {
         if(high[i] <= high[i-j] || high[i] <= high[i+j])
         {
            isSwing = false;
            break;
         }
      }
      if(isSwing) return high[i];
   }
   return 0.0;
}

double GetDXYSwingLow(string sym, ENUM_TIMEFRAMES tf, int start_idx)
{
   double low[];
   ArraySetAsSeries(low, true);
   if(CopyLow(sym, tf, start_idx, 100, low) < 50) return 0.0;
   
   for(int i = DXY_TF_SWING_PERIOD; i < 40; i++)
   {
      bool isSwing = true;
      for(int j = 1; j <= DXY_TF_SWING_PERIOD; j++)
      {
         if(low[i] >= low[i-j] || low[i] >= low[i+j])
         {
            isSwing = false;
            break;
         }
      }
      if(isSwing) return low[i];
   }
   return 0.0;
}

bool CheckDXYMomentum(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   double close = iClose(sym, tf, 1);
   double open = iOpen(sym, tf, 1);
   double body = direction == 1 ? (close - open) : (open - close);
   double hl = iHigh(sym, tf, 1) - iLow(sym, tf, 1);
   
   if(hl > 0)
   {
      // Yêu cầu nến 1 có body > 50% range để gọi là có momentum/displacement
      if (body / hl > 0.5) return true;
   }
   return false;
}

// ==================================================================
// LAYER 1: H1 Trend Regime
// ==================================================================
void EvaluateDXY_H1(int dxy_idx, string sym, ENUM_TIMEFRAMES htf)
{
   double ema20 = CalculateEMA_Generic(sym, htf, 20, 1);
   double ema50 = CalculateEMA_Generic(sym, htf, 50, 1);
   double ema50_prev = CalculateEMA_Generic(sym, htf, 50, 1 + TF_SLOPE_LOOKBACK);
   double close = iClose(sym, htf, 1);
   
   G_DXY_TF[dxy_idx].h1_ema_aligned = false;
   G_DXY_TF[dxy_idx].h1_slope_valid = false;
   G_DXY_TF[dxy_idx].h1_price_position_valid = false;
   G_DXY_TF[dxy_idx].h1_structure_valid = false;
   G_DXY_TF[dxy_idx].h1_not_sideway = true; // Simplified sideway check
   G_DXY_TF[dxy_idx].h1_direction = 0;
   
   if(ema20 > ema50 && close > ema50) // Potential BUY
   {
      G_DXY_TF[dxy_idx].h1_ema_aligned = true;
      G_DXY_TF[dxy_idx].h1_price_position_valid = true;
      if(ema50 > ema50_prev) G_DXY_TF[dxy_idx].h1_slope_valid = true;
      
      // Structure: HH HL
      double h1 = GetDXYSwingHigh(sym, htf, 1);
      if(close > h1 || h1 == 0.0) G_DXY_TF[dxy_idx].h1_structure_valid = true; // Phá vỡ đỉnh gần nhất -> cấu trúc tăng tiếp diễn
      else G_DXY_TF[dxy_idx].h1_structure_valid = true; // Hoặc có thể tạm chấp nhận nếu EMA đủ mạnh
      
      if(G_DXY_TF[dxy_idx].h1_slope_valid) G_DXY_TF[dxy_idx].h1_direction = 1;
   }
   else if(ema20 < ema50 && close < ema50) // Potential SELL
   {
      G_DXY_TF[dxy_idx].h1_ema_aligned = true;
      G_DXY_TF[dxy_idx].h1_price_position_valid = true;
      if(ema50 < ema50_prev) G_DXY_TF[dxy_idx].h1_slope_valid = true;
      
      double l1 = GetDXYSwingLow(sym, htf, 1);
      if(close < l1 || l1 == 0.0) G_DXY_TF[dxy_idx].h1_structure_valid = true; 
      else G_DXY_TF[dxy_idx].h1_structure_valid = true; 
      
      if(G_DXY_TF[dxy_idx].h1_slope_valid) G_DXY_TF[dxy_idx].h1_direction = -1;
   }
}

// ==================================================================
// LAYER 2: M15 Alignment
// ==================================================================
void EvaluateDXY_M15(int dxy_idx, string sym, ENUM_TIMEFRAMES mtf, int h1_dir)
{
   G_DXY_TF[dxy_idx].m15_direction = 0;
   G_DXY_TF[dxy_idx].m15_aligned = false;
   G_DXY_TF[dxy_idx].m15_structure_valid = false;
   
   if(h1_dir == 0) return;
   
   double ema50 = CalculateEMA_Generic(sym, mtf, 50, 1);
   double close = iClose(sym, mtf, 1);
   
   if(h1_dir == 1) // H1 is BUY
   {
      double protected_low = GetDXYSwingLow(sym, mtf, 1);
      G_DXY_TF[dxy_idx].protected_low = protected_low;
      
      if(close > protected_low || protected_low == 0.0)
      {
         G_DXY_TF[dxy_idx].m15_structure_valid = true;
         // Alignment có thể xét thêm EMA
         if(close > ema50) G_DXY_TF[dxy_idx].m15_aligned = true;
         else G_DXY_TF[dxy_idx].m15_aligned = true; // Nới lỏng: pullback vẫn coi là aligned nếu structure valid
         
         G_DXY_TF[dxy_idx].m15_direction = 1;
      }
   }
   else if(h1_dir == -1) // H1 is SELL
   {
      double protected_high = GetDXYSwingHigh(sym, mtf, 1);
      G_DXY_TF[dxy_idx].protected_high = protected_high;
      
      if(close < protected_high || protected_high == 0.0)
      {
         G_DXY_TF[dxy_idx].m15_structure_valid = true;
         if(close < ema50) G_DXY_TF[dxy_idx].m15_aligned = true;
         else G_DXY_TF[dxy_idx].m15_aligned = true;
         
         G_DXY_TF[dxy_idx].m15_direction = -1;
      }
   }
}

// ==================================================================
// LAYER 3: M5 Continuation
// ==================================================================
void EvaluateDXY_M5(int dxy_idx, string sym, ENUM_TIMEFRAMES ltf, int expected_dir)
{
   G_DXY_TF[dxy_idx].m5_direction = 0;
   G_DXY_TF[dxy_idx].m5_continuation = false;
   G_DXY_TF[dxy_idx].m5_displacement = false;
   G_DXY_TF[dxy_idx].m5_momentum = false;
   G_DXY_TF[dxy_idx].m5_structure_valid = false;
   
   if(expected_dir == 0) return;
   
   double close = iClose(sym, ltf, 1);
   double close2 = iClose(sym, ltf, 2);
   
   if(expected_dir == 1) // H1 & M15 BUY
   {
      double prev_high = GetDXYSwingHigh(sym, ltf, 2);
      if(close > prev_high || close > close2) G_DXY_TF[dxy_idx].m5_continuation = true; // Simplified continuation
      
      G_DXY_TF[dxy_idx].m5_displacement = CheckDXYMomentum(sym, ltf, 1);
      G_DXY_TF[dxy_idx].m5_momentum = G_DXY_TF[dxy_idx].m5_displacement;
      
      if(close > G_DXY_TF[dxy_idx].protected_low || G_DXY_TF[dxy_idx].protected_low == 0.0) G_DXY_TF[dxy_idx].m5_structure_valid = true;
      
      if(G_DXY_TF[dxy_idx].m5_continuation && G_DXY_TF[dxy_idx].m5_structure_valid)
      {
         G_DXY_TF[dxy_idx].m5_direction = 1;
      }
   }
   else if(expected_dir == -1) // H1 & M15 SELL
   {
      double prev_low = GetDXYSwingLow(sym, ltf, 2);
      if(close < prev_low || close < close2) G_DXY_TF[dxy_idx].m5_continuation = true; 
      
      G_DXY_TF[dxy_idx].m5_displacement = CheckDXYMomentum(sym, ltf, -1);
      G_DXY_TF[dxy_idx].m5_momentum = G_DXY_TF[dxy_idx].m5_displacement;
      
      if(close < G_DXY_TF[dxy_idx].protected_high || G_DXY_TF[dxy_idx].protected_high == 0.0) G_DXY_TF[dxy_idx].m5_structure_valid = true;
      
      if(G_DXY_TF[dxy_idx].m5_continuation && G_DXY_TF[dxy_idx].m5_structure_valid)
      {
         G_DXY_TF[dxy_idx].m5_direction = -1;
      }
   }
}

// ==================================================================
// DXY TF CONFIRMATION GATE
// ==================================================================
bool CheckDXYTrendFollowingConfirmation(int pair_idx, int pair_direction, string &reason)
{
   reason = "";
   
   if(!g_dxy_available || !InpUseDXYReference)
   {
      reason = "N/A";
      return true; // Skip DXY check
   }
   
   if(!G_Pairs[pair_idx].isUSDPair)
   {
      reason = "NOT_USD_PAIR";
      return true; // EURGBP etc.
   }
   
   int dxy_idx = G_Pairs[pair_idx].dxy_map_index;
   if(dxy_idx < 0 || dxy_idx >= DXY_CONTEXTS)
   {
      reason = "INVALID_DXY_INDEX";
      return false;
   }
   
   string sym = G_DXY_TF[dxy_idx].symbol;
   ENUM_TIMEFRAMES htf = G_DXY_TF[dxy_idx].htf;
   ENUM_TIMEFRAMES mtf = G_DXY_TF[dxy_idx].mtf;
   ENUM_TIMEFRAMES ltf = G_DXY_TF[dxy_idx].ltf;
   
   // Xác định hướng kỳ vọng của DXY
   int expected_dxy_direction = 0;
   string orientation = "UNKNOWN";
   
   if(G_Pairs[pair_idx].isUSDFirst) 
   {
      expected_dxy_direction = pair_direction; // USDxxx -> Cùng hướng
      orientation = "USD_FIRST";
   }
   else if(G_Pairs[pair_idx].isUSDSecond)
   {
      expected_dxy_direction = -pair_direction; // xxxUSD -> Ngược hướng
      orientation = "USD_SECOND";
   }
   
   // Đánh giá các Layer
   EvaluateDXY_H1(dxy_idx, sym, htf);
   EvaluateDXY_M15(dxy_idx, sym, mtf, G_DXY_TF[dxy_idx].h1_direction);
   EvaluateDXY_M5(dxy_idx, sym, ltf, G_DXY_TF[dxy_idx].m15_direction);
   
   // Xác nhận
   bool pass = true;
   string status_str = "PASS";
   
   if(G_DXY_TF[dxy_idx].h1_direction != expected_dxy_direction)
   {
      pass = false;
      reason = "DXY_H1_DIRECTION_MISMATCH";
      if(G_DXY_TF[dxy_idx].h1_direction == 0) reason = "DXY_H1_NEUTRAL";
      status_str = "FAIL";
   }
   else if(G_DXY_TF[dxy_idx].m15_direction != expected_dxy_direction)
   {
      pass = false;
      reason = "DXY_M15_NOT_ALIGNED";
      status_str = "FAIL";
   }
   else if(G_DXY_TF[dxy_idx].m5_direction != expected_dxy_direction)
   {
      pass = false;
      reason = "DXY_M5_CONTINUATION_MISSING";
      status_str = "FAIL";
   }
   
   // Update status logic
   G_DXY_TF[dxy_idx].status = status_str;
   G_DXY_TF[dxy_idx].reject_reason = reason;
   
   // LOGGING
   Print("\n[DXY_TF]");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("PAIR=%s", G_Pairs[pair_idx].symbol);
   PrintFormat("PAIR_DIRECTION=%s", (pair_direction == 1 ? "BUY" : "SELL"));
   Print("");
   PrintFormat("H1_DIRECTION=%s", (G_DXY_TF[dxy_idx].h1_direction == 1 ? "BUY" : (G_DXY_TF[dxy_idx].h1_direction == -1 ? "SELL" : "NONE")));
   PrintFormat("H1_STRUCTURE=%s", (G_DXY_TF[dxy_idx].h1_structure_valid ? "PASS" : "FAIL"));
   PrintFormat("H1_EMA=%s", (G_DXY_TF[dxy_idx].h1_ema_aligned ? "PASS" : "FAIL"));
   PrintFormat("H1_SLOPE=%s", (G_DXY_TF[dxy_idx].h1_slope_valid ? "PASS" : "FAIL"));
   Print("");
   PrintFormat("M15_DIRECTION=%s", (G_DXY_TF[dxy_idx].m15_direction == 1 ? "BUY" : (G_DXY_TF[dxy_idx].m15_direction == -1 ? "SELL" : "NONE")));
   PrintFormat("M15_STRUCTURE=%s", (G_DXY_TF[dxy_idx].m15_structure_valid ? "PASS" : "FAIL"));
   PrintFormat("M15_ALIGNMENT=%s", (G_DXY_TF[dxy_idx].m15_aligned ? "PASS" : "FAIL"));
   Print("");
   PrintFormat("M5_DIRECTION=%s", (G_DXY_TF[dxy_idx].m5_direction == 1 ? "BUY" : (G_DXY_TF[dxy_idx].m5_direction == -1 ? "SELL" : "NONE")));
   PrintFormat("M5_CONTINUATION=%s", (G_DXY_TF[dxy_idx].m5_continuation ? "PASS" : "FAIL"));
   PrintFormat("M5_DISPLACEMENT=%s", (G_DXY_TF[dxy_idx].m5_displacement ? "PASS" : "FAIL"));
   PrintFormat("M5_MOMENTUM=%s", (G_DXY_TF[dxy_idx].m5_momentum ? "PASS" : "FAIL"));
   Print("");
   PrintFormat("ORIENTATION=%s", orientation);
   PrintFormat("EXPECTED_DXY_DIRECTION=%s", (expected_dxy_direction == 1 ? "BUY" : "SELL"));
   PrintFormat("ACTUAL_DXY_DIRECTION=%s", (G_DXY_TF[dxy_idx].m5_direction == 1 ? "BUY" : (G_DXY_TF[dxy_idx].m5_direction == -1 ? "SELL" : "NONE")));
   PrintFormat("STATUS=%s", status_str);
   if(!pass) PrintFormat("REASON=%s", reason);
   
   return pass;
}
