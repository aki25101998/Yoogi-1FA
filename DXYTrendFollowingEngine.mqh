//+------------------------------------------------------------------+
//|                                     DXYTrendFollowingEngine.mqh |
//|                                                      Antigravity |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""

// --- Constants cho DXY TF Engine ---
const int DXY_TF_SWING_PERIOD = 3; 

// --- Helpers ---
double GetDXYSwingHigh(string sym, ENUM_TIMEFRAMES tf, int start_idx, int nth_swing = 1)
{
   double high[];
   ArraySetAsSeries(high, true);
   if(CopyHigh(sym, tf, start_idx, 100, high) < 50) return 0.0;
   
   int found_count = 0;
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
      if(isSwing)
      {
         found_count++;
         if(found_count == nth_swing) return high[i];
         i += DXY_TF_SWING_PERIOD; // Skip adjacent bars to ensure distinct swing
      }
   }
   return 0.0;
}

double GetDXYSwingLow(string sym, ENUM_TIMEFRAMES tf, int start_idx, int nth_swing = 1)
{
   double low[];
   ArraySetAsSeries(low, true);
   if(CopyLow(sym, tf, start_idx, 100, low) < 50) return 0.0;
   
   int found_count = 0;
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
      if(isSwing)
      {
         found_count++;
         if(found_count == nth_swing) return low[i];
         i += DXY_TF_SWING_PERIOD; // Skip adjacent bars to ensure distinct swing
      }
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
      // Yêu cầu nến 1 có body >= 50% range để gọi là có momentum/displacement
      if (body / hl >= 0.5) return true;
   }
   return false;
}

// --- Age Helpers ---
int GetDXYClosedBarAge(string sym, ENUM_TIMEFRAMES tf, datetime confirmed_time)
{
   if(confirmed_time <= 0) return -1;
   int shift = iBarShift(sym, tf, confirmed_time, true);
   return shift;
}

bool IsDXYH1Fresh(string sym, datetime confirmed_time)
{
   int age = GetDXYClosedBarAge(sym, PERIOD_H1, confirmed_time);
   return (age >= 0 && age <= DXY_TF_H1_MAX_AGE_BARS);
}

bool IsDXYM15Fresh(string sym, datetime confirmed_time)
{
   int age = GetDXYClosedBarAge(sym, PERIOD_M15, confirmed_time);
   return (age >= 0 && age <= DXY_TF_M15_MAX_AGE_BARS);
}

bool IsDXYM5Fresh(string sym, datetime confirmed_time)
{
   int age = GetDXYClosedBarAge(sym, PERIOD_M5, confirmed_time);
   return (age >= 0 && age <= DXY_TF_M5_MAX_AGE_BARS);
}

// ==================================================================
// LAYER 1: H1 Trend Regime
// ==================================================================
void EvaluateDXY_H1(int dxy_idx, string sym, ENUM_TIMEFRAMES htf)
{
   double ema20 = CalculateEMA_Generic(sym, htf, 20, 1);
   double ema50 = CalculateEMA_Generic(sym, htf, 50, 1);
   double ema50_prev = CalculateEMA_Generic(sym, htf, 50, 1 + TF_SLOPE_LOOKBACK);
   double atr = CalculateATR_Generic(sym, htf, 14, 1);
   double close = iClose(sym, htf, 1);
   
   G_DXY_TF[dxy_idx].h1_ema_aligned = false;
   G_DXY_TF[dxy_idx].h1_slope_valid = false;
   G_DXY_TF[dxy_idx].h1_price_position_valid = false;
   G_DXY_TF[dxy_idx].h1_structure_valid = false;
   G_DXY_TF[dxy_idx].h1_not_sideway = false; 
   G_DXY_TF[dxy_idx].h1_direction = 0;
   
   // --- Sideway Filter ---
   double ema_distance_atr = 0.0;
   if(atr > 0) ema_distance_atr = MathAbs(ema20 - ema50) / atr;
   
   // Reject if distance < 0.5 ATR (too tight -> sideway)
   if(ema_distance_atr >= 0.5) G_DXY_TF[dxy_idx].h1_not_sideway = true;
   
   // --- Lấy các swing points ---
   double hh1 = GetDXYSwingHigh(sym, htf, 1, 1);
   double hh2 = GetDXYSwingHigh(sym, htf, 1, 2);
   double hl1 = GetDXYSwingLow(sym, htf, 1, 1);
   double hl2 = GetDXYSwingLow(sym, htf, 1, 2);

   double lh1 = hh1;
   double lh2 = hh2;
   double ll1 = hl1;
   double ll2 = hl2;
   
   bool buy_struct = (hh1 > hh2 && hl1 > hl2 && close > hl1 && hh1 > 0 && hh2 > 0 && hl1 > 0 && hl2 > 0);
   bool sell_struct = (lh1 < lh2 && ll1 < ll2 && close < lh1 && lh1 > 0 && lh2 > 0 && ll1 > 0 && ll2 > 0);
   
   // Potential BUY
   if(ema20 > ema50 && close > ema50)
   {
      G_DXY_TF[dxy_idx].h1_ema_aligned = true;
      if(close > ema20 && close > ema50) G_DXY_TF[dxy_idx].h1_price_position_valid = true;
      if(ema50 > ema50_prev) G_DXY_TF[dxy_idx].h1_slope_valid = true;
      
      if(buy_struct)
      {
         G_DXY_TF[dxy_idx].h1_structure_valid = true;
      }
      
      if(G_DXY_TF[dxy_idx].h1_slope_valid && G_DXY_TF[dxy_idx].h1_price_position_valid && G_DXY_TF[dxy_idx].h1_structure_valid && G_DXY_TF[dxy_idx].h1_not_sideway)
      {
         G_DXY_TF[dxy_idx].h1_direction = 1;
         G_DXY_TF[dxy_idx].h1_last_confirmed_time = iTime(sym, htf, 1);
      }
   }
   // Potential SELL
   else if(ema20 < ema50 && close < ema50)
   {
      G_DXY_TF[dxy_idx].h1_ema_aligned = true;
      if(close < ema20 && close < ema50) G_DXY_TF[dxy_idx].h1_price_position_valid = true;
      if(ema50 < ema50_prev) G_DXY_TF[dxy_idx].h1_slope_valid = true;
      
      if(sell_struct)
      {
         G_DXY_TF[dxy_idx].h1_structure_valid = true;
      }
      
      if(G_DXY_TF[dxy_idx].h1_slope_valid && G_DXY_TF[dxy_idx].h1_price_position_valid && G_DXY_TF[dxy_idx].h1_structure_valid && G_DXY_TF[dxy_idx].h1_not_sideway)
      {
         G_DXY_TF[dxy_idx].h1_direction = -1;
         G_DXY_TF[dxy_idx].h1_last_confirmed_time = iTime(sym, htf, 1);
      }
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
   
   double ema20 = CalculateEMA_Generic(sym, mtf, 20, 1);
   double ema50 = CalculateEMA_Generic(sym, mtf, 50, 1);
   double close = iClose(sym, mtf, 1);
   
   if(h1_dir == 1) // H1 is BUY
   {
      double protected_low = GetDXYSwingLow(sym, mtf, 1, 1);
      G_DXY_TF[dxy_idx].protected_low = protected_low; // Set explicitly to recent low
      
      if(close > protected_low && protected_low > 0.0)
      {
         G_DXY_TF[dxy_idx].m15_structure_valid = true;
         if(close > ema20 && close > ema50 && ema20 >= ema50) 
         {
            G_DXY_TF[dxy_idx].m15_aligned = true;
            G_DXY_TF[dxy_idx].m15_direction = 1;
            G_DXY_TF[dxy_idx].m15_last_confirmed_time = iTime(sym, mtf, 1);
         }
      }
   }
   else if(h1_dir == -1) // H1 is SELL
   {
      double protected_high = GetDXYSwingHigh(sym, mtf, 1, 1);
      G_DXY_TF[dxy_idx].protected_high = protected_high;
      
      if(close < protected_high && protected_high > 0.0)
      {
         G_DXY_TF[dxy_idx].m15_structure_valid = true;
         if(close < ema20 && close < ema50 && ema20 <= ema50)
         {
            G_DXY_TF[dxy_idx].m15_aligned = true;
            G_DXY_TF[dxy_idx].m15_direction = -1;
            G_DXY_TF[dxy_idx].m15_last_confirmed_time = iTime(sym, mtf, 1);
         }
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
   
   if(expected_dir == 1) // Expected BUY
   {
      double recent_swing_high = GetDXYSwingHigh(sym, ltf, 2, 1); // get a formed swing high
      if(close > recent_swing_high && recent_swing_high > 0.0) 
      {
         G_DXY_TF[dxy_idx].m5_continuation = true; 
      }
      
      if(CheckDXYMomentum(sym, ltf, 1))
      {
         G_DXY_TF[dxy_idx].m5_displacement = true;
         G_DXY_TF[dxy_idx].m5_momentum = true;
      }
      
      if(close > G_DXY_TF[dxy_idx].protected_low && G_DXY_TF[dxy_idx].protected_low > 0.0) 
      {
         G_DXY_TF[dxy_idx].m5_structure_valid = true;
      }
      
      if(G_DXY_TF[dxy_idx].m5_continuation && G_DXY_TF[dxy_idx].m5_structure_valid && G_DXY_TF[dxy_idx].m5_momentum)
      {
         G_DXY_TF[dxy_idx].m5_direction = 1;
         G_DXY_TF[dxy_idx].m5_last_confirmed_time = iTime(sym, ltf, 1);
      }
   }
   else if(expected_dir == -1) // Expected SELL
   {
      double recent_swing_low = GetDXYSwingLow(sym, ltf, 2, 1); // get a formed swing low
      if(close < recent_swing_low && recent_swing_low > 0.0) 
      {
         G_DXY_TF[dxy_idx].m5_continuation = true; 
      }
      
      if(CheckDXYMomentum(sym, ltf, -1))
      {
         G_DXY_TF[dxy_idx].m5_displacement = true;
         G_DXY_TF[dxy_idx].m5_momentum = true;
      }
      
      if(close < G_DXY_TF[dxy_idx].protected_high && G_DXY_TF[dxy_idx].protected_high > 0.0) 
      {
         G_DXY_TF[dxy_idx].m5_structure_valid = true;
      }
      
      if(G_DXY_TF[dxy_idx].m5_continuation && G_DXY_TF[dxy_idx].m5_structure_valid && G_DXY_TF[dxy_idx].m5_momentum)
      {
         G_DXY_TF[dxy_idx].m5_direction = -1;
         G_DXY_TF[dxy_idx].m5_last_confirmed_time = iTime(sym, ltf, 1);
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
      return true; 
   }
   
   if(!G_Pairs[pair_idx].isUSDPair)
   {
      reason = "NOT_USD_PAIR";
      return true; 
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
   
   int expected_dxy_direction = 0;
   if(G_Pairs[pair_idx].isUSDFirst) expected_dxy_direction = pair_direction;
   else if(G_Pairs[pair_idx].isUSDSecond) expected_dxy_direction = -pair_direction;
   
   // Evaluate
   EvaluateDXY_H1(dxy_idx, sym, htf);
   EvaluateDXY_M15(dxy_idx, sym, mtf, G_DXY_TF[dxy_idx].h1_direction);
   EvaluateDXY_M5(dxy_idx, sym, ltf, G_DXY_TF[dxy_idx].m15_direction);
   
   bool pass = true;
   string status_str = "PASS";
   
   // --- H1 Check ---
   if(!G_DXY_TF[dxy_idx].h1_structure_valid)
   {
      reason = "DXY_H1_STRUCTURE_INVALID"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].h1_not_sideway)
   {
      reason = "DXY_H1_SIDEWAY"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].h1_ema_aligned)
   {
      reason = "DXY_H1_EMA_NOT_ALIGNED"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].h1_price_position_valid)
   {
      reason = "DXY_H1_PRICE_POSITION_INVALID"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].h1_slope_valid)
   {
      reason = "DXY_H1_SLOPE_INVALID"; pass = false;
   }
   else if(G_DXY_TF[dxy_idx].h1_direction != expected_dxy_direction)
   {
      reason = "DXY_H1_DIRECTION_MISMATCH"; pass = false;
   }
   else if(G_DXY_TF[dxy_idx].h1_last_confirmed_time <= 0)
   {
      reason = "DXY_H1_NOT_INITIALIZED"; pass = false;
   }
   else if(!IsDXYH1Fresh(sym, G_DXY_TF[dxy_idx].h1_last_confirmed_time))
   {
      reason = "DXY_H1_STALE"; pass = false;
   }
   
   // --- M15 Check ---
   else if(!G_DXY_TF[dxy_idx].m15_structure_valid)
   {
      reason = "DXY_M15_STRUCTURE_INVALID"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].m15_aligned)
   {
      reason = "DXY_M15_NOT_ALIGNED"; pass = false;
   }
   else if(G_DXY_TF[dxy_idx].m15_direction != expected_dxy_direction)
   {
      reason = "DXY_M15_DIRECTION_MISMATCH"; pass = false;
   }
   else if(G_DXY_TF[dxy_idx].m15_last_confirmed_time <= 0)
   {
      reason = "DXY_M15_NOT_INITIALIZED"; pass = false;
   }
   else if(!IsDXYM15Fresh(sym, G_DXY_TF[dxy_idx].m15_last_confirmed_time))
   {
      reason = "DXY_M15_STALE"; pass = false;
   }
   
   // --- M5 Check ---
   else if(!G_DXY_TF[dxy_idx].m5_structure_valid)
   {
      reason = "DXY_M5_PROTECTED_STRUCTURE_BROKEN"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].m5_continuation)
   {
      reason = "DXY_M5_CONTINUATION_MISSING"; pass = false;
   }
   else if(!G_DXY_TF[dxy_idx].m5_momentum)
   {
      reason = "DXY_M5_MOMENTUM_MISSING"; pass = false;
   }
   else if(G_DXY_TF[dxy_idx].m5_direction != expected_dxy_direction)
   {
      reason = "DXY_M5_DIRECTION_MISMATCH"; pass = false;
   }
   else if(G_DXY_TF[dxy_idx].m5_last_confirmed_time <= 0)
   {
      reason = "DXY_M5_NOT_INITIALIZED"; pass = false;
   }
   else if(!IsDXYM5Fresh(sym, G_DXY_TF[dxy_idx].m5_last_confirmed_time))
   {
      reason = "DXY_M5_STALE"; pass = false;
   }
   
   if(!pass) status_str = "FAIL";
   
   G_DXY_TF[dxy_idx].status = status_str;
   G_DXY_TF[dxy_idx].reject_reason = reason;
   
   int h1_age = GetDXYClosedBarAge(sym, htf, G_DXY_TF[dxy_idx].h1_last_confirmed_time);
   bool h1_fresh = IsDXYH1Fresh(sym, G_DXY_TF[dxy_idx].h1_last_confirmed_time);
   int m15_age = GetDXYClosedBarAge(sym, mtf, G_DXY_TF[dxy_idx].m15_last_confirmed_time);
   bool m15_fresh = IsDXYM15Fresh(sym, G_DXY_TF[dxy_idx].m15_last_confirmed_time);
   int m5_age = GetDXYClosedBarAge(sym, ltf, G_DXY_TF[dxy_idx].m5_last_confirmed_time);
   bool m5_fresh = IsDXYM5Fresh(sym, G_DXY_TF[dxy_idx].m5_last_confirmed_time);
   
   Print("\n[DXY_TF][", G_Pairs[pair_idx].symbol, "]");
   PrintFormat("PAIR_DIRECTION=%s", (pair_direction == 1 ? "BUY" : "SELL"));
   PrintFormat("DXY_REQUIRED_DIRECTION=%s", (expected_dxy_direction == 1 ? "BUY" : "SELL"));
   Print("");
   PrintFormat("H1_DIRECTION=%s", (G_DXY_TF[dxy_idx].h1_direction == 1 ? "BUY" : (G_DXY_TF[dxy_idx].h1_direction == -1 ? "SELL" : "NONE")));
   PrintFormat("H1_STRUCTURE=%s", (G_DXY_TF[dxy_idx].h1_structure_valid ? "PASS" : "FAIL"));
   PrintFormat("H1_EMA=%s", (G_DXY_TF[dxy_idx].h1_ema_aligned ? "PASS" : "FAIL"));
   PrintFormat("H1_SLOPE=%s", (G_DXY_TF[dxy_idx].h1_slope_valid ? "PASS" : "FAIL"));
   PrintFormat("H1_PRICE=%s", (G_DXY_TF[dxy_idx].h1_price_position_valid ? "PASS" : "FAIL"));
   PrintFormat("H1_SIDEWAY=%s", (G_DXY_TF[dxy_idx].h1_not_sideway ? "PASS" : "FAIL"));
   PrintFormat("H1_AGE_BARS=%d", h1_age);
   PrintFormat("H1_FRESH=%s", (h1_fresh ? "PASS" : "FAIL"));
   Print("");
   PrintFormat("M15_DIRECTION=%s", (G_DXY_TF[dxy_idx].m15_direction == 1 ? "BUY" : (G_DXY_TF[dxy_idx].m15_direction == -1 ? "SELL" : "NONE")));
   PrintFormat("M15_STRUCTURE=%s", (G_DXY_TF[dxy_idx].m15_structure_valid ? "PASS" : "FAIL"));
   PrintFormat("M15_ALIGNMENT=%s", (G_DXY_TF[dxy_idx].m15_aligned ? "PASS" : "FAIL"));
   PrintFormat("M15_AGE_BARS=%d", m15_age);
   PrintFormat("M15_FRESH=%s", (m15_fresh ? "PASS" : "FAIL"));
   Print("");
   PrintFormat("M5_STRUCTURE=%s", (G_DXY_TF[dxy_idx].m5_continuation ? "PASS" : "FAIL"));
   PrintFormat("M5_MOMENTUM=%s", (G_DXY_TF[dxy_idx].m5_momentum ? "PASS" : "FAIL"));
   PrintFormat("M5_PROTECTED=%s", (G_DXY_TF[dxy_idx].m5_structure_valid ? "PASS" : "FAIL"));
   PrintFormat("M5_AGE_BARS=%d", m5_age);
   PrintFormat("M5_FRESH=%s", (m5_fresh ? "PASS" : "FAIL"));
   Print("");
   PrintFormat("FINAL=%s", status_str);
   if(!pass) PrintFormat("REASON=%s", reason);
   
   return pass;
}
