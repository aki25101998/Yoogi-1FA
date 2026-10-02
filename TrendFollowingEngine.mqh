//+------------------------------------------------------------------+
//|                                        TrendFollowingEngine.mqh  |
//|                                                  Yoogi Trading   |
//|   Trend-Following Entry Engine - 3-Layer Architecture            |
//|   Layer 1: H1 Trend Regime                                       |
//|   Layer 2: M15 Pullback Detection                                |
//|   Layer 3: M5 Entry Trigger                                      |
//+------------------------------------------------------------------+
#property strict

const string TF_ENGINE_VERSION = "TF_PHASE_3";

#include "TrendFollowingDiagnostics.mqh"

// ==================================================================
// HELPER: TF State Diagnostic Logging
// ==================================================================
string TFStateToString(int state)
{
   switch(state)
   {
      case TF_STATE_NONE: return "NONE";
      case TF_STATE_H1_TREND: return "H1_TREND";
      case TF_STATE_M15_PULLBACK: return "M15_PULLBACK";
      case TF_STATE_M5_WAIT_SWEEP: return "M5_WAIT_SWEEP";
      case TF_STATE_M5_WAIT_DISPLACEMENT: return "M5_WAIT_DISPLACEMENT";
      case TF_STATE_M5_WAIT_MSS: return "M5_WAIT_MSS";
      case TF_STATE_ENTRY_READY: return "ENTRY_READY";
   }
   return "UNKNOWN";
}

void SetTFState(int idx, int new_state, string reason)
{
   if(G_TF[idx].setup_state != new_state)
   {
      string sym = G_Pairs[idx].symbol;
      string old_str = TFStateToString(G_TF[idx].setup_state);
      string new_str = TFStateToString(new_state);
      PrintFormat("[FT_STATE][%s] FROM=%s TO=%s REASON=%s", sym, old_str, new_str, reason);
      G_TF[idx].setup_state = new_state;
   }
}

void LogTFReset(int idx, string scope, string reason)
{
   string sym = G_Pairs[idx].symbol;
   string prev_str = TFStateToString(G_TF[idx].setup_state);
   PrintFormat("[FT_RESET] SYMBOL=%s SCOPE=%s PREV_STATE=%s REASON=%s", sym, scope, prev_str, reason);
}

// ==================================================================
// HELPER: Reset toàn bộ TF Setup
// ==================================================================
void ResetTFSetup(int idx, string reason)
{
   if(G_TF[idx].setup_state != TF_STATE_NONE)
   {
      PrintFormat("[TREND-FOLLOWING][%s] RESET | Prev State=%d | Dir=%d | Reason=%s",
                  G_Pairs[idx].symbol, G_TF[idx].setup_state,
                  G_TF[idx].h1_trend_direction, reason);
   }
   
   G_TF[idx].h1_trend_direction = 0;
   G_TF[idx].h1_trend_quality = 0.0;
   G_TF[idx].h1_classification = "";
   G_TF[idx].h1_ema_aligned = false;
   G_TF[idx].h1_slope_positive = false;
   G_TF[idx].h1_price_above_ema = false;
   G_TF[idx].h1_structure_valid = false;
   G_TF[idx].h1_not_sideway = false;
   
   ResetTFM15Evidence(idx);
   ResetTFM5Evidence(idx);
   
   G_TF[idx].score_dxy = 0.0;
   G_TF[idx].total_score = 0.0;
   G_TF[idx].setup_state = TF_STATE_NONE;
   G_TF[idx].setup_bar_count = 0;
   G_TF[idx].status = "NO SETUP";
   
   G_TF[idx].h1_protected_structure = 0.0;
   G_TF[idx].tf_setup_id = 0;
   TFDiag_EndSetup(idx, reason);
}

// Reset only M5 evidence (keep H1 + M15 state)
void ResetTFM5Evidence(int idx)
{
   G_TF[idx].m5_sweep = false;
   G_TF[idx].m5_displacement = false;
   G_TF[idx].m5_mss = false;
   G_TF[idx].m5_momentum_cci = false;
   G_TF[idx].m5_momentum_rf = false;
   G_TF[idx].m5_momentum_pc = false;
   
   G_TF[idx].m5_displacement_range_atr = 0.0;
   G_TF[idx].m5_mss_break_distance_atr = 0.0;
   G_TF[idx].m5_entry_extension_mss_atr = 0.0;
   G_TF[idx].m5_entry_extension_prot_atr = 0.0;
   G_TF[idx].m5_displacement_range = 0.0;
   G_TF[idx].phase3_current_atr = 0.0;
   G_TF[idx].phase3_baseline_atr = 0.0;
   G_TF[idx].phase3_atr_ratio = 0.0;
   G_TF[idx].phase3_entry_candle_range = 0.0;
   G_TF[idx].phase3_entry_candle_body = 0.0;
   G_TF[idx].phase3_entry_candle_body_ratio = 0.0;
   G_TF[idx].phase3_entry_candle_close_loc = 0.0;
   G_TF[idx].phase3_spread_points = 0.0;
   G_TF[idx].phase3_spread_atr = 0.0;
   G_TF[idx].phase3_rel_disp_extension = 0.0;
   G_TF[idx].phase3_post_mss_adverse_atr = 0.0;
   G_TF[idx].phase3_entry_candle_time = 0;
   
   G_TF[idx].m5_sweep_time = 0;
   G_TF[idx].m5_displacement_time = 0;
   G_TF[idx].m5_mss_time = 0;
   G_TF[idx].m5_momentum_time = 0;
   G_TF[idx].m5_momentum_start_time = 0;
   G_TF[idx].m5_momentum_cci_time = 0;
   G_TF[idx].m5_momentum_rf_time = 0;
   G_TF[idx].m5_momentum_pc_time = 0;
   
   G_TF[idx].m5_sweep_price = 0.0;
   G_TF[idx].m5_displacement_price = 0.0;
   
   G_TF[idx].m5_sweep_age = 0;
   G_TF[idx].m5_displacement_age = 0;
   G_TF[idx].m5_mss_age = 0;
   G_TF[idx].m5_momentum_bars_elapsed = 0;
   // NOTE: m5_momentum_last_closed_time is intentionally NOT reset.
   // Keeps the last processed timestamp so the same closed candle won't be
   // re-counted as bar+1 after reset. It advances naturally on next new bar.
   G_TF[idx].m5_mss_break_level = 0.0;
   G_TF[idx].m5_sweep_level = 0.0;
   
   G_TF[idx].score_sweep = 0.0;
   G_TF[idx].score_displacement = 0.0;
   G_TF[idx].score_mss = 0.0;
   G_TF[idx].score_event_coherence = 0.0;
   G_TF[idx].score_momentum = 0.0;
   G_TF[idx].score_entry_distance = 0.0;
}

// Reset only M15 evidence
void ResetTFM15Evidence(int idx)
{
   G_TF[idx].m15_pullback_valid = false;
   G_TF[idx].m15_pullback_quality = 0.0;
   G_TF[idx].m15_pullback_bar_count = 0;
   G_TF[idx].m15_pullback_depth = 0.0;
   G_TF[idx].m15_ema_distance = 0.0;
   G_TF[idx].m15_pullback_start_time = 0;
   G_TF[idx].m15_impulse_high = 0.0;
   G_TF[idx].m15_impulse_low = 0.0;
   G_TF[idx].m15_impulse_start_time = 0;
   G_TF[idx].m15_impulse_end_time = 0;
   G_TF[idx].m15_protected_time = 0;
   G_TF[idx].m15_protected_confirmed_time = 0;
   G_TF[idx].score_m15_pullback = 0.0;
   G_TF[idx].m15_protected_low = 0.0;
   G_TF[idx].m15_protected_high = 0.0;
}

// ==================================================================
// LAYER 1: H1 TREND REGIME
// ==================================================================

// Evaluate H1 Trend Quality - Returns direction (1=BUY, -1=SELL, 0=NONE)
int EvaluateH1TrendRegime(int idx, double &out_protected_struct)
{
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES htf = G_Pairs[idx].htf; // H1
   
   out_protected_struct = 0.0;
   
   // --- EMA Alignment ---
   double ema20 = CalculateEMA_Generic(sym, htf, 20, 1);
   double ema50 = CalculateEMA_Generic(sym, htf, 50, 1);
   if(ema20 <= 0 || ema50 <= 0) return 0;
   
   // --- EMA50 Slope (compare current vs N bars ago) ---
   double ema50_prev = CalculateEMA_Generic(sym, htf, 50, 1 + TF_SLOPE_LOOKBACK);
   bool slope_bull = (ema50 > ema50_prev);
   bool slope_bear = (ema50 < ema50_prev);
   
   // --- Price Position ---
   double close[];
   if(CopyClose(sym, htf, 1, 1, close) < 1) return 0;
   
   // --- ATR for volatility check ---
   double atr = CalculateATR_Generic(sym, htf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return 0;
   
   // --- Market Structure: check HH/HL or LL/LH using swings ---
   double highs[], lows[];
   int struct_lookback = 50;
   if(!ReadHighLow_Generic(sym, htf, 1, struct_lookback, highs, lows)) return 0;
   
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   // Collect recent swing highs and lows (up to 4 each)
   double swH[4]; int swHidx[4]; int shCount = 0;
   double swL[4]; int swLidx[4]; int slCount = 0;
   
   for(int i = right; i < struct_lookback - left && (shCount < 4 || slCount < 4); i++)
   {
      if(shCount < 4 && IsSwingHigh(highs, i, left, right, struct_lookback))
      {
         swH[shCount] = highs[i];
         swHidx[shCount] = i;
         shCount++;
      }
      if(slCount < 4 && IsSwingLow(lows, i, left, right, struct_lookback))
      {
         swL[slCount] = lows[i];
         swLidx[slCount] = i;
         slCount++;
      }
   }
   
   // Determine market structure
   bool has_hh_hl = false; // Bullish structure
   bool has_ll_lh = false; // Bearish structure
   
   if(shCount >= 2 && slCount >= 2)
   {
      // BUY: Recent high > Previous high (HH) AND Recent low > Previous low (HL)
      // Note: index 0 = newest, index 1 = older
      has_hh_hl = (swH[0] > swH[1]) && (swL[0] > swL[1]);
      
      // SELL: Recent low < Previous low (LL) AND Recent high < Previous high (LH)
      has_ll_lh = (swL[0] < swL[1]) && (swH[0] < swH[1]);
   }
   
   // --- Sideway Detection ---
   // Calculate price range vs ATR ratio
   double h1_range = 0.0;
   if(shCount > 0 && slCount > 0)
   {
      double max_h = swH[0], min_l = swL[0];
      for(int i = 1; i < shCount; i++) if(swH[i] > max_h) max_h = swH[i];
      for(int i = 1; i < slCount; i++) if(swL[i] < min_l) min_l = swL[i];
      h1_range = (max_h - min_l) / atr;
   }
   bool not_sideway = (h1_range > TF_SIDEWAY_ATR_RATIO); // Meaningful range
   
   // --- Evaluate BUY Trend ---
   bool buy_ema = (ema20 > ema50);
   bool buy_slope = slope_bull;
   bool buy_price = (close[0] > ema50);
   bool buy_structure = has_hh_hl;
   
   // --- Evaluate SELL Trend ---
   bool sell_ema = (ema20 < ema50);
   bool sell_slope = slope_bear;
   bool sell_price = (close[0] < ema50);
   bool sell_structure = has_ll_lh;
   
   int direction = 0;
   
   bool buy_minimum = (buy_ema && buy_slope && buy_price && not_sideway);
   bool sell_minimum = (sell_ema && sell_slope && sell_price && not_sideway);
   
   if(buy_minimum)
   {
      direction = 1;
      G_TF[idx].h1_ema_aligned = buy_ema;
      G_TF[idx].h1_slope_positive = buy_slope;
      G_TF[idx].h1_price_above_ema = buy_price;
      G_TF[idx].h1_structure_valid = buy_structure;
      G_TF[idx].h1_not_sideway = not_sideway;
      G_TF[idx].h1_trend_quality = buy_structure ? TF_H1_QUALITY_STRONG : TF_H1_QUALITY_BASE;
      G_TF[idx].score_h1_trend = buy_structure ? TF_H1_QUALITY_STRONG : TF_H1_QUALITY_BASE;
      G_TF[idx].h1_classification = buy_structure ? "STRONG" : "BASE";
      
      // Set protected structure: if price breaks below recent swing low, trend invalid
      if(slCount >= 1) out_protected_struct = swL[0];
      
      Print("\n[TF_H1_QUALITY]");
      PrintFormat("symbol=%s", sym);
      PrintFormat("direction=BUY");
      PrintFormat("quality=%.0f/20", G_TF[idx].h1_trend_quality);
      PrintFormat("classification=%s", G_TF[idx].h1_classification);
      PrintFormat("structure_valid=%s", buy_structure ? "true" : "false");
   }
   else if(sell_minimum)
   {
      direction = -1;
      G_TF[idx].h1_ema_aligned = sell_ema;
      G_TF[idx].h1_slope_positive = sell_slope;
      G_TF[idx].h1_price_above_ema = sell_price;
      G_TF[idx].h1_structure_valid = sell_structure;
      G_TF[idx].h1_not_sideway = not_sideway;
      G_TF[idx].h1_trend_quality = sell_structure ? TF_H1_QUALITY_STRONG : TF_H1_QUALITY_BASE;
      G_TF[idx].score_h1_trend = sell_structure ? TF_H1_QUALITY_STRONG : TF_H1_QUALITY_BASE;
      G_TF[idx].h1_classification = sell_structure ? "STRONG" : "BASE";
      
      // Set protected structure: if price breaks above recent swing high, trend invalid
      if(shCount >= 1) out_protected_struct = swH[0];
      
      Print("\n[TF_H1_QUALITY]");
      PrintFormat("symbol=%s", sym);
      PrintFormat("direction=SELL");
      PrintFormat("quality=%.0f/20", G_TF[idx].h1_trend_quality);
      PrintFormat("classification=%s", G_TF[idx].h1_classification);
      PrintFormat("structure_valid=%s", sell_structure ? "true" : "false");
   }
   else
   {
      G_TF[idx].h1_trend_quality = 0.0;
      G_TF[idx].score_h1_trend = 0.0;
      G_TF[idx].h1_classification = "NONE";
   }
   
   datetime h1_time_arr[];
   datetime cur_h1_time = (CopyTime(sym, htf, 0, 1, h1_time_arr) >= 1) ? h1_time_arr[0] : 0;
   TFDiag_RecordH1(idx, direction, G_TF[idx].h1_trend_quality, cur_h1_time);
   
   return direction;
}

// ==================================================================
// PHASE 2B: M15 PULLBACK QUALITY VALIDATION
// ==================================================================
bool ValidateTFM15PullbackQuality(int idx, int trend_dir, string &reject_reason)
{
   string sym = G_Pairs[idx].symbol;
   reject_reason = "NONE";
   
   double atr = CalculateATR_Generic(sym, PERIOD_M15, InpReversal_ATR_Period, 1);
   if(atr <= 0) { reject_reason = "M15_ATR_INVALID"; return false; }
   
   double close[];
   if(CopyClose(sym, PERIOD_M15, 1, 1, close) < 1) { reject_reason = "M15_CLOSE_UNAVAILABLE"; return false; }
   
   double ema50 = CalculateEMA_Generic(sym, PERIOD_M15, 50, 1);
   double ema_dist_atr = (trend_dir == 1) ? ((ema50 - close[0]) / atr) : ((close[0] - ema50) / atr);
   
   double prot_struct = (trend_dir == 1) ? G_TF[idx].m15_protected_low : G_TF[idx].m15_protected_high;
   int impulse_age = G_TF[idx].m15_pullback_bar_count;
   if(G_TF[idx].m15_impulse_end_time > 0)
   {
      datetime cur_m15 = iTime(sym, PERIOD_M15, 1);
      if(cur_m15 >= G_TF[idx].m15_impulse_end_time)
         impulse_age = (int)((cur_m15 - G_TF[idx].m15_impulse_end_time) / PeriodSeconds(PERIOD_M15));
   }
   
   double depth_atr = G_TF[idx].m15_pullback_depth;
   
   if(trend_dir == 1) // BUY
   {
      if(G_TF[idx].h1_trend_direction != 1)
      {
         reject_reason = "H1_TREND_NOT_BUY";
      }
      else if(G_TF[idx].m15_impulse_high <= G_TF[idx].m15_impulse_low || G_TF[idx].m15_impulse_start_time >= G_TF[idx].m15_impulse_end_time)
      {
         reject_reason = "M15_IMPULSE_NOT_BULLISH";
      }
      else if(close[0] > G_TF[idx].m15_impulse_high)
      {
         reject_reason = "PRICE_ABOVE_IMPULSE_HIGH";
      }
      else if(G_TF[idx].m15_protected_low <= 0.0 || close[0] <= G_TF[idx].m15_protected_low)
      {
         reject_reason = "PROTECTED_HL_BROKEN";
      }
      else if(close[0] <= G_TF[idx].m15_impulse_low)
      {
         reject_reason = "ORIGIN_LOW_INVALIDATED";
      }
      else if(depth_atr < TF_PULLBACK_MIN_DEPTH_ATR || depth_atr > TF_PULLBACK_MAX_DEPTH_ATR)
      {
         reject_reason = "PULLBACK_DEPTH_OUT_OF_BOUNDS";
      }
      else if(ema_dist_atr < -0.5)
      {
         reject_reason = "EMA_DISTANCE_TOO_FAR";
      }
      else if(impulse_age > TF_PULLBACK_MAX_BARS)
      {
         reject_reason = "IMPULSE_STALE";
      }
   }
   else if(trend_dir == -1) // SELL
   {
      if(G_TF[idx].h1_trend_direction != -1)
      {
         reject_reason = "H1_TREND_NOT_SELL";
      }
      else if(G_TF[idx].m15_impulse_low >= G_TF[idx].m15_impulse_high || G_TF[idx].m15_impulse_start_time >= G_TF[idx].m15_impulse_end_time)
      {
         reject_reason = "M15_IMPULSE_NOT_BEARISH";
      }
      else if(close[0] < G_TF[idx].m15_impulse_low)
      {
         reject_reason = "PRICE_BELOW_IMPULSE_LOW";
      }
      else if(G_TF[idx].m15_protected_high <= 0.0 || close[0] >= G_TF[idx].m15_protected_high)
      {
         reject_reason = "PROTECTED_LH_BROKEN";
      }
      else if(close[0] >= G_TF[idx].m15_impulse_high)
      {
         reject_reason = "ORIGIN_HIGH_INVALIDATED";
      }
      else if(depth_atr < TF_PULLBACK_MIN_DEPTH_ATR || depth_atr > TF_PULLBACK_MAX_DEPTH_ATR)
      {
         reject_reason = "PULLBACK_DEPTH_OUT_OF_BOUNDS";
      }
      else if(ema_dist_atr < -0.5)
      {
         reject_reason = "EMA_DISTANCE_TOO_FAR";
      }
      else if(impulse_age > TF_PULLBACK_MAX_BARS)
      {
         reject_reason = "IMPULSE_STALE";
      }
   }
   
   bool pass = (reject_reason == "NONE");
   
   Print("\n[M15_QUALITY]");
   PrintFormat("symbol=%s", sym);
   PrintFormat("direction=%s", (trend_dir == 1 ? "BUY" : "SELL"));
   PrintFormat("protected_structure=%.5f", prot_struct);
   PrintFormat("pullback_depth_atr=%.2f", depth_atr);
   PrintFormat("ema_distance_atr=%.2f", ema_dist_atr);
   PrintFormat("impulse_age=%d", impulse_age);
   PrintFormat("quality=%s", pass ? "PASS" : "REJECT");
   PrintFormat("reason=%s", reject_reason);
   
   return pass;
}

// ==================================================================
// LAYER 2: M15 PULLBACK DETECTION
// ==================================================================

bool EvaluateM15Pullback(int idx, int trend_dir)
{
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES m15 = PERIOD_M15;
   
   double atr = CalculateATR_Generic(sym, m15, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double ema50 = CalculateEMA_Generic(sym, m15, 50, 1);
   if(ema50 <= 0) return false;
   
   double close[];
   if(CopyClose(sym, m15, 1, 1, close) < 1) return false;
   
   double m15_highs[], m15_lows[];
   int pb_lookback = 100;
   if(!ReadHighLow_Generic(sym, m15, 1, pb_lookback, m15_highs, m15_lows)) return false;
   
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   if(trend_dir == 1) // BUY trend → look for pullback DOWN
   {
      double distance_to_ema = (ema50 - close[0]) / atr;
      G_TF[idx].m15_ema_distance = distance_to_ema;
      
      // Look for valid impulse to allow refresh (only if not locked by M5 execution)
      if(G_TF[idx].setup_state <= TF_STATE_M15_PULLBACK)
      {
         int best_hl = -1, best_hh = -1, best_ol = -1, best_oh = -1;
         double best_score = -999999.0;
         int candidate_count = 0;
         
         int summary_raw_pairs = 0;
         int summary_rej_pullback_leg = 0;
         int summary_passed_relevance = 0;
         int summary_rej_structure = 0;
         int summary_valid_structs = 0;
         
         for(int i_hl = right; i_hl < pb_lookback - left; i_hl++)
         {
            if(!IsSwingLow(m15_lows, i_hl, left, right, pb_lookback)) continue;
            
            for(int i_hh = i_hl + 1; i_hh < pb_lookback - left; i_hh++)
            {
               if(!IsSwingHigh(m15_highs, i_hh, left, right, pb_lookback)) continue;
               
               summary_raw_pairs++;
               
               // HARD FILTER: Relevance Check (Price must be in Pullback Leg)
               if (close[0] > m15_highs[i_hh] || close[0] < m15_lows[i_hl])
               {
                   summary_rej_pullback_leg++;
                   if (summary_rej_pullback_leg <= 10) {
                       PrintFormat("[M15_STRUCTURE_REJECT][%s]\nreason=NOT_IN_PULLBACK_LEG\ndirection=BUY\ncurrent_close=%.5f\ncandidate_hl=%.5f\ncandidate_hh=%.5f\nhl_idx=%d\nhh_idx=%d", 
                                   sym, close[0], m15_lows[i_hl], m15_highs[i_hh], i_hl, i_hh);
                   }
                   continue;
               }
               
               summary_passed_relevance++;
               bool found_valid_structure = false;
               
               for(int i_oh = i_hh + 1; i_oh < pb_lookback - left; i_oh++)
               {
                  if(!IsSwingHigh(m15_highs, i_oh, left, right, pb_lookback)) continue;
                  
                  for(int i_ol = i_oh + 1; i_ol < pb_lookback - left; i_ol++)
                  {
                     if(!IsSwingLow(m15_lows, i_ol, left, right, pb_lookback)) continue;
                     
                     // Validate structure: Origin Low -> Ref High -> Higher High -> Protected HL
                     if(m15_highs[i_hh] > m15_highs[i_oh] && // Break of structure
                        m15_highs[i_oh] > m15_lows[i_ol] &&  // OH is above OL
                        m15_lows[i_hl] > m15_lows[i_ol] &&   // Protected HL is above OL
                        m15_highs[i_hh] > m15_lows[i_hl])    // HH is above HL
                     {
                        summary_valid_structs++;
                        candidate_count++;
                        
                        double freshness = 1.0 / (i_hl + 1.0);
                        double amplitude = (m15_highs[i_hh] - m15_lows[i_ol]) / atr;
                        double relevance = MathAbs(close[0] - m15_lows[i_hl]) / atr;
                        
                        // Rank: Relevance (High Priority), Freshness, Amplitude
                        double score = -(relevance * 100.0) + (freshness * 50.0) + (amplitude * 10.0);
                        
                        if(score > best_score)
                        {
                           best_score = score;
                           best_hl = i_hl;
                           best_hh = i_hh;
                           best_ol = i_ol;
                           best_oh = i_oh;
                        }
                        found_valid_structure = true;
                     }
                     else
                     {
                         if (!found_valid_structure && summary_rej_structure < 10) {
                             PrintFormat("[M15_STRUCTURE_REJECT][%s]\nreason=INVALID_QUAD\ndirection=BUY\norigin_low=%.5f\nreference_high=%.5f\nhigher_high=%.5f\nprotected_hl=%.5f\ncurrent_close=%.5f", 
                                         sym, m15_lows[i_ol], m15_highs[i_oh], m15_highs[i_hh], m15_lows[i_hl], close[0]);
                             summary_rej_structure++;
                         }
                     }
                  }
               }
               
               if(!found_valid_structure)
               {
                  if (summary_rej_structure < 10) {
                      PrintFormat("[M15_STRUCTURE_REJECT][%s]\nreason=NO_VALID_STRUCTURAL_BREAK\ndirection=BUY\ncurrent_close=%.5f\ncandidate_hl=%.5f\ncandidate_hh=%.5f\nhl_idx=%d\nhh_idx=%d", 
                                  sym, close[0], m15_lows[i_hl], m15_highs[i_hh], i_hl, i_hh);
                      summary_rej_structure++;
                  }
               }
            }
         }
         
         PrintFormat("[M15_FILTER_SUMMARY][%s]\ndirection=BUY\nraw_HL_HH_pairs=%d\nrejected_not_in_pullback_leg=%d\npassed_relevance=%d\nrejected_structure=%d\nvalid_structures=%d\nselected=%s", 
                     sym, summary_raw_pairs, summary_rej_pullback_leg, summary_passed_relevance, summary_rej_structure, summary_valid_structs, (candidate_count > 0 ? "YES" : "NO"));
         PrintFormat("[M15_IMPULSE_CANDIDATES][%s] BUY candidates=%d", sym, candidate_count);
         
         if(candidate_count > 0 && best_hl != -1 && best_hh != -1 && best_ol != -1 && best_oh != -1)
         {
             datetime t_hl[], t_hh[], t_ol[], t_oh[], t_conf[];
             if(CopyTime(sym, m15, best_hl + 1, 1, t_hl) == 1 && 
                CopyTime(sym, m15, best_hh + 1, 1, t_hh) == 1 && 
                CopyTime(sym, m15, best_ol + 1, 1, t_ol) == 1 &&
                CopyTime(sym, m15, best_oh + 1, 1, t_oh) == 1 &&
                CopyTime(sym, m15, best_hl - right + 1, 1, t_conf) == 1)
             {
                if(t_ol[0] < t_oh[0] && t_oh[0] < t_hh[0] && t_hh[0] < t_hl[0])
                {
                   bool is_newer_or_better = false;
                   if(G_TF[idx].m15_impulse_start_time == 0) is_newer_or_better = true;
                   else if(t_ol[0] > G_TF[idx].m15_impulse_start_time) is_newer_or_better = true;
                   else if(t_ol[0] == G_TF[idx].m15_impulse_start_time && t_hh[0] > G_TF[idx].m15_impulse_end_time) is_newer_or_better = true;
                   
                   if(is_newer_or_better)
                   {
                      if(G_TF[idx].m15_impulse_start_time != 0) {
                         PrintFormat("[M15_IMPULSE_REFRESH][%s] direction=BUY old_protected=%.5f new_protected=%.5f reason=NEW_STRUCTURAL_IMPULSE",
                                     sym, G_TF[idx].m15_protected_low, m15_lows[best_hl]);
                         LogTFReset(idx, "M5", "M15_IMPULSE_REFRESH");
                         ResetTFM5Evidence(idx);
                         if(G_TF[idx].setup_state > TF_STATE_M15_PULLBACK) {
                             SetTFState(idx, TF_STATE_M15_PULLBACK, "M15_IMPULSE_REFRESH");
                         }
                      }
                      
                      G_TF[idx].m15_impulse_high = m15_highs[best_hh];
                      G_TF[idx].m15_impulse_low = m15_lows[best_ol];
                      G_TF[idx].m15_protected_low = m15_lows[best_hl];
                      G_TF[idx].m15_impulse_start_time = t_ol[0];
                      G_TF[idx].m15_impulse_end_time = t_hh[0];
                      G_TF[idx].m15_protected_time = t_hl[0];
                      G_TF[idx].m15_protected_confirmed_time = t_conf[0];
                      G_TF[idx].m15_pullback_start_time = t_hh[0];
                      
                      double relevance = MathAbs(close[0] - m15_lows[best_hl]) / atr;
                      PrintFormat("[M15_SELECTED_IMPULSE][%s] direction=BUY origin_low=%.5f ref_high=%.5f impulse_hh=%.5f protected_hl=%.5f amplitude_atr=%.2f relevance=%.2f ranking_score=%.2f",
                                  sym, m15_lows[best_ol], m15_highs[best_oh], m15_highs[best_hh], m15_lows[best_hl], (m15_highs[best_hh] - m15_lows[best_ol])/atr, relevance, best_score);
                   }
                   else if (t_ol[0] < G_TF[idx].m15_impulse_start_time)
                   {
                      PrintFormat("[M15_IMPULSE_REJECT][%s] reason=OLDER_IMPULSE_FOUND", sym);
                   }
                }
             }
         }
         else
         {
             PrintFormat("[M15_NO_VALID_IMPULSE][%s]", sym);
         }
      }
      else
      {
         PrintFormat("[M15_CONTEXT_LOCKED][%s] direction=BUY state=%s", sym, TFStateToString(G_TF[idx].setup_state));
      }
      
      if(G_TF[idx].m15_impulse_high > 0.0)
      {
         double depth = (G_TF[idx].m15_impulse_high - close[0]) / atr;
         G_TF[idx].m15_pullback_depth = depth;
         
         string m15_rej_reason = "";
         datetime m15_bar_time = iTime(sym, PERIOD_M15, 1);
         if(ValidateTFM15PullbackQuality(idx, trend_dir, m15_rej_reason))
         {
            G_TF[idx].m15_pullback_quality = 20.0;
            G_TF[idx].score_m15_pullback = 20.0;
            G_TF[idx].m15_pullback_valid = true;
            TFDiag_RecordM15(idx, trend_dir, true, "NONE", m15_bar_time);
            TFDiag_RecordFunnelStep(idx, trend_dir, TF_FUNNEL_M15_VALID);
            TFDiag_LogFunnel(idx, trend_dir, "M15_PULLBACK", "PASS", StringFormat("depth=%.2f ATR", depth));
            return true;
         }
         else
         {
            G_TF[idx].m15_pullback_quality = 0.0;
            G_TF[idx].score_m15_pullback = 0.0;
            G_TF[idx].m15_pullback_valid = false;
            TFDiag_RecordM15(idx, trend_dir, false, m15_rej_reason, m15_bar_time);
            TFDiag_LogFunnel(idx, trend_dir, "M15_PULLBACK", "REJECT", m15_rej_reason);
         }
      }
      else
      {
         datetime m15_bar_time = iTime(sym, PERIOD_M15, 1);
         TFDiag_RecordM15(idx, trend_dir, false, "M15_IMPULSE_NOT_BULLISH", m15_bar_time);
         TFDiag_LogFunnel(idx, trend_dir, "M15_PULLBACK", "REJECT", "NO_VALID_BULLISH_IMPULSE");
      }
   }
   else if(trend_dir == -1) // SELL trend → look for pullback UP
   {
      double distance_to_ema = (close[0] - ema50) / atr;
      G_TF[idx].m15_ema_distance = distance_to_ema;
      
      // Look for valid impulse to allow refresh (only if not locked by M5 execution)
      if(G_TF[idx].setup_state <= TF_STATE_M15_PULLBACK)
      {
         int best_lh = -1, best_ll = -1, best_oh = -1, best_ol = -1;
         double best_score = -999999.0;
         int candidate_count = 0;
         
         int summary_raw_pairs = 0;
         int summary_rej_pullback_leg = 0;
         int summary_passed_relevance = 0;
         int summary_rej_structure = 0;
         int summary_valid_structs = 0;
         
         for(int i_lh = right; i_lh < pb_lookback - left; i_lh++)
         {
            if(!IsSwingHigh(m15_highs, i_lh, left, right, pb_lookback)) continue;
            
            for(int i_ll = i_lh + 1; i_ll < pb_lookback - left; i_ll++)
            {
               if(!IsSwingLow(m15_lows, i_ll, left, right, pb_lookback)) continue;
               
               summary_raw_pairs++;
               
               // HARD FILTER: Relevance Check (Price must be in Pullback Leg)
               if (close[0] < m15_lows[i_ll] || close[0] > m15_highs[i_lh])
               {
                   summary_rej_pullback_leg++;
                   if (summary_rej_pullback_leg <= 10) {
                       PrintFormat("[M15_STRUCTURE_REJECT][%s]\nreason=NOT_IN_PULLBACK_LEG\ndirection=SELL\ncurrent_close=%.5f\ncandidate_lh=%.5f\ncandidate_ll=%.5f\nlh_idx=%d\nll_idx=%d", 
                                   sym, close[0], m15_highs[i_lh], m15_lows[i_ll], i_lh, i_ll);
                   }
                   continue;
               }
               
               summary_passed_relevance++;
               bool found_valid_structure = false;
               
               for(int i_ol = i_ll + 1; i_ol < pb_lookback - left; i_ol++)
               {
                  if(!IsSwingLow(m15_lows, i_ol, left, right, pb_lookback)) continue;
                  
                  for(int i_oh = i_ol + 1; i_oh < pb_lookback - left; i_oh++)
                  {
                     if(!IsSwingHigh(m15_highs, i_oh, left, right, pb_lookback)) continue;
                     
                     // Validate structure: Origin High -> Ref Low -> Lower Low -> Protected LH
                     if(m15_lows[i_ll] < m15_lows[i_ol] && // Break of structure
                        m15_lows[i_ol] < m15_highs[i_oh] &&  // OL is below OH
                        m15_highs[i_lh] < m15_highs[i_oh] &&   // Protected LH is below OH
                        m15_lows[i_ll] < m15_highs[i_lh])    // LL is below LH
                     {
                        summary_valid_structs++;
                        candidate_count++;
                        
                        double freshness = 1.0 / (i_lh + 1.0);
                        double amplitude = (m15_highs[i_oh] - m15_lows[i_ll]) / atr;
                        double relevance = MathAbs(close[0] - m15_highs[i_lh]) / atr;
                        
                        // Rank: Relevance (High Priority), Freshness, Amplitude
                        double score = -(relevance * 100.0) + (freshness * 50.0) + (amplitude * 10.0);
                        
                        if(score > best_score)
                        {
                           best_score = score;
                           best_lh = i_lh;
                           best_ll = i_ll;
                           best_oh = i_oh;
                           best_ol = i_ol;
                        }
                        found_valid_structure = true;
                     }
                     else
                     {
                         if (!found_valid_structure && summary_rej_structure < 10) {
                             PrintFormat("[M15_STRUCTURE_REJECT][%s]\nreason=INVALID_QUAD\ndirection=SELL\norigin_high=%.5f\nreference_low=%.5f\nlower_low=%.5f\nprotected_lh=%.5f\ncurrent_close=%.5f", 
                                         sym, m15_highs[i_oh], m15_lows[i_ol], m15_lows[i_ll], m15_highs[i_lh], close[0]);
                             summary_rej_structure++;
                         }
                     }
                  }
               }
               
               if(!found_valid_structure)
               {
                  if (summary_rej_structure < 10) {
                      PrintFormat("[M15_STRUCTURE_REJECT][%s]\nreason=NO_VALID_STRUCTURAL_BREAK\ndirection=SELL\ncurrent_close=%.5f\ncandidate_lh=%.5f\ncandidate_ll=%.5f\nlh_idx=%d\nll_idx=%d", 
                                  sym, close[0], m15_highs[i_lh], m15_lows[i_ll], i_lh, i_ll);
                      summary_rej_structure++;
                  }
               }
            }
         }
         
         PrintFormat("[M15_FILTER_SUMMARY][%s]\ndirection=SELL\nraw_HL_HH_pairs=%d\nrejected_not_in_pullback_leg=%d\npassed_relevance=%d\nrejected_structure=%d\nvalid_structures=%d\nselected=%s", 
                     sym, summary_raw_pairs, summary_rej_pullback_leg, summary_passed_relevance, summary_rej_structure, summary_valid_structs, (candidate_count > 0 ? "YES" : "NO"));
         PrintFormat("[M15_IMPULSE_CANDIDATES][%s] SELL candidates=%d", sym, candidate_count);
         
         if(candidate_count > 0 && best_lh != -1 && best_ll != -1 && best_oh != -1 && best_ol != -1)
         {
             datetime t_lh[], t_ll[], t_oh[], t_ol[], t_conf[];
             if(CopyTime(sym, m15, best_lh + 1, 1, t_lh) == 1 && 
                CopyTime(sym, m15, best_ll + 1, 1, t_ll) == 1 && 
                CopyTime(sym, m15, best_oh + 1, 1, t_oh) == 1 &&
                CopyTime(sym, m15, best_ol + 1, 1, t_ol) == 1 &&
                CopyTime(sym, m15, best_lh - right + 1, 1, t_conf) == 1)
             {
                if(t_oh[0] < t_ol[0] && t_ol[0] < t_ll[0] && t_ll[0] < t_lh[0])
                {
                   bool is_newer_or_better = false;
                   if(G_TF[idx].m15_impulse_start_time == 0) is_newer_or_better = true;
                   else if(t_oh[0] > G_TF[idx].m15_impulse_start_time) is_newer_or_better = true;
                   else if(t_oh[0] == G_TF[idx].m15_impulse_start_time && t_ll[0] > G_TF[idx].m15_impulse_end_time) is_newer_or_better = true;
                   
                   if(is_newer_or_better)
                   {
                      if(G_TF[idx].m15_impulse_start_time != 0) {
                         PrintFormat("[M15_IMPULSE_REFRESH][%s] direction=SELL old_protected=%.5f new_protected=%.5f reason=NEW_STRUCTURAL_IMPULSE",
                                     sym, G_TF[idx].m15_protected_high, m15_highs[best_lh]);
                         LogTFReset(idx, "M5", "M15_IMPULSE_REFRESH");
                         ResetTFM5Evidence(idx);
                         if(G_TF[idx].setup_state > TF_STATE_M15_PULLBACK) {
                             SetTFState(idx, TF_STATE_M15_PULLBACK, "M15_IMPULSE_REFRESH");
                         }
                      }
                      
                      G_TF[idx].m15_impulse_low = m15_lows[best_ll];
                      G_TF[idx].m15_impulse_high = m15_highs[best_oh];
                      G_TF[idx].m15_protected_high = m15_highs[best_lh];
                      G_TF[idx].m15_impulse_start_time = t_oh[0];
                      G_TF[idx].m15_impulse_end_time = t_ll[0];
                      G_TF[idx].m15_protected_time = t_lh[0];
                      G_TF[idx].m15_protected_confirmed_time = t_conf[0];
                      G_TF[idx].m15_pullback_start_time = t_ll[0];
                      
                      double relevance = MathAbs(close[0] - m15_highs[best_lh]) / atr;
                      PrintFormat("[M15_SELECTED_IMPULSE][%s] direction=SELL origin_high=%.5f ref_low=%.5f impulse_ll=%.5f protected_lh=%.5f amplitude_atr=%.2f relevance=%.2f ranking_score=%.2f",
                                  sym, m15_highs[best_oh], m15_lows[best_ol], m15_lows[best_ll], m15_highs[best_lh], (m15_highs[best_oh] - m15_lows[best_ll])/atr, relevance, best_score);
                   }
                   else if (t_oh[0] < G_TF[idx].m15_impulse_start_time)
                   {
                      PrintFormat("[M15_IMPULSE_REJECT][%s] reason=OLDER_IMPULSE_FOUND", sym);
                   }
                }
             }
         }
         else
         {
             PrintFormat("[M15_NO_VALID_IMPULSE][%s]", sym);
         }
      }
      else
      {
         PrintFormat("[M15_CONTEXT_LOCKED][%s] direction=SELL state=%s", sym, TFStateToString(G_TF[idx].setup_state));
      }
      
      if(G_TF[idx].m15_impulse_low > 0.0)
      {
         double depth = (close[0] - G_TF[idx].m15_impulse_low) / atr;
         G_TF[idx].m15_pullback_depth = depth;
         
         string m15_rej_reason = "";
         datetime m15_bar_time = iTime(sym, PERIOD_M15, 1);
         if(ValidateTFM15PullbackQuality(idx, trend_dir, m15_rej_reason))
         {
            G_TF[idx].m15_pullback_quality = 20.0;
            G_TF[idx].score_m15_pullback = 20.0;
            G_TF[idx].m15_pullback_valid = true;
            TFDiag_RecordM15(idx, trend_dir, true, "NONE", m15_bar_time);
            TFDiag_RecordFunnelStep(idx, trend_dir, TF_FUNNEL_M15_VALID);
            TFDiag_LogFunnel(idx, trend_dir, "M15_PULLBACK", "PASS", StringFormat("depth=%.2f ATR", depth));
            return true;
         }
         else
         {
            G_TF[idx].m15_pullback_quality = 0.0;
            G_TF[idx].score_m15_pullback = 0.0;
            G_TF[idx].m15_pullback_valid = false;
            TFDiag_RecordM15(idx, trend_dir, false, m15_rej_reason, m15_bar_time);
            TFDiag_LogFunnel(idx, trend_dir, "M15_PULLBACK", "REJECT", m15_rej_reason);
         }
      }
      else
      {
         datetime m15_bar_time = iTime(sym, PERIOD_M15, 1);
         TFDiag_RecordM15(idx, trend_dir, false, "M15_IMPULSE_NOT_BEARISH", m15_bar_time);
         TFDiag_LogFunnel(idx, trend_dir, "M15_PULLBACK", "REJECT", "NO_VALID_BEARISH_IMPULSE");
      }
   }
   
   return false;
}

// ==================================================================
// HELPER: M5 STRUCTURAL SIGNIFICANCE CHECK
// ==================================================================
// Determines whether an M5 swing has structural significance by measuring
// the price reaction AWAY from the swing using only closed bar data.
// A structurally significant swing must have produced a meaningful
// price reaction (normalized by ATR) that creates local structure.
//
// Returns: reaction_ratio (ATR-normalized). 0.0 = not significant.
// Uses only bars between the swing and the most recent closed bar.
// No look-ahead: only data at indices [right .. swing_idx-1] relative
// to the swing formation is used (all confirmed/closed bars).

const double TF_M5_MIN_REACTION_ATR = 0.5; // Minimum reaction to qualify as structural

double MeasureSwingReaction(const double &highs[], const double &lows[],
                            int swing_idx, int right_bars, int direction,
                            double swing_price, double atr, int array_size)
{
   if(atr <= 0.0) return 0.0;
   if(swing_idx <= right_bars) return 0.0; // Not enough bars after swing
   
   // Scan bars BETWEEN the swing confirmation and current bar
   // Index 0 = newest closed bar, swing_idx = swing bar
   // Bars right_bars..swing_idx-1 are AFTER the swing was confirmed
   // (lower index = more recent = chronologically after the swing)
   
   if(direction == 1) // BUY: swing low → measure upward reaction
   {
      double max_high = 0.0;
      for(int j = right_bars; j < swing_idx; j++)
      {
         if(highs[j] > max_high) max_high = highs[j];
      }
      if(max_high <= swing_price) return 0.0;
      return (max_high - swing_price) / atr;
   }
   else // SELL: swing high → measure downward reaction
   {
      double min_low = 999999.0;
      for(int j = right_bars; j < swing_idx; j++)
      {
         if(lows[j] < min_low) min_low = lows[j];
      }
      if(min_low >= swing_price) return 0.0;
      return (swing_price - min_low) / atr;
   }
}

// Check if swing was broken (violated) before the current sweep candle.
// For BUY: check if any bar between swing and bar 2 went below swing_price
// For SELL: check if any bar between swing and bar 2 went above swing_price
// Bar index 1 = the sweep candle itself (excluded from this check)
bool IsSwingIntactBeforeSweep(const double &highs[], const double &lows[],
                              int swing_idx, int direction, double swing_price,
                              int array_size)
{
   // Check bars from 2 (one before sweep candle) up to swing_idx-1
   // These are bars AFTER the swing was formed, BEFORE the sweep candle
   if(swing_idx <= 2) return true; // Not enough bars to check
   
   if(direction == 1) // BUY: swing low must not have been broken below
   {
      for(int j = 2; j < swing_idx; j++)
      {
         if(lows[j] < swing_price) return false;
      }
   }
   else // SELL: swing high must not have been broken above
   {
      for(int j = 2; j < swing_idx; j++)
      {
         if(highs[j] > swing_price) return false;
      }
   }
   return true;
}

// ==================================================================
// LAYER 3: M5 ENTRY TRIGGER
// ==================================================================

void EvaluateM5Trigger(int idx, int trend_dir)
{
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES m5 = PERIOD_M5;
   
   datetime m5_tm[];
   if(CopyTime(sym, m5, 1, 1, m5_tm) < 1) return; // Use closed candle time
   datetime current_time = m5_tm[0];
   
   // --- GIAI ĐOẠN A: Event formation freshness ---
   // TF_MAX_EVENT_BARS controls Sweep -> Displacement (max 5 bars).
   // TF_MSS_MAX_WAIT_BARS controls Displacement -> MSS (max 15 bars).
   // It MUST NOT apply once state reaches TF_STATE_ENTRY_READY (Giai đoạn C: Momentum confirmation window).
   long period_sec = PeriodSeconds(m5);
   if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_DISPLACEMENT)
   {
      if(G_TF[idx].m5_sweep && G_TF[idx].m5_sweep_time > 0)
      {
         long bars_since_sweep = (current_time - G_TF[idx].m5_sweep_time) / period_sec;
         if(bars_since_sweep > TF_MAX_EVENT_BARS)
         {
            TFDiag_RecordCoherenceTimeout(idx, trend_dir, (int)bars_since_sweep, current_time);
            TFDiag_LogFunnel(idx, trend_dir, "EVENT_COHERENCE", "REJECT", StringFormat("TIMEOUT: bars_since_sweep=%d > %d", bars_since_sweep, TF_MAX_EVENT_BARS));
            ResetTFM5Evidence(idx);
            SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M5_TIMEOUT");
            return;
         }
      }
   }
   else if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_MSS)
   {
      // Invariant: M15 pullback context must remain valid while waiting for MSS
      if(!G_TF[idx].m15_pullback_valid || CheckM15PullbackInvalidation(idx))
      {
         LogTFReset(idx, "M15", "M15_INVALIDATION_DURING_MSS_WAIT");
         ResetTFM15Evidence(idx);
         ResetTFM5Evidence(idx);
         SetTFState(idx, TF_STATE_H1_TREND, "M15_INVALIDATION");
         G_TF[idx].status = "M15 PULLBACK INVALID";
         TFDiag_RecordM15Invalidation(idx, trend_dir);
         TFDiag_LogFunnel(idx, trend_dir, "M15_INVALIDATION", "REVERSAL_BROKEN");
         return;
      }
      
      // Stage B Freshness: Displacement -> MSS must complete within TF_MSS_MAX_WAIT_BARS
      if(G_TF[idx].m5_displacement && G_TF[idx].m5_displacement_time > 0)
      {
         long bars_since_disp = (current_time - G_TF[idx].m5_displacement_time) / period_sec;
         long bars_since_sweep = (G_TF[idx].m5_sweep_time > 0) ? ((current_time - G_TF[idx].m5_sweep_time) / period_sec) : 0;
         if(bars_since_disp > TF_MSS_MAX_WAIT_BARS)
         {
            TFDiag_RecordMSSTimeout(idx, trend_dir, (int)bars_since_disp, current_time);
            TFDiag_LogFunnel(idx, trend_dir, "M5_MSS", "TIMEOUT",
               StringFormat("bars_since_displacement=%d > TF_MSS_MAX_WAIT_BARS=%d (bars_since_sweep=%d, TF_MAX_EVENT_BARS=%d)",
                            bars_since_disp, TF_MSS_MAX_WAIT_BARS, bars_since_sweep, TF_MAX_EVENT_BARS));
            ResetTFM5Evidence(idx);
            SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M5_TIMEOUT");
            return;
         }
      }
      else if(G_TF[idx].m5_displacement_time <= 0)
      {
         ResetTFM5Evidence(idx);
         SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M5_DISP_MISSING");
         return;
      }
   }
   
   // --- Find qualified swings on M5 ---
   double m5_highs[], m5_lows[];
   int m5_lookback = InpLiquiditySweepLookback;
   if(!ReadHighLow_Generic(sym, m5, 1, m5_lookback, m5_highs, m5_lows)) return;
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   // === STATE MACHINE ===
   if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_SWEEP)
   {
      double sweep_target = 0.0;
      int best_candidate_idx = -1;
      double best_score = -1.0;
      int candidate_count = 0;
      
      int sum_raw = 0;
      int sum_qualified = 0;
      int sum_rej_consumed = 0;
      int sum_rej_broken = 0;
      int sum_rej_range = 0;
      int sum_rej_nosweep = 0;
      
      double close_arr[];
      CopyClose(sym, m5, 1, 1, close_arr);
      double current_close = (ArraySize(close_arr) > 0) ? close_arr[0] : 0.0;
      
      double atr = CalculateATR_Generic(sym, m5, InpReversal_ATR_Period, 1);
      
      if(trend_dir == 1) {
         for(int i = right; i < m5_lookback - left; i++) {
            if(IsSwingLow(m5_lows, i, left, right, m5_lookback)) {
               sum_raw++;
               double target = m5_lows[i];
               if(!(target >= G_TF[idx].m15_protected_low && target <= G_TF[idx].m15_impulse_high)) {
                  sum_rej_range++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=BUY\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_LOW\nQUALIFIED=NO\nREJECT_REASON=OUTSIDE_M15_RANGE\nIS_CONSUMED=NO\nIS_SWING_INTACT=YES\nIN_M15_RANGE=NO\nREACTION_RATIO=0.0\nRANK_SCORE=0.0", sym, current_close, target);
                  PrintFormat("[M5_TARGET_INVALIDATED]\nSYMBOL=%s\nTARGET=%.5f\nREASON=OUTSIDE_M15_RANGE", sym, target);
                  continue;
               }
               if(current_time <= G_TF[idx].m15_protected_confirmed_time) {
                  continue; // Don't spam, just wait for confirmation
               }
               
               // MUST be structurally relevant: Formed DURING the pullback, not before
               datetime t_arr[];
               if(CopyTime(sym, m5, i + 1, 1, t_arr) != 1) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=TARGET_TIME_UNAVAILABLE idx=%d", sym, i);
                  continue;
               }
               
               datetime target_time = t_arr[0];
               if (target_time < G_TF[idx].m15_pullback_start_time) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=TARGET_BEFORE_PULLBACK target=%.5f time=%s", sym, target, TimeToString(target_time));
                  continue;
               }
               
               // --- STRUCTURAL SIGNIFICANCE CHECK (before consumed/sweep) ---
               double reaction_ratio = MeasureSwingReaction(m5_highs, m5_lows,
                  i, right, 1, target, atr, m5_lookback);
               
               if(reaction_ratio < TF_M5_MIN_REACTION_ATR) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=NOT_STRUCTURALLY_SIGNIFICANT target=%.5f reaction_ratio=%.2f threshold=%.2f",
                              sym, target, reaction_ratio, TF_M5_MIN_REACTION_ATR);
                  continue;
               }
               
               // Check swing integrity: not broken before sweep
               if(!IsSwingIntactBeforeSweep(m5_highs, m5_lows, i, 1, target, m5_lookback)) {
                  sum_rej_broken++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=BUY\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_LOW\nQUALIFIED=NO\nREJECT_REASON=SWING_BROKEN_BEFORE_SWEEP\nIS_CONSUMED=NO\nIS_SWING_INTACT=NO\nIN_M15_RANGE=YES\nREACTION_RATIO=%.2f\nRANK_SCORE=0.0", sym, current_close, target, reaction_ratio);
                  PrintFormat("[M5_TARGET_INVALIDATED]\nSYMBOL=%s\nTARGET=%.5f\nREASON=SWING_BROKEN_BEFORE_SWEEP", sym, target);
                  continue;
               }
               
               // Filter: already consumed by intermediate candles?
               bool consumed = false;
               for(int j = 1; j < i; j++) {
                  if(m5_lows[j] < target) { consumed = true; break; }
               }
               
               if(consumed) {
                  sum_rej_consumed++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=BUY\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_LOW\nQUALIFIED=NO\nREJECT_REASON=CONSUMED\nIS_CONSUMED=YES\nIS_SWING_INTACT=YES\nIN_M15_RANGE=YES\nREACTION_RATIO=%.2f\nRANK_SCORE=0.0", sym, current_close, target, reaction_ratio);
                  PrintFormat("[M5_TARGET_INVALIDATED]\nSYMBOL=%s\nTARGET=%.5f\nREASON=CONSUMED", sym, target);
                  continue;
               }
               
               if(!DetectLiquiditySweep(sym, m5, trend_dir, target)) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=NO_LIQUIDITY_SWEEP target=%.5f", sym, target);
                  continue;
               }
               
               candidate_count++;
               double freshness = 1.0 / (i + 1.0);
               double dist = 0;
               if(atr > 0) dist = MathAbs(target - G_TF[idx].m15_protected_low) / atr;
               
               double structural_depth = 0;
               if(atr > 0) structural_depth = (G_TF[idx].m15_impulse_high - target) / atr;
               
               // Priorities:
               // 1. Structural significance (price reaction) - highest weight
               // 2. Structural depth (depth into pullback) - medium weight
               // 3. Proximity to protected level (dist) - negative weight
               // 4. Freshness - lowest weight
               double score = (reaction_ratio * 200.0) + (structural_depth * 50.0) - (dist * 30.0) + (freshness * 5.0);
               
               if(score > best_score) {
                  best_score = score;
                  best_candidate_idx = i;
                  sweep_target = target;
               }
            }
         }
      } else {
         for(int i = right; i < m5_lookback - left; i++) {
            if(IsSwingHigh(m5_highs, i, left, right, m5_lookback)) {
               sum_raw++;
               double target = m5_highs[i];
               if(!(target <= G_TF[idx].m15_protected_high && target >= G_TF[idx].m15_impulse_low)) {
                  sum_rej_range++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=SELL\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_HIGH\nQUALIFIED=NO\nREJECT_REASON=OUTSIDE_M15_RANGE\nIS_CONSUMED=NO\nIS_SWING_INTACT=YES\nIN_M15_RANGE=NO\nREACTION_RATIO=0.0\nRANK_SCORE=0.0", sym, current_close, target);
                  PrintFormat("[M5_TARGET_INVALIDATED]\nSYMBOL=%s\nTARGET=%.5f\nREASON=OUTSIDE_M15_RANGE", sym, target);
                  continue;
               }
               if(current_time <= G_TF[idx].m15_protected_confirmed_time) {
                  continue; // Don't spam, just wait for confirmation
               }
               
               // MUST be structurally relevant: Formed DURING the pullback, not before
               datetime t_arr[];
               if(CopyTime(sym, m5, i + 1, 1, t_arr) != 1) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=TARGET_TIME_UNAVAILABLE idx=%d", sym, i);
                  continue;
               }
               
               datetime target_time = t_arr[0];
               if (target_time < G_TF[idx].m15_pullback_start_time) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=TARGET_BEFORE_PULLBACK target=%.5f time=%s", sym, target, TimeToString(target_time));
                  continue;
               }
               
               // --- STRUCTURAL SIGNIFICANCE CHECK (before consumed/sweep) ---
               double reaction_ratio = MeasureSwingReaction(m5_highs, m5_lows,
                  i, right, -1, target, atr, m5_lookback);
               
               if(reaction_ratio < TF_M5_MIN_REACTION_ATR) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=NOT_STRUCTURALLY_SIGNIFICANT target=%.5f reaction_ratio=%.2f threshold=%.2f",
                              sym, target, reaction_ratio, TF_M5_MIN_REACTION_ATR);
                  continue;
               }
               
               // Check swing integrity: not broken before sweep
               if(!IsSwingIntactBeforeSweep(m5_highs, m5_lows, i, -1, target, m5_lookback)) {
                  sum_rej_broken++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=SELL\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_HIGH\nQUALIFIED=NO\nREJECT_REASON=SWING_BROKEN_BEFORE_SWEEP\nIS_CONSUMED=NO\nIS_SWING_INTACT=NO\nIN_M15_RANGE=YES\nREACTION_RATIO=%.2f\nRANK_SCORE=0.0", sym, current_close, target, reaction_ratio);
                  PrintFormat("[M5_TARGET_INVALIDATED]\nSYMBOL=%s\nTARGET=%.5f\nREASON=SWING_BROKEN_BEFORE_SWEEP", sym, target);
                  continue;
               }
               
               // Filter: already consumed by intermediate candles?
               bool consumed = false;
               for(int j = 1; j < i; j++) {
                  if(m5_highs[j] > target) { consumed = true; break; }
               }
               if(consumed) {
                  sum_rej_consumed++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=SELL\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_HIGH\nQUALIFIED=NO\nREJECT_REASON=CONSUMED\nIS_CONSUMED=YES\nIS_SWING_INTACT=YES\nIN_M15_RANGE=YES\nREACTION_RATIO=%.2f\nRANK_SCORE=0.0", sym, current_close, target, reaction_ratio);
                  PrintFormat("[M5_TARGET_INVALIDATED]\nSYMBOL=%s\nTARGET=%.5f\nREASON=CONSUMED", sym, target);
                  continue;
               }
               
               if(!DetectLiquiditySweep(sym, m5, trend_dir, target)) {
                  PrintFormat("[M5_SWEEP_REJECT][%s] reason=NO_LIQUIDITY_SWEEP target=%.5f", sym, target);
                  sum_rej_nosweep++;
                  PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=SELL\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=REJECTED\nCANDIDATE_SOURCE=M5_SWING_HIGH\nQUALIFIED=YES\nREJECT_REASON=NO_LIQUIDITY_SWEEP\nIS_CONSUMED=NO\nIS_SWING_INTACT=YES\nIN_M15_RANGE=YES\nREACTION_RATIO=%.2f\nRANK_SCORE=0.0", sym, current_close, target, reaction_ratio);
                  continue;
               }
               
               candidate_count++;
               double freshness = 1.0 / (i + 1.0);
               double dist = 0;
               if(atr > 0) dist = MathAbs(target - G_TF[idx].m15_protected_high) / atr;
               
               double structural_depth = 0;
               if(atr > 0) structural_depth = (target - G_TF[idx].m15_impulse_low) / atr;
               
               // Priorities:
               // 1. Structural significance (price reaction) - highest weight
               // 2. Structural depth (depth into pullback) - medium weight
               // 3. Proximity to protected level (dist) - negative weight
               // 4. Freshness - lowest weight
               double score = (reaction_ratio * 200.0) + (structural_depth * 50.0) - (dist * 30.0) + (freshness * 5.0);
               
               sum_qualified++;
               PrintFormat("[M5_TARGET_LIFECYCLE]\nSYMBOL=%s\nDIRECTION=SELL\nCURRENT_CLOSE=%.5f\nTARGET=%.5f\nTARGET_STATUS=SWEPT\nCANDIDATE_SOURCE=M5_SWING_HIGH\nQUALIFIED=YES\nREJECT_REASON=NONE\nIS_CONSUMED=NO\nIS_SWING_INTACT=YES\nIN_M15_RANGE=YES\nREACTION_RATIO=%.2f\nRANK_SCORE=%.2f", sym, current_close, target, reaction_ratio, score);
               
               if(score > best_score) {
                  best_score = score;
                  best_candidate_idx = i;
                  sweep_target = target;
               }
            }
         }
      }
      
      PrintFormat("[M5_TARGET_SUMMARY]\nSYMBOL=%s\nDIRECTION=%s\nTOTAL_RAW=%d\nQUALIFIED=%d\nREJECT_CONSUMED=%d\nREJECT_BROKEN=%d\nREJECT_OUTSIDE_RANGE=%d\nREJECT_NO_SWEEP=%d\nSELECTED_TARGET=%.5f\nSELECTED_STATUS=%s", 
                  sym, (trend_dir == 1 ? "BUY" : "SELL"), sum_raw, sum_qualified, sum_rej_consumed, sum_rej_broken, sum_rej_range, sum_rej_nosweep, sweep_target, (best_candidate_idx != -1 ? "SWEPT_AND_SELECTED" : "NONE"));
      PrintFormat("[M5_SWEEP_CANDIDATES][%s] direction=%d candidates=%d", sym, trend_dir, candidate_count);
      
      bool sweep_found = (best_candidate_idx != -1);
      TFDiag_RecordSweep(idx, trend_dir, sweep_found, current_time,
                         candidate_count, sum_raw, sum_qualified, sum_rej_consumed, sum_rej_broken, sum_rej_range, sum_rej_nosweep);
      
      if(best_candidate_idx != -1)
      {
         G_TF[idx].m5_sweep = true;
         G_TF[idx].m5_sweep_time = current_time;
         G_TF[idx].m5_sweep_price = sweep_target;
         G_TF[idx].m5_sweep_level = sweep_target;
         G_TF[idx].score_sweep = 10.0;
         SetTFState(idx, TF_STATE_M5_WAIT_DISPLACEMENT, "M5_SWEEP_CONFIRMED");
         G_TF[idx].status = "WAIT DISPLACEMENT";
         
         TFDiag_RecordFunnelStep(idx, trend_dir, TF_FUNNEL_SWEEP_FOUND);
         TFDiag_LogFunnel(idx, trend_dir, "M5_SWEEP", "PASS", StringFormat("target=%.5f, candidates=%d", sweep_target, candidate_count));
         
#ifdef _DEBUG
         if(!G_TF[idx].m15_pullback_valid)
         {
             PrintFormat("[TF_INVARIANT_VIOLATION][%s] M5_SWEEP_EXISTS_BUT_M15_CONTEXT_INVALID", sym);
         }
#endif
         
         double dist_val = 0;
         double structural_relevance = 0;
         if(atr > 0) {
            dist_val = MathAbs(sweep_target - (trend_dir == 1 ? G_TF[idx].m15_protected_low : G_TF[idx].m15_protected_high)) / atr;
            structural_relevance = (trend_dir == 1) ? (G_TF[idx].m15_impulse_high - sweep_target) / atr : (sweep_target - G_TF[idx].m15_impulse_low) / atr;
         }
         
         double selected_reaction = MeasureSwingReaction(m5_highs, m5_lows,
            best_candidate_idx, right, trend_dir, sweep_target, atr, m5_lookback);
         
         PrintFormat("[M5_SELECTED_SWEEP][%s] direction=%d swing_price=%.5f structural_significance=%.2f structural_depth=%.2f distance=%.2f freshness=%d ranking_score=%.2f", 
                     sym, trend_dir, sweep_target, selected_reaction, structural_relevance, dist_val, best_candidate_idx, best_score);
      }
      else
      {
         TFDiag_LogFunnel(idx, trend_dir, "M5_SWEEP", "REJECT", StringFormat("raw=%d, nosweep=%d, broken=%d, consumed=%d, range=%d", sum_raw, sum_rej_nosweep, sum_rej_broken, sum_rej_consumed, sum_rej_range));
         PrintFormat("[M5_NO_VALID_SWEEP][%s] direction=%d", sym, trend_dir);
         return; // Only return if no sweep found, otherwise fall through to evaluate Displacement on the same candle
      }
   }
   
   if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_DISPLACEMENT)
   {
      // Allow displacement evaluation on the same candle as sweep (>= instead of >)
      if(current_time >= G_TF[idx].m5_sweep_time)
      {
         if(DetectDisplacement(sym, m5, trend_dir))
         {
            double close[]; CopyClose(sym, m5, 1, 1, close);
            double high[], low[];
            CopyHigh(sym, m5, 1, 1, high);
            CopyLow(sym, m5, 1, 1, low);
            double atr = CalculateATR_Generic(sym, m5, InpReversal_ATR_Period, 1);
            
            double candle_range = (ArraySize(high) > 0 && ArraySize(low) > 0) ? (high[0] - low[0]) : 0.0;
            double range_atr = (atr > 0.0) ? (candle_range / atr) : 0.0;
            G_TF[idx].m5_displacement_range_atr = range_atr;
            
            bool disp_pass = (range_atr >= TF_MIN_DISPLACEMENT_ATR);
            TFDiag_RecordDisplacement(idx, trend_dir, disp_pass, range_atr, TF_MIN_DISPLACEMENT_ATR, current_time);
            
            Print("\n[TF_DISPLACEMENT_QUALITY]");
            PrintFormat("symbol=%s", sym);
            PrintFormat("direction=%s", (trend_dir == 1 ? "BUY" : "SELL"));
            PrintFormat("range_atr=%.2f", range_atr);
            PrintFormat("minimum_atr=%.2f", TF_MIN_DISPLACEMENT_ATR);
            PrintFormat("%s", disp_pass ? "PASS" : "REJECT");
            
            if(disp_pass)
            {
               G_TF[idx].m5_displacement = true;
               G_TF[idx].m5_displacement_time = current_time;
               G_TF[idx].m5_displacement_price = close[0];
               G_TF[idx].m5_displacement_range = candle_range;
               G_TF[idx].score_displacement = 10.0;
               SetTFState(idx, TF_STATE_M5_WAIT_MSS, "M5_DISPLACEMENT_CONFIRMED");
               G_TF[idx].status = "WAIT MSS";
               TFDiag_RecordFunnelStep(idx, trend_dir, TF_FUNNEL_DISPLACEMENT_FOUND);
               TFDiag_LogFunnel(idx, trend_dir, "M5_DISPLACEMENT", "PASS", StringFormat("range_atr=%.2f >= %.2f", range_atr, TF_MIN_DISPLACEMENT_ATR));
               PrintFormat("[TREND-FOLLOWING][%s] M5 Displacement Confirmed (dir=%d) on time=%s", sym, trend_dir, TimeToString(current_time));
            }
            else
            {
               // Weak displacement -> Reject setup
               TFDiag_LogFunnel(idx, trend_dir, "M5_DISPLACEMENT", "REJECT", StringFormat("WEAK: range_atr=%.2f < %.2f", range_atr, TF_MIN_DISPLACEMENT_ATR));
               LogTFReset(idx, "M5", "TF_P2_DISPLACEMENT_REJECT");
               ResetTFM5Evidence(idx);
               SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "TF_P2_DISPLACEMENT_REJECT");
               return;
            }
         }
         else
         {
            TFDiag_RecordDisplacement(idx, trend_dir, false, 0.0, TF_MIN_DISPLACEMENT_ATR, current_time, "NOT_DETECTED");
            return; // Wait for next candle if displacement not found yet
         }
      }
      else
      {
         return; // Safety guard for time invalidity
      }
   }
   
   if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_MSS)
   {
      // Allow MSS evaluation on the same candle as displacement (>= instead of >)
      if(current_time >= G_TF[idx].m5_displacement_time)
      {
         double breakLvl = 0.0;
         string mssReason = "";
         if(DetectStructureShift(idx, sym, m5, trend_dir, breakLvl, mssReason))
         {
            double close[]; CopyClose(sym, m5, 1, 1, close);
            double atr = CalculateATR_Generic(sym, m5, InpReversal_ATR_Period, 1);
            
            double break_dist = (trend_dir == 1) ? (close[0] - breakLvl) : (breakLvl - close[0]);
            double break_dist_atr = (atr > 0.0) ? (break_dist / atr) : 0.0;
            G_TF[idx].m5_mss_break_distance_atr = break_dist_atr;
            
            bool mss_pass = (break_dist_atr >= TF_MIN_MSS_BREAK_ATR);
            TFDiag_RecordMSS(idx, trend_dir, mss_pass, break_dist_atr, TF_MIN_MSS_BREAK_ATR, current_time);
            
            Print("\n[TF_MSS_QUALITY]");
            PrintFormat("symbol=%s", sym);
            PrintFormat("direction=%s", (trend_dir == 1 ? "BUY" : "SELL"));
            PrintFormat("break_distance_atr=%.2f", break_dist_atr);
            PrintFormat("minimum_break_atr=%.2f", TF_MIN_MSS_BREAK_ATR);
            PrintFormat("%s", mss_pass ? "PASS" : "REJECT");
            
            if(mss_pass)
            {
               G_TF[idx].m5_mss = true;
               G_TF[idx].m5_mss_time = current_time;
               G_TF[idx].m5_mss_break_level = breakLvl;
               G_TF[idx].score_mss = 10.0;
               SetTFState(idx, TF_STATE_ENTRY_READY, "M5_MSS_CONFIRMED"); // Forward to entry validation
               G_TF[idx].status = "MSS CONFIRMED";
               TFDiag_RecordFunnelStep(idx, trend_dir, TF_FUNNEL_MSS_FOUND);
               TFDiag_LogFunnel(idx, trend_dir, "M5_MSS", "PASS", StringFormat("break_dist_atr=%.2f >= %.2f", break_dist_atr, TF_MIN_MSS_BREAK_ATR));
               PrintFormat("[TREND-FOLLOWING][%s] M5 MSS Confirmed (dir=%d, level=%.5f) on time=%s", sym, trend_dir, breakLvl, TimeToString(current_time));
               
               // Record MSS Timing Distribution (bars from displacement to MSS confirmation)
               long bars_disp_to_mss = (current_time - G_TF[idx].m5_displacement_time) / period_sec;
               TFDiag_RecordMSSConfirmedBars(idx, trend_dir, (int)bars_disp_to_mss);
               
               // Start Momentum Window
               if(G_TF[idx].m5_momentum_start_time == 0)
                  G_TF[idx].m5_momentum_start_time = (G_TF[idx].m5_sweep_time > 0) ? G_TF[idx].m5_sweep_time : current_time;
               G_TF[idx].m5_momentum_bars_elapsed = 0;
               G_TF[idx].m5_momentum_last_closed_time = iTime(sym, PERIOD_M5, 1);
               G_TF[idx].m5_momentum_cci = false;
               G_TF[idx].m5_momentum_rf = false;
               G_TF[idx].m5_momentum_pc = false;
               G_TF[idx].score_momentum = 0.0;
            }
            else
            {
               TFDiag_LogFunnel(idx, trend_dir, "M5_MSS", "REJECT", StringFormat("WEAK: break_dist_atr=%.2f < %.2f", break_dist_atr, TF_MIN_MSS_BREAK_ATR));
               // Weak break -> MSS NOT CONFIRMED, continue waiting if within MSS wait window
               long period_sec = PeriodSeconds(m5);
               long bars_since_disp = (current_time - G_TF[idx].m5_displacement_time) / period_sec;
               long bars_since_sweep = (G_TF[idx].m5_sweep_time > 0) ? ((current_time - G_TF[idx].m5_sweep_time) / period_sec) : 0;
               if(bars_since_disp > TF_MSS_MAX_WAIT_BARS)
               {
                  TFDiag_RecordMSSTimeout(idx, trend_dir, (int)bars_since_disp, current_time);
                  TFDiag_LogFunnel(idx, trend_dir, "M5_MSS", "TIMEOUT",
                     StringFormat("bars_since_displacement=%d > TF_MSS_MAX_WAIT_BARS=%d (bars_since_sweep=%d, TF_MAX_EVENT_BARS=%d)",
                                  bars_since_disp, TF_MSS_MAX_WAIT_BARS, bars_since_sweep, TF_MAX_EVENT_BARS));
                  LogTFReset(idx, "M5", "TF_P2_MSS_REJECT");
                  ResetTFM5Evidence(idx);
                  SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "TF_P2_MSS_REJECT");
                  return;
               }
               G_TF[idx].status = "WAIT MSS (weak break)";
               return; // Wait for next candle if still within window
            }
         }
         else
         {
            TFDiag_RecordMSS(idx, trend_dir, false, 0.0, TF_MIN_MSS_BREAK_ATR, current_time, "NOT_DETECTED");
            return; // Wait for next candle if MSS not found yet
         }
      }
      else
      {
         return; // Safety guard for time invalidity
      }
   }
   
   if(G_TF[idx].setup_state == TF_STATE_ENTRY_READY)
   {
      // Step 1: Get the most recent CLOSED M5 candle timestamp
      datetime closed_m5_time = iTime(G_Pairs[idx].symbol, PERIOD_M5, 1);
      if(closed_m5_time <= 0)
         return;
      
      // Step 2: Check whether this is a NEW closed M5 candle
      // If same closed candle as last processed → do nothing (prevents multi-call counting)
      if(closed_m5_time == G_TF[idx].m5_momentum_last_closed_time)
         return; // Same candle already processed, skip entirely
      
      // Step 3: This IS a new closed M5 candle → update tracking and increment counter
      G_TF[idx].m5_momentum_last_closed_time = closed_m5_time;
      G_TF[idx].m5_momentum_bars_elapsed++;
      int bars_elapsed = G_TF[idx].m5_momentum_bars_elapsed;
      
      // Step 4: Check Momentum Window BEFORE evaluating momentum
      // bars_elapsed > TF_MOMENTUM_MAX_BARS means this bar is OUTSIDE the window
      if(bars_elapsed > TF_MOMENTUM_MAX_BARS)
      {
         // If momentum was NOT fully confirmed within the window → TIMEOUT
         if(G_TF[idx].score_momentum < 10.0)
         {
            TFDiag_RecordMomentumTimeout(idx, trend_dir, bars_elapsed, closed_m5_time);
            TFDiag_LogFunnel(idx, trend_dir, "MOMENTUM", "REJECT", StringFormat("TIMEOUT: bars=%d > %d, score=%.0f", bars_elapsed, TF_MOMENTUM_MAX_BARS, G_TF[idx].score_momentum));
            Print("\n[TF_MOMENTUM_TIMEOUT]");
            PrintFormat("SYMBOL=%s", sym);
            PrintFormat("DIRECTION=%s", (trend_dir == 1 ? "BUY" : "SELL"));
            PrintFormat("MSS_TIME=%s", TimeToString(G_TF[idx].m5_mss_time));
            PrintFormat("CLOSED_M5_TIME=%s", TimeToString(closed_m5_time));
            PrintFormat("BARS=%d/%d", bars_elapsed, TF_MOMENTUM_MAX_BARS);
            PrintFormat("MAX_BARS=%d", TF_MOMENTUM_MAX_BARS);
            PrintFormat("CCI_CONFIRMED=%s", G_TF[idx].m5_momentum_cci ? "true" : "false");
            PrintFormat("RF_CONFIRMED=%s", G_TF[idx].m5_momentum_rf ? "true" : "false");
            PrintFormat("PRICE_CONTINUATION=%s", G_TF[idx].m5_momentum_pc ? "true" : "false");
            PrintFormat("MOMENTUM_SCORE=%.0f", G_TF[idx].score_momentum);
            PrintFormat("ACTION=RESET_M5");
            
            ResetTFM5Evidence(idx);
            SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "MOMENTUM_TIMEOUT");
            return;
         }
         // Score was already 10, wait for Final Entry Gate
         return;
      }
      
      // Step 5: Within window (bars_elapsed 1..10) → evaluate Momentum confirmation on closed candle
      EvaluateTFMomentumConfirmation(idx, trend_dir, G_TF[idx].m5_momentum_cci, G_TF[idx].m5_momentum_rf, G_TF[idx].m5_momentum_pc);
      
      // Step 6: Update momentum score
      int pass_count = 0;
      if(G_TF[idx].m5_momentum_cci) pass_count++;
      if(G_TF[idx].m5_momentum_rf)  pass_count++;
      if(G_TF[idx].m5_momentum_pc)  pass_count++;
      
      if(G_TF[idx].m5_momentum_pc && pass_count >= 2) {
         G_TF[idx].score_momentum = 10.0;
      } else {
         if(pass_count > 0) G_TF[idx].score_momentum = 5.0;
         else G_TF[idx].score_momentum = 0.0;
      }
      
      // Step 7: Diagnostic log
      string mom_status = "WAIT";
      if(G_TF[idx].score_momentum == 10.0) mom_status = "CONFIRMED";
      else if(bars_elapsed == TF_MOMENTUM_MAX_BARS) mom_status = "LAST_CHANCE";
      
      int cci_status = 0, rf_status = 0;
      datetime cci_time = 0, rf_time = 0;
      CheckMomentumStatus(idx, cci_status, rf_status, cci_time, rf_time);
      
      TFDiag_RecordMomentumEval(idx, trend_dir, bars_elapsed,
                               G_TF[idx].m5_momentum_cci, G_TF[idx].m5_momentum_rf, G_TF[idx].m5_momentum_pc,
                               G_TF[idx].score_momentum, cci_status, rf_status, cci_time, rf_time, closed_m5_time);
      if(G_TF[idx].score_momentum == 10.0)
      {
         TFDiag_RecordFunnelStep(idx, trend_dir, TF_FUNNEL_MOMENTUM_PASS);
         TFDiag_LogFunnel(idx, trend_dir, "MOMENTUM", "PASS", "Confirmed (score=10)");
      }
      else
      {
         TFDiag_LogFunnel(idx, trend_dir, "MOMENTUM", "WAIT", StringFormat("Bar=%d/%d, Score=%.0f", bars_elapsed, TF_MOMENTUM_MAX_BARS, G_TF[idx].score_momentum));
      }
      
      string cci_state_str = (cci_status == 1) ? "BUY" : (cci_status == -1 ? "SELL" : "NONE");
      string rf_state_str  = (rf_status == 1)  ? "BUY" : (rf_status == -1  ? "SELL" : "NONE");
      
      string cci_valid_str = "FAIL";
      if(G_TF[idx].m5_momentum_cci)
         cci_valid_str = "PASS";
      else if(cci_status == trend_dir)
         cci_valid_str = "CCI_STALE";
      
      string rf_valid_str = "FAIL";
      if(G_TF[idx].m5_momentum_rf)
         rf_valid_str = "PASS";
      else if(rf_status == trend_dir)
         rf_valid_str = "RF_STALE";
      
      Print("\n[TF_MOMENTUM_DIAGNOSTIC]");
      PrintFormat("SYMBOL=%s", sym);
      PrintFormat("DIRECTION=%s", (trend_dir == 1 ? "BUY" : "SELL"));
      PrintFormat("MSS_TIME=%s", TimeToString(G_TF[idx].m5_mss_time));
      PrintFormat("CLOSED_M5_TIME=%s", TimeToString(closed_m5_time));
      PrintFormat("BAR=%d/%d", bars_elapsed, TF_MOMENTUM_MAX_BARS);
      PrintFormat("CCI_STATE=%s", cci_state_str);
      PrintFormat("CCI_SIGNAL_TIME=%s", TimeToString(cci_time));
      PrintFormat("CCI_VALID=%s", cci_valid_str);
      PrintFormat("RF_STATE=%s", rf_state_str);
      PrintFormat("RF_SIGNAL_TIME=%s", TimeToString(rf_time));
      PrintFormat("RF_VALID=%s", rf_valid_str);
      PrintFormat("PRICE_CONTINUATION=%s", G_TF[idx].m5_momentum_pc ? "PASS" : "FAIL");
      // Find protected structure intactness for diagnostic
      bool prot_intact = false;
      if(trend_dir == 1) {
         double prot = (G_TF[idx].m15_protected_low > 0.0) ? G_TF[idx].m15_protected_low : G_TF[idx].h1_protected_structure;
         if(prot > 0.0 && iClose(sym, PERIOD_M5, 1) >= prot) prot_intact = true;
      } else {
         double prot = (G_TF[idx].m15_protected_high > 0.0) ? G_TF[idx].m15_protected_high : G_TF[idx].h1_protected_structure;
         if(prot > 0.0 && iClose(sym, PERIOD_M5, 1) <= prot) prot_intact = true;
      }
      PrintFormat("PROTECTED_STRUCTURE=%s", prot_intact ? "PASS" : "FAIL");
      PrintFormat("MOMENTUM_SCORE=%.0f", G_TF[idx].score_momentum);
      PrintFormat("STATUS=%s", mom_status);
      
      // Phase 2F: Momentum Quality diagnostic log
      string mom_q_status = "WAIT";
      if(G_TF[idx].score_momentum == 10.0) mom_q_status = "PASS";
      else if(bars_elapsed >= TF_MOMENTUM_MAX_BARS) mom_q_status = "REJECT";
      
      Print("\n[TF_MOMENTUM_QUALITY]");
      PrintFormat("symbol=%s", sym);
      PrintFormat("bars_elapsed=%d", bars_elapsed);
      PrintFormat("CCI=%s", G_TF[idx].m5_momentum_cci ? "true" : "false");
      PrintFormat("RF=%s", G_TF[idx].m5_momentum_rf ? "true" : "false");
      PrintFormat("PC=%s", G_TF[idx].m5_momentum_pc ? "true" : "false");
      PrintFormat("score=%.0f", G_TF[idx].score_momentum);
      PrintFormat("%s", mom_q_status);
      
      if(G_TF[idx].score_momentum == 10.0)
      {
         double current_total = CalculateTFScore(idx);
         Print("\n[TF_SCORE_DIAGNOSTIC]");
         PrintFormat("SYMBOL=%s", sym);
         PrintFormat("H1=%.0f", G_TF[idx].score_h1_trend);
         PrintFormat("M15=%.0f", G_TF[idx].score_m15_pullback);
         PrintFormat("SWEEP=%.0f", G_TF[idx].score_sweep);
         PrintFormat("DISPLACEMENT=%.0f", G_TF[idx].score_displacement);
         PrintFormat("MSS=%.0f", G_TF[idx].score_mss);
         PrintFormat("COHERENCE=%.0f", G_TF[idx].score_event_coherence);
         PrintFormat("MOMENTUM=%.0f", G_TF[idx].score_momentum);
         PrintFormat("ENTRY_DISTANCE=%.0f", G_TF[idx].score_entry_distance);
         if(G_TF[idx].h1_trend_quality < 20.0) PrintFormat("DXY=%.0f", G_TF[idx].score_dxy);
         PrintFormat("TOTAL=%.0f", current_total);
         
         if(current_total >= InpTF_RequiredScore) {
             Print("[SCORE_REQ_REACHED]");
         }
      }

      
      return;
   }
}

void EvaluateTFMomentumConfirmation(int idx, int trend_dir, bool &cci_confirmed, bool &rf_confirmed, bool &pc_confirmed)
{
   string sym = G_Pairs[idx].symbol;
   int cci_status = 0, rf_status = 0;
   datetime cci_time = 0, rf_time = 0;
   CheckMomentumStatus(idx, cci_status, rf_status, cci_time, rf_time);
   
   datetime closed_m5_time = iTime(sym, PERIOD_M5, 1);
   long period_sec = PeriodSeconds(PERIOD_M5);
   
   // Determine setup lifecycle anchor for freshness
   datetime anchor_time = G_TF[idx].m5_momentum_start_time;
   if(anchor_time <= 0)
   {
      if(G_TF[idx].m15_pullback_start_time > 0) anchor_time = G_TF[idx].m15_pullback_start_time;
      else if(G_TF[idx].m5_sweep_time > 0)      anchor_time = G_TF[idx].m5_sweep_time;
      else                                      anchor_time = G_TF[idx].m5_mss_time;
   }
   
   // 1. Evaluate CCI Momentum confirmation & freshness
   bool cci_fresh = false;
   if(cci_status == trend_dir && cci_time > 0)
   {
      long bars_since_cci = (closed_m5_time - cci_time) / period_sec;
      // Must be within current setup lifecycle (>= anchor_time), closed candle (<= closed_m5_time), and fresh
      if(cci_time >= anchor_time && cci_time <= closed_m5_time && bars_since_cci >= 0 && bars_since_cci <= TF_MOMENTUM_SIGNAL_MAX_AGE_BARS)
         cci_fresh = true;
   }
   
   if(cci_fresh)
   {
      cci_confirmed = true;
      if(G_TF[idx].m5_momentum_cci_time == 0)
         G_TF[idx].m5_momentum_cci_time = closed_m5_time;
   }
   else if(cci_status == -trend_dir)
   {
      // Adverse momentum invalidates previous confirmation
      cci_confirmed = false;
      G_TF[idx].m5_momentum_cci_time = 0;
   }
   
   // 2. Evaluate Range Filter confirmation & freshness
   bool rf_fresh = false;
   if(rf_status == trend_dir && rf_time > 0)
   {
      long bars_since_rf = (closed_m5_time - rf_time) / period_sec;
      // Must be within current setup lifecycle (>= anchor_time), closed candle (<= closed_m5_time), and fresh
      if(rf_time >= anchor_time && rf_time <= closed_m5_time && bars_since_rf >= 0 && bars_since_rf <= TF_MOMENTUM_SIGNAL_MAX_AGE_BARS)
         rf_fresh = true;
   }
   
   if(rf_fresh)
   {
      rf_confirmed = true;
      if(G_TF[idx].m5_momentum_rf_time == 0)
         G_TF[idx].m5_momentum_rf_time = closed_m5_time;
   }
   else if(rf_status == -trend_dir)
   {
      // Adverse momentum invalidates previous confirmation
      rf_confirmed = false;
      G_TF[idx].m5_momentum_rf_time = 0;
   }
   
   // 3. Evaluate Price Continuation (closed candle validation)
   double close1 = iClose(sym, PERIOD_M5, 1);
   double close2 = iClose(sym, PERIOD_M5, 2);
   
   bool protected_intact = false;
   if(trend_dir == 1) {
      double prot_low = (G_TF[idx].m15_protected_low > 0.0) ? G_TF[idx].m15_protected_low : G_TF[idx].h1_protected_structure;
      if(prot_low > 0.0 && close1 >= prot_low) protected_intact = true;
      
      if(close1 > close2 && close1 > G_TF[idx].m5_mss_break_level && protected_intact)
      {
         pc_confirmed = true;
         if(G_TF[idx].m5_momentum_pc_time == 0)
            G_TF[idx].m5_momentum_pc_time = closed_m5_time;
      }
      else if(!protected_intact)
      {
         pc_confirmed = false;
         G_TF[idx].m5_momentum_pc_time = 0;
      }
   }
   else if(trend_dir == -1) {
      double prot_high = (G_TF[idx].m15_protected_high > 0.0) ? G_TF[idx].m15_protected_high : G_TF[idx].h1_protected_structure;
      if(prot_high > 0.0 && close1 <= prot_high) protected_intact = true;
      
      if(close1 < close2 && close1 < G_TF[idx].m5_mss_break_level && protected_intact)
      {
         pc_confirmed = true;
         if(G_TF[idx].m5_momentum_pc_time == 0)
            G_TF[idx].m5_momentum_pc_time = closed_m5_time;
      }
      else if(!protected_intact)
      {
         pc_confirmed = false;
         G_TF[idx].m5_momentum_pc_time = 0;
      }
   }
}

// ==================================================================
// EVENT COHERENCE CHECK
// ==================================================================
// Stage A: Sweep → Displacement must be within TF_MAX_EVENT_BARS (5 bars)
// Stage B: Displacement → MSS must be within TF_MSS_MAX_WAIT_BARS (15 bars)

bool CheckTFEventCoherence(int idx)
{
   datetime m5_time = iTime(G_Pairs[idx].symbol, PERIOD_M5, 1);
   if(!G_TF[idx].m5_sweep || !G_TF[idx].m5_displacement || !G_TF[idx].m5_mss)
   {
      TFDiag_RecordCoherence(idx, G_TF[idx].h1_trend_direction, false, 0, TF_MAX_EVENT_BARS, m5_time);
      return false;
   }
   
   if(G_TF[idx].m5_sweep_time == 0 || G_TF[idx].m5_displacement_time == 0 || G_TF[idx].m5_mss_time == 0)
   {
      TFDiag_RecordCoherence(idx, G_TF[idx].h1_trend_direction, false, 0, TF_MAX_EVENT_BARS, m5_time);
      return false;
   }
      
   // Events can happen on the same candle (==), but must not happen backward in time (>)
   if(G_TF[idx].m5_sweep_time > G_TF[idx].m5_displacement_time ||
      G_TF[idx].m5_displacement_time > G_TF[idx].m5_mss_time ||
      G_TF[idx].m15_protected_confirmed_time > G_TF[idx].m5_sweep_time)
   {
      TFDiag_RecordCoherence(idx, G_TF[idx].h1_trend_direction, false, 0, TF_MAX_EVENT_BARS, m5_time);
      return false;
   }
   
   long period_sec = PeriodSeconds(PERIOD_M5);
   
   // Stage A Freshness: Sweep -> Displacement must complete within TF_MAX_EVENT_BARS
   long sweep_to_disp_bars = (G_TF[idx].m5_displacement_time - G_TF[idx].m5_sweep_time) / period_sec;
   if(sweep_to_disp_bars > TF_MAX_EVENT_BARS)
   {
      TFDiag_RecordCoherence(idx, G_TF[idx].h1_trend_direction, false, (int)sweep_to_disp_bars, TF_MAX_EVENT_BARS, m5_time);
      return false;
   }
   
   // Stage B Freshness: Displacement -> MSS must complete within TF_MSS_MAX_WAIT_BARS
   long disp_to_mss_bars = (G_TF[idx].m5_mss_time - G_TF[idx].m5_displacement_time) / period_sec;
   if(disp_to_mss_bars > TF_MSS_MAX_WAIT_BARS)
   {
      TFDiag_RecordCoherence(idx, G_TF[idx].h1_trend_direction, false, (int)disp_to_mss_bars, TF_MSS_MAX_WAIT_BARS, m5_time);
      return false;
   }
   
   long total_sequence_bars = (G_TF[idx].m5_mss_time - G_TF[idx].m5_sweep_time) / period_sec;
   G_TF[idx].score_event_coherence = 10.0;
   TFDiag_RecordCoherence(idx, G_TF[idx].h1_trend_direction, true, (int)total_sequence_bars, TF_MAX_EVENT_BARS + TF_MSS_MAX_WAIT_BARS, m5_time);
   return true;
}

// ==================================================================
// ENTRY DISTANCE CHECK
// ==================================================================
// Don't chase price if it has moved too far from trigger

bool ValidateTFEntryDistance(int idx, int direction, double &distance_atr, double &max_distance_atr)
{
   distance_atr = 0.0;
   max_distance_atr = TF_MAX_ENTRY_DISTANCE_ATR;
   
   if(G_TF[idx].m5_mss_break_level <= 0.0) return false; // MUST NOT BE SKIPPED
   
   string sym = G_Pairs[idx].symbol;
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false; // Fail-closed
   
   double close[];
   if(CopyClose(sym, PERIOD_M5, 1, 1, close) < 1) return false; // Fail-closed
   
   double distance = 0.0;
   if(direction == 1)
   {
      distance = close[0] - G_TF[idx].m5_mss_break_level;
      if(close[0] < G_TF[idx].m5_mss_break_level) return false;
   }
   else
   {
      distance = G_TF[idx].m5_mss_break_level - close[0];
      if(close[0] > G_TF[idx].m5_mss_break_level) return false;
   }
   
   distance_atr = distance / atr;
   if(distance_atr > max_distance_atr) return false;
   
   return true;
}

// ==================================================================
// PHASE 2E — ENTRY LOCATION QUALITY (MSS EXTENSION)
// ==================================================================

bool ValidateTFEntryLocationQuality(int idx, int direction, double &dist_mss_atr, double &dist_prot_atr, double &max_ext_atr)
{
   dist_mss_atr = 0.0;
   dist_prot_atr = 0.0;
   max_ext_atr = TF_MAX_MSS_ENTRY_EXTENSION_ATR;
   
   if(G_TF[idx].m5_mss_break_level <= 0.0) return false;
   
   string sym = G_Pairs[idx].symbol;
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double close1 = iClose(sym, PERIOD_M5, 1);
   if(close1 <= 0) return false;
   
   double dist_mss = MathAbs(close1 - G_TF[idx].m5_mss_break_level);
   dist_mss_atr = dist_mss / atr;
   G_TF[idx].m5_entry_extension_mss_atr = dist_mss_atr;
   
   double prot = 0.0;
   if(direction == 1)
      prot = (G_TF[idx].m15_protected_low > 0.0) ? G_TF[idx].m15_protected_low : G_TF[idx].h1_protected_structure;
   else if(direction == -1)
      prot = (G_TF[idx].m15_protected_high > 0.0) ? G_TF[idx].m15_protected_high : G_TF[idx].h1_protected_structure;
      
   if(prot > 0.0)
   {
      double dist_prot = MathAbs(close1 - prot);
      dist_prot_atr = dist_prot / atr;
      G_TF[idx].m5_entry_extension_prot_atr = dist_prot_atr;
   }
   
   bool pass = true;
   if(dist_mss_atr > TF_MAX_MSS_ENTRY_EXTENSION_ATR)
      pass = false;
      
   Print("\n[TF_ENTRY_LOCATION]");
   PrintFormat("symbol=%s", sym);
   PrintFormat("direction=%s", (direction == 1 ? "BUY" : (direction == -1 ? "SELL" : "NONE")));
   PrintFormat("distance_from_mss_atr=%.2f", dist_mss_atr);
   PrintFormat("distance_from_protected_atr=%.2f", dist_prot_atr);
   PrintFormat("max_extension_atr=%.2f", max_ext_atr);
   PrintFormat("%s", pass ? "PASS" : "REJECT");
   
   return pass;
}

// ==================================================================
// H1 TREND INVALIDATION CHECK
// ==================================================================

bool CheckH1TrendInvalidation(int idx)
{
   if(G_TF[idx].h1_protected_structure <= 0.0) return false;
   
   string sym = G_Pairs[idx].symbol;
   double close[];
   if(CopyClose(sym, G_Pairs[idx].htf, 1, 1, close) < 1) return false;
   
   int dir = G_TF[idx].h1_trend_direction;
   
   if(dir == 1 && close[0] < G_TF[idx].h1_protected_structure)
      return true; // BUY trend broken
   
   if(dir == -1 && close[0] > G_TF[idx].h1_protected_structure)
      return true; // SELL trend broken
   
   return false;
}

// ==================================================================
// M15 PULLBACK INVALIDATION CHECK
// ==================================================================

bool CheckM15PullbackInvalidation(int idx)
{
   int dir = G_TF[idx].h1_trend_direction;
   string sym = G_Pairs[idx].symbol;
   
   double close[];
   if(CopyClose(sym, PERIOD_M15, 1, 1, close) < 1) return false;
   
   if(dir == 1 && G_TF[idx].m15_protected_low > 0.0)
   {
      // BUY: if M15 breaks protected low → pullback became reversal
      if(close[0] < G_TF[idx].m15_protected_low)
         return true;
   }
   
   if(dir == -1 && G_TF[idx].m15_protected_high > 0.0)
   {
      // SELL: if M15 breaks protected high → pullback became reversal
      if(close[0] > G_TF[idx].m15_protected_high)
         return true;
   }
   
   return false;
}

// ==================================================================
// TF SCORE CALCULATION
// ==================================================================

double CalculateTFScore(int idx)
{
   double d_atr=0, max_d=0;
   bool dist_valid = ValidateTFEntryDistance(idx, G_TF[idx].h1_trend_direction, d_atr, max_d);
   
   // H1 BASE (15/20) uses Entry Distance = 5, DXY = 10; H1 STRONG (20/20) uses Entry Distance = 10
   if(G_TF[idx].h1_trend_quality >= TF_H1_QUALITY_STRONG)
   {
      G_TF[idx].score_entry_distance = dist_valid ? 10.0 : 0.0;
      G_TF[idx].score_dxy = 0.0;
   }
   else
   {
      G_TF[idx].score_entry_distance = dist_valid ? 5.0 : 0.0;
      string dxy_reason = "";
      bool dxy_pass = CheckDXYTrendFollowingConfirmation(idx, G_TF[idx].h1_trend_direction, dxy_reason);
      G_TF[idx].score_dxy = dxy_pass ? 10.0 : 0.0;
   }
   
   if(CheckTFEventCoherence(idx)) {
      G_TF[idx].score_event_coherence = 10.0;
   } else {
      G_TF[idx].score_event_coherence = 0.0;
   }

   double raw_score = G_TF[idx].score_h1_trend
                    + G_TF[idx].score_m15_pullback
                    + G_TF[idx].score_sweep
                    + G_TF[idx].score_displacement
                    + G_TF[idx].score_mss
                    + G_TF[idx].score_event_coherence
                    + G_TF[idx].score_momentum
                    + G_TF[idx].score_entry_distance
                    + G_TF[idx].score_dxy;
   
   G_TF[idx].total_score = MathMin(100.0, raw_score);
   return G_TF[idx].total_score;
}

// ==================================================================
// TF PHASE 2 ENTRY QUALITY GATE (CENTRALIZED VALIDATION)
// ==================================================================
// Validates all 12 hard conditions from Phase 2 Section 8:
// 1. H1 quality >= 15
// 2. M15 quality valid
// 3. M15 protected structure intact
// 4. Sweep valid
// 5. Displacement valid
// 6. MSS valid
// 7. Event coherence <= 5 bars
// 8. Momentum score = 10
// 9. Entry distance valid
// 10. Entry extension valid
// 11. DXY confirmation valid
// 12. Total score >= InpTF_RequiredScore

bool ValidateTFPhase2EntryQuality(int idx, int direction, string &rejectReason)
{
   bool pass = true;
   string first_reject = "";
   string sym = G_Pairs[idx].symbol;
   
   // 1. H1 Quality >= 15 & Direction
   if(G_TF[idx].h1_trend_direction != direction || G_TF[idx].h1_trend_quality < TF_H1_QUALITY_BASE)
   {
      if(first_reject == "") first_reject = "TF_P2_H1_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] H1 (direction=%d, quality=%.0f)", G_TF[idx].h1_trend_direction, G_TF[idx].h1_trend_quality);
      pass = false;
   }
   
   // 2. M15 Pullback Quality Valid
   if(!G_TF[idx].m15_pullback_valid || G_TF[idx].m15_pullback_quality < 20.0)
   {
      if(first_reject == "") first_reject = "TF_P2_M15_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] M15 (valid=%s, quality=%.0f)", G_TF[idx].m15_pullback_valid ? "true" : "false", G_TF[idx].m15_pullback_quality);
      pass = false;
   }
   
   // 3. M15 Protected Structure Intact (closed M5 candle must not invalidate protected level)
   double close1 = iClose(sym, PERIOD_M5, 1);
   bool prot_ok = true;
   if(direction == 1)
   {
      double prot = (G_TF[idx].m15_protected_low > 0.0) ? G_TF[idx].m15_protected_low : G_TF[idx].h1_protected_structure;
      if(prot > 0.0 && close1 < prot) prot_ok = false;
   }
   else if(direction == -1)
   {
      double prot = (G_TF[idx].m15_protected_high > 0.0) ? G_TF[idx].m15_protected_high : G_TF[idx].h1_protected_structure;
      if(prot > 0.0 && close1 > prot) prot_ok = false;
   }
   if(!prot_ok)
   {
      if(first_reject == "") first_reject = "TF_P2_M15_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] Protected Structure (close=%.5f broken)", close1);
      pass = false;
   }
   
   // 4. Sweep Valid
   if(!G_TF[idx].m5_sweep)
   {
      if(first_reject == "") first_reject = "TF_P2_SWEEP_REJECT";
      Print("[TF_PHASE2_REJECT] Sweep");
      pass = false;
   }
   
   // 5. Displacement Valid
   if(!G_TF[idx].m5_displacement || G_TF[idx].m5_displacement_range_atr < TF_MIN_DISPLACEMENT_ATR)
   {
      if(first_reject == "") first_reject = "TF_P2_DISPLACEMENT_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] Displacement (range_atr=%.2f < min=%.2f)", G_TF[idx].m5_displacement_range_atr, TF_MIN_DISPLACEMENT_ATR);
      pass = false;
   }
   
   // 6. MSS Valid
   if(!G_TF[idx].m5_mss || G_TF[idx].m5_mss_break_level <= 0.0 || G_TF[idx].m5_mss_break_distance_atr < TF_MIN_MSS_BREAK_ATR)
   {
      if(first_reject == "") first_reject = "TF_P2_MSS_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] MSS (level=%.5f, break_atr=%.2f < min=%.2f)", G_TF[idx].m5_mss_break_level, G_TF[idx].m5_mss_break_distance_atr, TF_MIN_MSS_BREAK_ATR);
      pass = false;
   }
   
   // 7. Event Coherence (Sweep->Disp <= TF_MAX_EVENT_BARS, Disp->MSS <= TF_MSS_MAX_WAIT_BARS)
   bool event_coherent = CheckTFEventCoherence(idx);
   if(!event_coherent)
   {
      if(first_reject == "") first_reject = "EVENT_NOT_COHERENT";
      Print("[TF_PHASE2_REJECT] Event Coherence");
      pass = false;
   }
   
   // 8. Momentum Score = 10
   if(G_TF[idx].score_momentum < 10.0)
   {
      if(first_reject == "") first_reject = "TF_P2_MOMENTUM_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] Momentum (score=%.0f < 10)", G_TF[idx].score_momentum);
      pass = false;
   }
   
   // 9. Entry Distance Valid (<= 2.0 ATR from MSS level)
   double d_atr = 0, max_d = 0;
   bool dist_valid = ValidateTFEntryDistance(idx, direction, d_atr, max_d);
   if(!dist_valid)
   {
      if(first_reject == "") first_reject = "TF_P2_ENTRY_LOCATION_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] Entry Distance (dist_atr=%.2f > max=%.2f)", d_atr, max_d);
      pass = false;
   }
   
   // 10. Entry Extension Valid (<= 1.50 ATR from MSS level)
   double ext_mss = 0, ext_prot = 0, max_ext = 0;
   bool ext_valid = ValidateTFEntryLocationQuality(idx, direction, ext_mss, ext_prot, max_ext);
   if(!ext_valid)
   {
      if(first_reject == "") first_reject = "TF_P2_ENTRY_LOCATION_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] Entry Extension (mss_ext_atr=%.2f > max=%.2f)", ext_mss, max_ext);
      pass = false;
   }
   
   // 11. DXY Confirmation Valid
   // H1 STRONG -> DXY NOT REQUIRED (do not reject)
   // H1 BASE   -> DXY REQUIRED (hard gate)
   bool h1_strong = (G_TF[idx].h1_trend_quality >= TF_H1_QUALITY_STRONG);
   bool h1_base   = (G_TF[idx].h1_trend_quality >= TF_H1_QUALITY_BASE && G_TF[idx].h1_trend_quality < TF_H1_QUALITY_STRONG);
   bool dxy_pass  = true;
   
   if(h1_strong)
   {
      PrintFormat("\n[TF_DXY_GATE] H1 STRONG -> DXY not required (symbol=%s)", sym);
      if(G_Pairs[idx].isUSDPair)
      {
         string dxy_info_reason = "";
         bool dxy_info_pass = CheckDXYTrendFollowingConfirmation(idx, direction, dxy_info_reason);
         PrintFormat("[TF_DXY_INFO] H1 STRONG -> DXY result ignored (pass=%s, reason=%s)",
                     dxy_info_pass ? "true" : "false", dxy_info_reason);
      }
   }
   else if(h1_base)
   {
      PrintFormat("\n[TF_DXY_GATE] H1 BASE -> DXY required (symbol=%s)", sym);
      string dxy_reason = "";
      dxy_pass = CheckDXYTrendFollowingConfirmation(idx, direction, dxy_reason);
      if(!dxy_pass)
      {
         if(first_reject == "") first_reject = (StringFind(dxy_reason, "DXY_") == 0) ? dxy_reason : "TF_P2_DXY_REJECT";
         PrintFormat("[TF_PHASE2_REJECT] DXY (H1 BASE -> DXY REQUIRED, reason=%s)", dxy_reason);
         pass = false;
      }
   }
   
   // 12. Total Score >= InpTF_RequiredScore
   double score = CalculateTFScore(idx);
   if(score < InpTF_RequiredScore)
   {
      if(first_reject == "") first_reject = "TF_P2_SCORE_REJECT";
      PrintFormat("[TF_PHASE2_REJECT] Final Score (score=%.0f < req=%.0f)", score, InpTF_RequiredScore);
      pass = false;
   }
   
   // Record Phase 2 Funnel & Diagnostic Counters
   bool rej_h1    = (G_TF[idx].h1_trend_direction != direction || G_TF[idx].h1_trend_quality < TF_H1_QUALITY_BASE);
   bool rej_m15   = (!G_TF[idx].m15_pullback_valid || G_TF[idx].m15_pullback_quality < 20.0);
   bool rej_prot  = (!prot_ok);
   bool rej_sweep = (!G_TF[idx].m5_sweep);
   bool rej_disp  = (!G_TF[idx].m5_displacement || G_TF[idx].m5_displacement_range_atr < TF_MIN_DISPLACEMENT_ATR);
   bool rej_mss   = (!G_TF[idx].m5_mss || G_TF[idx].m5_mss_break_level <= 0.0 || G_TF[idx].m5_mss_break_distance_atr < TF_MIN_MSS_BREAK_ATR);
   bool rej_coh   = (!event_coherent);
   bool rej_mom   = (G_TF[idx].score_momentum < 10.0);
   bool rej_dist  = (!dist_valid);
   bool rej_ext   = (!ext_valid);
   bool rej_dxy   = (h1_base && !dxy_pass);
   bool rej_score = (score < InpTF_RequiredScore);
   
   datetime p2_m5_time = iTime(sym, PERIOD_M5, 1);
   TFDiag_RecordPhase2(idx, direction, pass, first_reject,
                       rej_h1, rej_m15, rej_prot, rej_sweep,
                       rej_disp, rej_mss, rej_coh, rej_mom,
                       rej_dist, rej_ext, rej_dxy, rej_score,
                       p2_m5_time);
                       
   if(pass)
   {
      TFDiag_RecordFunnelStep(idx, direction, TF_FUNNEL_PHASE2_PASS);
      TFDiag_LogFunnel(idx, direction, "PHASE_2", "PASS");
   }
   else
   {
      TFDiag_LogFunnel(idx, direction, "PHASE_2", "REJECT", first_reject);
   }
   
   // Gather diagnostic values
   string dir_str = (direction == 1) ? "BUY" : ((direction == -1) ? "SELL" : "NONE");
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   
   int cci_status = 0, rf_status = 0;
   datetime cci_time = 0, rf_time = 0;
   CheckMomentumStatus(idx, cci_status, rf_status, cci_time, rf_time);
   string cci_dir = (cci_status == 1) ? "BUY" : (cci_status == -1 ? "SELL" : "NONE");
   string rf_dir = (rf_status == 1) ? "BUY" : (rf_status == -1 ? "SELL" : "NONE");
   
   // --- PRINT DIAGNOSTIC BLOCK ---
   Print("\n[TF_SETUP_DIAGNOSTIC]");
   Print("");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("DIRECTION=%s", dir_str);
   Print("");
   Print("H1:");
   PrintFormat("  VALID=%s", (G_TF[idx].h1_trend_direction == direction) ? "true" : "false");
   PrintFormat("  QUALITY=%.0f", G_TF[idx].h1_trend_quality);
   PrintFormat("  CLASSIFICATION=%s", G_TF[idx].h1_classification);
   PrintFormat("  SCORE=%.0f", G_TF[idx].score_h1_trend);
   Print("");
   Print("M15:");
   PrintFormat("  VALID=%s", G_TF[idx].m15_pullback_valid ? "true" : "false");
   PrintFormat("  QUALITY=%.0f", G_TF[idx].m15_pullback_quality);
   PrintFormat("  SCORE=%.0f", G_TF[idx].score_m15_pullback);
   Print("");
   Print("M5:");
   PrintFormat("  SWEEP=%s", G_TF[idx].m5_sweep ? "true" : "false");
   PrintFormat("  DISPLACEMENT=%s", G_TF[idx].m5_displacement ? "true" : "false");
   PrintFormat("  DISPLACEMENT_ATR=%.2f", G_TF[idx].m5_displacement_range_atr);
   PrintFormat("  MSS=%s", G_TF[idx].m5_mss ? "true" : "false");
   PrintFormat("  MSS_BREAK_ATR=%.2f", G_TF[idx].m5_mss_break_distance_atr);
   PrintFormat("  EVENT=%s", event_coherent ? "true" : "false");
   Print("");
   int bars_elapsed = G_TF[idx].m5_momentum_bars_elapsed;
   
   string mom_diag_status = "WAIT";
   if(G_TF[idx].score_momentum == 10.0) mom_diag_status = "CONFIRMED";
   else if(bars_elapsed == TF_MOMENTUM_MAX_BARS) mom_diag_status = "LAST_CHANCE";
   
   Print("\n[TF_MOMENTUM]");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("DIRECTION=%s", dir_str);
   PrintFormat("MSS_TIME=%s", TimeToString(G_TF[idx].m5_mss_time));
   PrintFormat("CLOSED_M5_TIME=%s", TimeToString(iTime(sym, PERIOD_M5, 1)));
   PrintFormat("BARS_SINCE_MSS=%d", bars_elapsed);
   PrintFormat("MAX_BARS=%d", TF_MOMENTUM_MAX_BARS);
   Print("");
   PrintFormat("CCI_STATE=%s", cci_dir);
   PrintFormat("CCI_CONFIRMED=%s", G_TF[idx].m5_momentum_cci ? "true" : "false");
   if(G_TF[idx].m5_momentum_cci_time > 0) PrintFormat("CCI_CONFIRMED_TIME=%s", TimeToString(G_TF[idx].m5_momentum_cci_time));
   Print("");
   PrintFormat("RF_STATE=%s", rf_dir);
   PrintFormat("RF_CONFIRMED=%s", G_TF[idx].m5_momentum_rf ? "true" : "false");
   if(G_TF[idx].m5_momentum_rf_time > 0) PrintFormat("RF_CONFIRMED_TIME=%s", TimeToString(G_TF[idx].m5_momentum_rf_time));
   Print("");
   PrintFormat("PC_CONFIRMED=%s", G_TF[idx].m5_momentum_pc ? "true" : "false");
   if(G_TF[idx].m5_momentum_pc_time > 0) PrintFormat("PC_CONFIRMED_TIME=%s", TimeToString(G_TF[idx].m5_momentum_pc_time));
   Print("");
   
   int mom_pass_count = 0;
   if(G_TF[idx].m5_momentum_cci) mom_pass_count++;
   if(G_TF[idx].m5_momentum_rf)  mom_pass_count++;
   if(G_TF[idx].m5_momentum_pc)  mom_pass_count++;
   PrintFormat("MOMENTUM_PASS_COUNT=%d", mom_pass_count);
   PrintFormat("MOMENTUM_REQUIRED=2");
   PrintFormat("MOMENTUM_PC_REQUIRED=true");
   string mom_reason = "";
   if(G_TF[idx].m5_momentum_pc && mom_pass_count >= 3) mom_reason = "3_OF_3";
   else if(G_TF[idx].m5_momentum_pc && mom_pass_count >= 2) mom_reason = "2_OF_3_WITH_PRICE_CONTINUATION";
   else if(!G_TF[idx].m5_momentum_pc && G_TF[idx].m5_momentum_cci && G_TF[idx].m5_momentum_rf) mom_reason = "PRICE_CONTINUATION_REQUIRED";
   else if(mom_pass_count == 1) mom_reason = "INSUFFICIENT_CONFIRMATIONS";
   else mom_reason = "NO_CONFIRMATIONS";
   PrintFormat("MOMENTUM_REASON=%s", mom_reason);
   PrintFormat("MOMENTUM_SCORE=%.0f", G_TF[idx].score_momentum);
   PrintFormat("STATUS=%s", mom_diag_status);
   Print("");
   Print("ENTRY_DISTANCE:");
   PrintFormat("  MSS_LEVEL=%.5f", G_TF[idx].m5_mss_break_level);
   PrintFormat("  CLOSE=%.5f", close1);
   PrintFormat("  ATR=%.5f", atr);
   PrintFormat("  DISTANCE_ATR=%.2f", d_atr);
   PrintFormat("  MAX_DISTANCE_ATR=%.2f", max_d);
   PrintFormat("  VALID=%s", dist_valid ? "true" : "false");
   PrintFormat("  SCORE=%.0f", G_TF[idx].score_entry_distance);
   Print("");
   Print("DXY:");
   PrintFormat("  GATE=%s", h1_strong ? "NOT REQUIRED (H1 STRONG)" : "REQUIRED (H1 BASE)");
   PrintFormat("  SCORE=%.0f", G_TF[idx].score_dxy);
   Print("");

   PrintFormat("TOTAL_SCORE=%.0f", score);
   Print("");
   PrintFormat("FINAL_GATE=%s", pass ? "PASS" : "FAIL");
   if(!pass) PrintFormat("REJECT_REASON=%s", first_reject);
   
   rejectReason = first_reject;
   return pass;
}

bool ValidateTFPhase2EntryQuality(int idx)
{
   string rejectReason = "";
   return ValidateTFPhase2EntryQuality(idx, G_TF[idx].h1_trend_direction, rejectReason);
}

bool ValidateTFHardRequirements(int idx, int direction, string &rejectReason)
{
   return ValidateTFPhase2EntryQuality(idx, direction, rejectReason);
}

// ==================================================================
// PHASE 3 — ADVANCED EXECUTION & VOLATILITY QUALITY FILTERS
// ==================================================================

// ------------------------------------------------------------------
// Phase 3.1: Volatility Regime Filter
// ------------------------------------------------------------------
bool ValidateTFPhase3Volatility(int idx, double &out_curr_atr, double &out_base_atr, double &out_ratio, string &reject_reason)
{
   out_curr_atr = 0.0;
   out_base_atr = 0.0;
   out_ratio = 0.0;
   reject_reason = "NONE";
   
   string sym = G_Pairs[idx].symbol;
   int atr_handle = iATR(sym, PERIOD_M5, InpReversal_ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      reject_reason = "TF_P3_VOLATILITY_HANDLE_INVALID";
      return false; // Fail-closed
   }
   
   double atr_current[];
   double atr_baseline[];
   
   // Current ATR: closed M5 candle shift 1
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_current) < 1)
   {
      IndicatorRelease(atr_handle);
      reject_reason = "TF_P3_VOLATILITY_CURRENT_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   // Baseline ATR: closed M5 candles shift 2 -> shift (LOOKBACK + 1)
   if(CopyBuffer(atr_handle, 0, 2, TF_PHASE3_ATR_LOOKBACK, atr_baseline) < TF_PHASE3_ATR_LOOKBACK)
   {
      IndicatorRelease(atr_handle);
      reject_reason = "TF_P3_VOLATILITY_DATA_INSUFFICIENT";
      return false; // Fail-closed
   }
   IndicatorRelease(atr_handle);
   
   out_curr_atr = atr_current[0];
   if(out_curr_atr <= 0.0)
   {
      reject_reason = "TF_P3_VOLATILITY_CURRENT_INVALID";
      return false; // Fail-closed
   }
   
   double sum = 0.0;
   for(int i = 0; i < TF_PHASE3_ATR_LOOKBACK; i++)
   {
      if(atr_baseline[i] <= 0.0)
      {
         reject_reason = "TF_P3_VOLATILITY_BASELINE_INVALID";
         return false; // Fail-closed
      }
      sum += atr_baseline[i];
   }
   out_base_atr = sum / TF_PHASE3_ATR_LOOKBACK;
   
   if(out_base_atr <= 0.0)
   {
      reject_reason = "TF_P3_VOLATILITY_BASELINE_ZERO";
      return false; // Fail-closed
   }
   
   out_ratio = out_curr_atr / out_base_atr;
   G_TF[idx].phase3_current_atr = out_curr_atr;
   G_TF[idx].phase3_baseline_atr = out_base_atr;
   G_TF[idx].phase3_atr_ratio = out_ratio;
   
   if(out_ratio < TF_PHASE3_MIN_ATR_RATIO)
   {
      reject_reason = "VOLATILITY_TOO_LOW";
   }
   else if(out_ratio > TF_PHASE3_MAX_ATR_RATIO)
   {
      reject_reason = "VOLATILITY_SPIKE";
   }
   
   bool pass = (reject_reason == "NONE");
   
   Print("\n[TF_PHASE3_VOLATILITY]");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("CURRENT_ATR_SHIFT=1");
   PrintFormat("BASELINE_ATR_SHIFT=2..%d", TF_PHASE3_ATR_LOOKBACK + 1);
   PrintFormat("CURRENT_ATR=%.5f", out_curr_atr);
   PrintFormat("BASELINE_ATR=%.5f", out_base_atr);
   PrintFormat("ATR_RATIO=%.2f", out_ratio);
   PrintFormat("MIN_RATIO=%.2f", TF_PHASE3_MIN_ATR_RATIO);
   PrintFormat("MAX_RATIO=%.2f", TF_PHASE3_MAX_ATR_RATIO);
   PrintFormat("RESULT=%s", pass ? "PASS" : "REJECT");
   PrintFormat("REASON=%s", reject_reason);
   
   return pass;
}

// ------------------------------------------------------------------
// Phase 3.2: Entry Candle Quality
// ------------------------------------------------------------------
bool ValidateTFPhase3EntryCandle(int idx, int direction, double &out_range, double &out_body, double &out_body_ratio, double &out_close_loc, string &reject_reason)
{
   out_range = 0.0;
   out_body = 0.0;
   out_body_ratio = 0.0;
   out_close_loc = 0.0;
   reject_reason = "NONE";
   
   string sym = G_Pairs[idx].symbol;
   datetime dec_time = iTime(sym, PERIOD_M5, 1);
   if(dec_time <= 0)
   {
      reject_reason = "TF_P3_CANDLE_DATA_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   // Sync / ensure phase3_entry_candle_time is set
   G_TF[idx].phase3_entry_candle_time = dec_time;
   
   // Chronology validation: entry candle cannot precede MSS confirmation candle
   if(G_TF[idx].m5_mss_time > 0 && dec_time < G_TF[idx].m5_mss_time)
   {
      reject_reason = "TF_P3_CANDLE_PRE_MSS";
      return false; // Fail-closed
   }
   
   double high1  = iHigh(sym, PERIOD_M5, 1);
   double low1   = iLow(sym, PERIOD_M5, 1);
   double open1  = iOpen(sym, PERIOD_M5, 1);
   double close1 = iClose(sym, PERIOD_M5, 1);
   
   if(high1 <= 0 || low1 <= 0 || open1 <= 0 || close1 <= 0)
   {
      reject_reason = "TF_P3_CANDLE_DATA_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   out_range = high1 - low1;
   if(out_range <= 0.0)
   {
      reject_reason = "TF_P3_CANDLE_ZERO_RANGE";
      return false; // Fail-closed
   }
   
   out_body = MathAbs(close1 - open1);
   out_body_ratio = out_body / out_range;
   
   G_TF[idx].phase3_entry_candle_range = out_range;
   G_TF[idx].phase3_entry_candle_body = out_body;
   G_TF[idx].phase3_entry_candle_body_ratio = out_body_ratio;
   
   if(direction == 1) // BUY
   {
      // 1. Must be bullish continuation candle
      if(close1 <= open1)
      {
         reject_reason = "BEARISH_OR_FLAT_ENTRY_CANDLE";
         return false;
      }
      
      // 2. Close location ratio (relative to candle low)
      out_close_loc = (close1 - low1) / out_range;
      G_TF[idx].phase3_entry_candle_close_loc = out_close_loc;
      
      // 3. Body ratio check
      if(out_body_ratio < TF_PHASE3_MIN_ENTRY_BODY_RATIO)
      {
         reject_reason = "BODY_RATIO_TOO_SMALL";
         return false;
      }
      
      // 4. Close location check
      if(out_close_loc < TF_PHASE3_MIN_CLOSE_LOCATION_RATIO)
      {
         reject_reason = "CLOSE_LOCATION_TOO_LOW";
         return false;
      }
      
      // 5. Upper rejection wick check (adverse wick)
      double upper_wick_ratio = (high1 - close1) / out_range;
      if(upper_wick_ratio > TF_PHASE3_MAX_REJECTION_WICK_RATIO)
      {
         reject_reason = "UPPER_REJECTION_WICK_TOO_LARGE";
         return false;
      }
   }
   else if(direction == -1) // SELL
   {
      // 1. Must be bearish continuation candle
      if(close1 >= open1)
      {
         reject_reason = "BULLISH_OR_FLAT_ENTRY_CANDLE";
         return false;
      }
      
      // 2. Close location ratio (relative to candle high: closer to low means higher ratio)
      out_close_loc = (high1 - close1) / out_range;
      G_TF[idx].phase3_entry_candle_close_loc = out_close_loc;
      
      // 3. Body ratio check
      if(out_body_ratio < TF_PHASE3_MIN_ENTRY_BODY_RATIO)
      {
         reject_reason = "BODY_RATIO_TOO_SMALL";
         return false;
      }
      
      // 4. Close location check
      if(out_close_loc < TF_PHASE3_MIN_CLOSE_LOCATION_RATIO)
      {
         reject_reason = "CLOSE_LOCATION_TOO_HIGH";
         return false;
      }
      
      // 5. Lower rejection wick check (adverse wick)
      double lower_wick_ratio = (close1 - low1) / out_range;
      if(lower_wick_ratio > TF_PHASE3_MAX_REJECTION_WICK_RATIO)
      {
         reject_reason = "LOWER_REJECTION_WICK_TOO_LARGE";
         return false;
      }
   }
   else
   {
      reject_reason = "INVALID_DIRECTION";
      return false;
   }
   
   return true;
}

// ------------------------------------------------------------------
// Phase 3.3: Spread / Execution Quality
// ------------------------------------------------------------------
bool ValidateTFPhase3ExecutionQuality(int idx, double &out_spread_pts, double &out_spread_atr, string &reject_reason)
{
   out_spread_pts = 0.0;
   out_spread_atr = 0.0;
   reject_reason = "NONE";
   
   string sym = G_Pairs[idx].symbol;
   long spread_pts = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   if(spread_pts < 0 || point <= 0.0)
   {
      reject_reason = "TF_P3_SPREAD_INFO_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   out_spread_pts = (double)spread_pts;
   double spread_price = spread_pts * point;
   
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   if(atr <= 0.0)
   {
      reject_reason = "TF_P3_SPREAD_ATR_INVALID";
      return false; // Fail-closed
   }
   
   out_spread_atr = spread_price / atr;
   G_TF[idx].phase3_spread_points = out_spread_pts;
   G_TF[idx].phase3_spread_atr = out_spread_atr;
   
   if(out_spread_pts > TF_PHASE3_MAX_SPREAD_POINTS)
   {
      reject_reason = "SPREAD_POINTS_EXCEEDED";
   }
   else if(out_spread_atr > TF_PHASE3_MAX_SPREAD_ATR)
   {
      reject_reason = "SPREAD_ATR_EXCEEDED";
   }
   
   bool pass = (reject_reason == "NONE");
   
   Print("\n[TF_PHASE3_SPREAD]");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("SPREAD_POINTS=%.0f", out_spread_pts);
   PrintFormat("SPREAD_ATR=%.2f", out_spread_atr);
   PrintFormat("MAX_SPREAD_ATR=%.2f", TF_PHASE3_MAX_SPREAD_ATR);
   PrintFormat("RESULT=%s", pass ? "PASS" : "REJECT");
   PrintFormat("REASON=%s", reject_reason);
   
   return pass;
}

// ------------------------------------------------------------------
// Phase 3.4: Relative Displacement Extension
// ------------------------------------------------------------------
bool ValidateTFPhase3DisplacementExtension(int idx, int direction, double &out_dist_mss, double &out_disp_range, double &out_rel_ext, string &reject_reason)
{
   out_dist_mss = 0.0;
   out_disp_range = 0.0;
   out_rel_ext = 0.0;
   reject_reason = "NONE";
   
   string sym = G_Pairs[idx].symbol;
   if(G_TF[idx].m5_mss_break_level <= 0.0)
   {
      reject_reason = "MSS_BREAK_LEVEL_INVALID";
      return false; // Fail-closed
   }
   
   double close1 = iClose(sym, PERIOD_M5, 1);
   if(close1 <= 0.0)
   {
      reject_reason = "CLOSE_PRICE_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   out_dist_mss = MathAbs(close1 - G_TF[idx].m5_mss_break_level);
   
   // Retrieve displacement candle range
   out_disp_range = G_TF[idx].m5_displacement_range;
   if(out_disp_range <= 0.0 && G_TF[idx].m5_displacement_time > 0)
   {
      int disp_shift = iBarShift(sym, PERIOD_M5, G_TF[idx].m5_displacement_time, true);
      if(disp_shift >= 1)
      {
         double dh = iHigh(sym, PERIOD_M5, disp_shift);
         double dl = iLow(sym, PERIOD_M5, disp_shift);
         if(dh > dl && dl > 0)
         {
            out_disp_range = dh - dl;
            G_TF[idx].m5_displacement_range = out_disp_range;
         }
      }
   }
   
   if(out_disp_range <= 0.0)
   {
      reject_reason = "DISPLACEMENT_RANGE_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   out_rel_ext = out_dist_mss / out_disp_range;
   G_TF[idx].phase3_rel_disp_extension = out_rel_ext;
   
   if(out_rel_ext > TF_PHASE3_MAX_DISPLACEMENT_EXTENSION)
   {
      reject_reason = "DISPLACEMENT_EXTENSION_EXCEEDED";
      return false;
   }
   
   return true;
}

// ------------------------------------------------------------------
// Phase 3.5: Post-MSS Adverse Retracement
// ------------------------------------------------------------------
bool ValidateTFPhase3PostMSSRetracement(int idx, int direction, double &out_adverse_atr, int &out_mss_shift, datetime &out_scan_start, datetime &out_scan_end, string &reject_reason)
{
   out_adverse_atr = 0.0;
   out_mss_shift = 0;
   out_scan_start = 0;
   out_scan_end = 0;
   reject_reason = "NONE";
   
   if(G_TF[idx].m5_mss_time <= 0 || G_TF[idx].m5_mss_break_level <= 0.0)
   {
      reject_reason = "MSS_METRICS_INVALID";
      return false; // Fail-closed
   }
   
   string sym = G_Pairs[idx].symbol;
   int mss_shift = iBarShift(sym, PERIOD_M5, G_TF[idx].m5_mss_time, false);
   if(mss_shift < 1)
   {
      reject_reason = "MSS_SHIFT_INVALID";
      return false; // Fail-closed
   }
   
   if(mss_shift <= 1)
   {
      out_mss_shift = mss_shift;
      reject_reason = "NO_POST_MSS_CANDLES";
      return false; // Fail-closed
   }
   
   // Safety check on MSS age (cannot exceed reasonable boundary)
   if(mss_shift > TF_MAX_EVENT_BARS + TF_MSS_MAX_WAIT_BARS + TF_MOMENTUM_MAX_BARS + 5)
   {
      reject_reason = "MSS_AGE_EXCEEDED";
      return false; // Fail-closed
   }
   
   out_mss_shift = mss_shift;
   out_scan_start = iTime(sym, PERIOD_M5, mss_shift - 1);
   out_scan_end = iTime(sym, PERIOD_M5, 1);
   if(out_scan_start <= 0 || out_scan_end <= 0)
   {
      reject_reason = "CANDLE_DATA_MISSING";
      return false; // Fail-closed
   }
   
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   if(atr <= 0.0)
   {
      reject_reason = "ATR_UNAVAILABLE";
      return false; // Fail-closed
   }
   
   // Strictly post-MSS closed candles: shift 1 (decision candle) through shift (mss_shift - 1)
   double adverse_distance = 0.0;
   
   if(direction == 1) // BUY
   {
      double lowest_low = DBL_MAX;
      for(int s = 1; s < mss_shift; s++)
      {
         double ls = iLow(sym, PERIOD_M5, s);
         if(ls <= 0.0) { reject_reason = "CANDLE_DATA_MISSING"; return false; }
         if(ls < lowest_low) lowest_low = ls;
      }
      
      // If price dropped below the MSS break level
      if(lowest_low < G_TF[idx].m5_mss_break_level)
         adverse_distance = G_TF[idx].m5_mss_break_level - lowest_low;
      else
         adverse_distance = 0.0;
   }
   else if(direction == -1) // SELL
   {
      double highest_high = 0.0;
      for(int s = 1; s < mss_shift; s++)
      {
         double hs = iHigh(sym, PERIOD_M5, s);
         if(hs <= 0.0) { reject_reason = "CANDLE_DATA_MISSING"; return false; }
         if(hs > highest_high) highest_high = hs;
      }
      
      // If price rallied above the MSS break level
      if(highest_high > G_TF[idx].m5_mss_break_level)
         adverse_distance = highest_high - G_TF[idx].m5_mss_break_level;
      else
         adverse_distance = 0.0;
   }
   else
   {
      reject_reason = "INVALID_DIRECTION";
      return false;
   }
   
   out_adverse_atr = adverse_distance / atr;
   G_TF[idx].phase3_post_mss_adverse_atr = out_adverse_atr;
   
   if(out_adverse_atr > TF_PHASE3_MAX_POST_MSS_ADVERSE_ATR)
   {
      reject_reason = "ADVERSE_RETRACEMENT_EXCEEDED";
      return false;
   }
   
   return true;
}

// ------------------------------------------------------------------
// Phase 3 Centralized Validation Layer
// ------------------------------------------------------------------
bool ValidateTFPhase3EntryContext(int idx, int direction, string &rejectReason)
{
   bool pass = true;
   string first_reject = "";
   string sym = G_Pairs[idx].symbol;
   
   datetime dec_time = iTime(sym, PERIOD_M5, 1);
   G_TF[idx].phase3_entry_candle_time = dec_time;
   
   // 1. Volatility Regime
   double curr_atr = 0.0, base_atr = 0.0, atr_ratio = 0.0;
   string vol_reason = "";
   bool vol_pass = ValidateTFPhase3Volatility(idx, curr_atr, base_atr, atr_ratio, vol_reason);
   if(!vol_pass)
   {
      if(first_reject == "") first_reject = "TF_P3_VOLATILITY_REJECT";
      pass = false;
   }
   
   // 2. Entry Candle Quality
   double c_range = 0.0, c_body = 0.0, c_body_ratio = 0.0, c_close_loc = 0.0;
   string candle_reason = "";
   bool candle_pass = ValidateTFPhase3EntryCandle(idx, direction, c_range, c_body, c_body_ratio, c_close_loc, candle_reason);
   if(!candle_pass)
   {
      if(first_reject == "") first_reject = "TF_P3_ENTRY_CANDLE_REJECT";
      pass = false;
   }
   
   // 3. Spread / Execution Quality
   double spread_pts = 0.0, spread_atr = 0.0;
   string spread_reason = "";
   bool spread_pass = ValidateTFPhase3ExecutionQuality(idx, spread_pts, spread_atr, spread_reason);
   if(!spread_pass)
   {
      if(first_reject == "") first_reject = "TF_P3_SPREAD_REJECT";
      pass = false;
   }
   
   // 4. Relative Displacement Extension
   double dist_mss = 0.0, disp_range = 0.0, rel_ext = 0.0;
   string ext_reason = "";
   bool ext_pass = ValidateTFPhase3DisplacementExtension(idx, direction, dist_mss, disp_range, rel_ext, ext_reason);
   if(!ext_pass)
   {
      if(first_reject == "") first_reject = "TF_P3_DISPLACEMENT_EXTENSION_REJECT";
      pass = false;
   }
   
   // 5. Post-MSS Adverse Retracement
   double adverse_atr = 0.0;
   int mss_shift = 0;
   datetime scan_start = 0, scan_end = 0;
   string retrace_reason = "";
   bool retrace_pass = ValidateTFPhase3PostMSSRetracement(idx, direction, adverse_atr, mss_shift, scan_start, scan_end, retrace_reason);
   if(!retrace_pass)
   {
      if(first_reject == "")
      {
         if(retrace_reason == "NO_POST_MSS_CANDLES")
            first_reject = "TF_P3_NO_POST_MSS_CANDLES";
         else
            first_reject = "TF_P3_ADVERSE_RETRACE_REJECT";
      }
      pass = false;
   }
   
   // Record Phase 3 Funnel & Diagnostic Counters
   datetime p3_dec_time = iTime(sym, PERIOD_M5, 1);
   TFDiag_RecordPhase3(idx, direction, pass, first_reject,
                       vol_pass, candle_pass, spread_pass, ext_pass, retrace_pass, retrace_reason,
                       atr_ratio, c_range, c_body, c_body_ratio, c_close_loc,
                       spread_pts, spread_atr, rel_ext, adverse_atr, p3_dec_time);
                       
   if(pass)
   {
      TFDiag_RecordFunnelStep(idx, direction, TF_FUNNEL_PHASE3_PASS);
      TFDiag_LogFunnel(idx, direction, "PHASE_3", "PASS");
   }
   else
   {
      TFDiag_LogFunnel(idx, direction, "PHASE_3", "REJECT", first_reject);
   }
   
   // Print [TF_PHASE3_DIAGNOSTIC] block
   Print("\n[TF_PHASE3_DIAGNOSTIC]");
   Print("");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("DIRECTION=%s", (direction == 1 ? "BUY" : (direction == -1 ? "SELL" : "NONE")));
   PrintFormat("ENTRY_CANDLE_TIME=%s", TimeToString(G_TF[idx].phase3_entry_candle_time));
   PrintFormat("MSS_TIME=%s", TimeToString(G_TF[idx].m5_mss_time));
   PrintFormat("MOMENTUM_LAST_CLOSED_TIME=%s", TimeToString(G_TF[idx].m5_momentum_last_closed_time));
   Print("");
   Print("VOLATILITY:");
   PrintFormat("  CURRENT_ATR_SHIFT=1");
   PrintFormat("  BASELINE_ATR_RANGE=2..%d", TF_PHASE3_ATR_LOOKBACK + 1);
   PrintFormat("  CURRENT_ATR=%.5f", curr_atr);
   PrintFormat("  BASELINE_ATR=%.5f", base_atr);
   PrintFormat("  ATR_RATIO=%.2f", atr_ratio);
   PrintFormat("  RESULT=%s", vol_pass ? "PASS" : "REJECT (" + vol_reason + ")");
   Print("");
   Print("ENTRY_CANDLE:");
   PrintFormat("  RANGE=%.5f", c_range);
   PrintFormat("  BODY=%.5f", c_body);
   PrintFormat("  BODY_RATIO=%.2f", c_body_ratio);
   PrintFormat("  CLOSE_LOCATION=%.2f", c_close_loc);
   PrintFormat("  RESULT=%s", candle_pass ? "PASS" : "REJECT (" + candle_reason + ")");
   Print("");
   Print("EXECUTION:");
   PrintFormat("  SPREAD_POINTS=%.0f", spread_pts);
   PrintFormat("  SPREAD_ATR=%.2f", spread_atr);
   PrintFormat("  RESULT=%s", spread_pass ? "PASS" : "REJECT (" + spread_reason + ")");
   Print("");
   Print("DISPLACEMENT_EXTENSION:");
   PrintFormat("  DISTANCE_FROM_MSS=%.5f", dist_mss);
   PrintFormat("  DISPLACEMENT_RANGE=%.5f", disp_range);
   PrintFormat("  RELATIVE_EXTENSION=%.2f", rel_ext);
   PrintFormat("  RESULT=%s", ext_pass ? "PASS" : "REJECT (" + ext_reason + ")");
   Print("");
   Print("POST_MSS_RETRACE:");
   PrintFormat("  MSS_SHIFT=%d", mss_shift);
   PrintFormat("  MSS_CANDLE_INCLUDED=false");
   if(mss_shift > 1)
   {
      PrintFormat("  POST_MSS_SCAN_SHIFTS=1..%d", mss_shift - 1);
      PrintFormat("  DECISION_SHIFT=1");
      PrintFormat("  RETRACE_SCAN_START=%s", TimeToString(scan_start));
      PrintFormat("  RETRACE_SCAN_END=%s", TimeToString(scan_end));
      PrintFormat("  ADVERSE_ATR=%.2f", adverse_atr);
      PrintFormat("  MAX_ADVERSE_ATR=%.2f", TF_PHASE3_MAX_POST_MSS_ADVERSE_ATR);
      PrintFormat("  RESULT=%s", retrace_pass ? "PASS" : "REJECT (" + retrace_reason + ")");
   }
   else
   {
      PrintFormat("  POST_MSS_SCAN_SHIFTS=NONE");
      PrintFormat("  DECISION_SHIFT=1");
      PrintFormat("  RESULT=REJECT (%s)", retrace_reason);
   }
   Print("");
   PrintFormat("FINAL_RESULT=%s", pass ? "PASS" : "REJECT");
   if(!pass) PrintFormat("REJECT_REASON=%s", first_reject);
   
   rejectReason = first_reject;
   return pass;
}

bool ValidateTFPhase3EntryContext(int idx)
{
   string rejectReason = "";
   return ValidateTFPhase3EntryContext(idx, G_TF[idx].h1_trend_direction, rejectReason);
}

void LogTFTimeoutSnapshot(int idx)
{
   string sym = G_Pairs[idx].symbol;
   int direction = G_TF[idx].h1_trend_direction;
   string dir_str = (direction == 1) ? "BUY" : ((direction == -1) ? "SELL" : "NONE");
   
   Print("\n[TF_TIMEOUT_SNAPSHOT]");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("DIRECTION=%s", dir_str);
   
   PrintFormat("TOTAL_SCORE=%.0f", G_TF[idx].total_score);
   
   PrintFormat("H1_SCORE=%.0f", G_TF[idx].score_h1_trend);
   PrintFormat("M15_SCORE=%.0f", G_TF[idx].score_m15_pullback);
   PrintFormat("SWEEP_SCORE=%.0f", G_TF[idx].score_sweep);
   PrintFormat("DISPLACEMENT_SCORE=%.0f", G_TF[idx].score_displacement);
   PrintFormat("MSS_SCORE=%.0f", G_TF[idx].score_mss);
   PrintFormat("EVENT_SCORE=%.0f", G_TF[idx].score_event_coherence);
   PrintFormat("MOMENTUM_SCORE=%.0f", G_TF[idx].score_momentum);
   PrintFormat("ENTRY_DISTANCE_SCORE=%.0f", G_TF[idx].score_entry_distance);
   
   int cci_status = 0, rf_status = 0;
   datetime cci_time = 0, rf_time = 0;
   CheckMomentumStatus(idx, cci_status, rf_status, cci_time, rf_time);
   string cci_dir = (cci_status == 1) ? "BUY" : (cci_status == -1 ? "SELL" : "NONE");
   string rf_dir = (rf_status == 1) ? "BUY" : (rf_status == -1 ? "SELL" : "NONE");
   
   PrintFormat("CCI=%s", cci_dir);
   PrintFormat("RF=%s", rf_dir);
   
   double m5_close = iClose(sym, PERIOD_M5, 1);
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   double break_lvl = G_TF[idx].m5_mss_break_level;
   double dist_atr = (atr > 0) ? MathAbs(m5_close - break_lvl) / atr : 0;
   PrintFormat("ENTRY_DISTANCE_ATR=%.2f", dist_atr);
   
   PrintFormat("TIME_IN_ENTRY_READY=%d", G_TF[idx].setup_bar_count);
   PrintFormat("TIMEOUT_REASON=M5_TIMEOUT");
}

// ==================================================================
// DEBUG LOGGING
// ==================================================================

void LogTFDecision(int idx, int direction, string decision, string reason, double score)
{
   string sym = G_Pairs[idx].symbol;
   string dir_str = (direction == 1) ? "BUY" : ((direction == -1) ? "SELL" : "NONE");
   
   if(decision == "REJECT")
   {
      PrintFormat("[TREND-FOLLOWING][%s] REJECT | Reason=%s", sym, reason);
      return;
   }
   
   PrintFormat("\n[TREND-FOLLOWING][%s]", sym);
   PrintFormat("H1:");
   PrintFormat(" Direction=%s", dir_str);
   PrintFormat(" Score=%.0f/20 (%s)", G_TF[idx].score_h1_trend, G_TF[idx].h1_classification);
   PrintFormat(" EMA=%d", G_TF[idx].h1_ema_aligned ? 1 : 0);
   PrintFormat(" Slope=%d", G_TF[idx].h1_slope_positive ? 1 : 0);
   PrintFormat(" Price=%d", G_TF[idx].h1_price_above_ema ? 1 : 0);
   PrintFormat(" Structure=%d", G_TF[idx].h1_structure_valid ? 1 : 0);
   PrintFormat(" Sideway=%d", !G_TF[idx].h1_not_sideway ? 1 : 0);
   
   PrintFormat("\nM15:");
   PrintFormat(" Impulse=%s", (G_TF[idx].m15_impulse_high > 0 || G_TF[idx].m15_impulse_low > 0) ? "YES" : "NO");
   PrintFormat(" Pullback=%s", G_TF[idx].m15_pullback_valid ? "YES" : "NO");
   PrintFormat(" Depth=%.2f ATR", G_TF[idx].m15_pullback_depth);
   PrintFormat(" Protected=%s", (G_TF[idx].m15_protected_low > 0 || G_TF[idx].m15_protected_high > 0) ? "YES" : "NO");
   
   PrintFormat("\nM5:");
   PrintFormat(" State=%s", G_TF[idx].status);
   PrintFormat(" Sweep=%s", G_TF[idx].m5_sweep ? "YES" : "NO");
   PrintFormat(" Displacement=%s", G_TF[idx].m5_displacement ? "YES" : "NO");
   PrintFormat(" MSS=%s", G_TF[idx].m5_mss ? "YES" : "NO");
   
   PrintFormat("\nScore:");
   PrintFormat(" H1=%.0f", G_TF[idx].score_h1_trend);
   PrintFormat(" M15=%.0f", G_TF[idx].score_m15_pullback);
   PrintFormat(" Sweep=%.0f", G_TF[idx].score_sweep);
   PrintFormat(" Disp=%.0f", G_TF[idx].score_displacement);
   PrintFormat(" MSS=%.0f", G_TF[idx].score_mss);
   PrintFormat(" Coh=%.0f", G_TF[idx].score_event_coherence);
   PrintFormat(" Momentum=%.0f", G_TF[idx].score_momentum);
   PrintFormat(" Distance=%.0f", G_TF[idx].score_entry_distance);
   if(G_TF[idx].h1_trend_quality < 20.0) PrintFormat(" DXY=%.0f", G_TF[idx].score_dxy);
   PrintFormat(" Total=%.0f/100", G_TF[idx].total_score);
   
   string next = "NONE";
   if(G_TF[idx].setup_state == TF_STATE_H1_TREND) next = "M15 PULLBACK";
   else if(G_TF[idx].setup_state == TF_STATE_M15_PULLBACK) next = "SWEEP";
   else if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_SWEEP) next = "SWEEP";
   else if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_DISPLACEMENT) next = "DISPLACEMENT";
   else if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_MSS) next = "MSS";
   else if(G_TF[idx].setup_state == TF_STATE_ENTRY_READY) next = "TRIGGER";
   PrintFormat("\nNEXT=%s\n", next);
}

// ==================================================================
// CORE TREND-FOLLOWING SIGNAL LOGIC (STATE MACHINE)
// ==================================================================
// Returns: 1 = BUY Trigger, -1 = SELL Trigger, 0 = Wait/None

int CheckTrendFollowingSignal(int idx)
{
   if(!InpEnableTrendFollowing) return 0;
   
   string sym = G_Pairs[idx].symbol;
   
   // === LAYER 1: H1 TREND REGIME (On H1 New Bar) ===
   // Note: We share H1 new bar tracking with Counter-Trend.
   // We call on every tick but only re-evaluate on H1 bar change.
   // Use a separate check by reading H1 bar time directly.
   {
      datetime h1_tm[];
      if(CopyTime(sym, G_Pairs[idx].htf, 0, 1, h1_tm) >= 1)
      {
         static datetime s_tf_h1_last_time[];
         static bool s_tf_h1_initialized = false;
         
         if(!s_tf_h1_initialized)
         {
            ArrayResize(s_tf_h1_last_time, TOTAL_PAIRS);
            ArrayInitialize(s_tf_h1_last_time, 0);
            s_tf_h1_initialized = true;
         }
         
         if(h1_tm[0] != s_tf_h1_last_time[idx])
         {
            s_tf_h1_last_time[idx] = h1_tm[0];
            
            int prev_dir = G_TF[idx].h1_trend_direction;
            double new_protected = 0.0;
            int new_dir = EvaluateH1TrendRegime(idx, new_protected);
            
            if(new_dir != 0)
            {
               if(G_TF[idx].setup_state == TF_STATE_NONE)
               {
                  G_TF[idx].h1_trend_direction = new_dir;
                  G_TF[idx].h1_protected_structure = new_protected;
                  G_TF[idx].setup_state = TF_STATE_H1_TREND;
                  G_TF[idx].setup_bar_count = 0;
                  G_TF[idx].status = "H1 TREND";
                  G_TF[idx].tf_setup_id = TFDiag_StartSetup(idx, new_dir);
                  TFDiag_RecordFunnelStep(idx, new_dir, TF_FUNNEL_H1_VALID);
                  TFDiag_LogFunnel(idx, new_dir, "H1_TREND", "DETECTED", StringFormat("QUALITY=%.0f", G_TF[idx].h1_trend_quality));
                  LogTFDecision(idx, new_dir, "H1_TREND", "Trend detected", 0);
               }
               else if(prev_dir != 0 && prev_dir != new_dir)
               {
                  // H1 trend changed direction → full reset old, init new immediately
                  ResetTFSetup(idx, "H1_SETUP_INVALIDATED");
                  EvaluateH1TrendRegime(idx, new_protected); // Re-evaluate to set new state
                  G_TF[idx].h1_trend_direction = new_dir;
                  G_TF[idx].h1_protected_structure = new_protected;
                  G_TF[idx].setup_state = TF_STATE_H1_TREND;
                  G_TF[idx].setup_bar_count = 0;
                  G_TF[idx].status = "H1 TREND (FLIPPED)";
                  G_TF[idx].tf_setup_id = TFDiag_StartSetup(idx, new_dir);
                  TFDiag_RecordFunnelStep(idx, new_dir, TF_FUNNEL_H1_VALID);
                  TFDiag_LogFunnel(idx, new_dir, "H1_TREND", "FLIPPED", StringFormat("QUALITY=%.0f", G_TF[idx].h1_trend_quality));
                  LogTFDecision(idx, new_dir, "H1_TREND", "Trend flipped", 0);
               }
               else
               {
                  // Recovered from weakened, or just continuing
                  G_TF[idx].h1_trend_direction = new_dir;
               }
            }
            else
            {
               // No clear trend → check invalidation
               if(G_TF[idx].setup_state != TF_STATE_NONE)
               {
                  G_TF[idx].status = "H1_REGIME_WEAKENED";
                  PrintFormat("[TREND-FOLLOWING][%s] H1_REGIME_WEAKENED", sym);
               }
            }
            
            // Check H1 trend invalidation (protected structure broken)
            if(G_TF[idx].setup_state != TF_STATE_NONE && CheckH1TrendInvalidation(idx))
            {
               ResetTFSetup(idx, "H1_SETUP_INVALIDATED");
               return 0;
            }
         }
      }
   }
   
   // If no H1 trend → stop
   if(G_TF[idx].h1_trend_direction == 0) return 0;
   if(G_TF[idx].setup_state == TF_STATE_NONE) return 0;
   
   // Block progression if H1 is weakened (quality < 15.0)
   if(G_TF[idx].h1_trend_quality < 15.0) return 0;
   
   int dir = G_TF[idx].h1_trend_direction;
   if(G_TF[idx].tf_setup_id == 0)
   {
      G_TF[idx].tf_setup_id = TFDiag_StartSetup(idx, dir);
      TFDiag_RecordFunnelStep(idx, dir, TF_FUNNEL_H1_VALID);
   }
   
   // === LAYER 2: M15 PULLBACK (On M15 New Bar) ===
   if(IsNewBar_M15_TF(idx))
   {
      G_TF[idx].m15_pullback_bar_count++;
      
      // 1. Evaluate pullback FIRST to allow impulse refresh
      if(G_TF[idx].setup_state >= TF_STATE_H1_TREND)
      {
         bool pb_valid = EvaluateM15Pullback(idx, dir);
         if(pb_valid && G_TF[idx].setup_state == TF_STATE_H1_TREND)
         {
            SetTFState(idx, TF_STATE_M15_PULLBACK, "M15_PULLBACK_CONFIRMED");
            G_TF[idx].status = "M15 PULLBACK";
            LogTFDecision(idx, dir, "M15_PULLBACK", "Pullback detected", 0);
         }
      }
      
      // 2. Check M15 pullback invalidation (after potential refresh)
      if(G_TF[idx].setup_state >= TF_STATE_M15_PULLBACK && CheckM15PullbackInvalidation(idx))
      {
         // Pullback became reversal → reset M15 + M5 but keep H1
         LogTFReset(idx, "M15", "M15_PROTECTED_STRUCTURE_BROKEN");
         ResetTFM15Evidence(idx);
         ResetTFM5Evidence(idx);
         SetTFState(idx, TF_STATE_H1_TREND, "M15_INVALIDATION");
         G_TF[idx].status = "M15 PULLBACK INVALID";
         TFDiag_RecordM15Invalidation(idx, dir);
         TFDiag_LogFunnel(idx, dir, "M15_INVALIDATION", "REVERSAL_BROKEN");
         LogTFDecision(idx, dir, "M15_INVALID", "Pullback became reversal", 0);
         return 0;
      }
      
      // Pullback timeout
      if(G_TF[idx].m15_pullback_bar_count > TF_PULLBACK_MAX_BARS && 
         G_TF[idx].setup_state == TF_STATE_H1_TREND)
      {
         // Reset pullback counter but don't kill setup
         G_TF[idx].m15_pullback_bar_count = 0;
      }
   }
   
   // === LAYER 3: M5 ENTRY TRIGGER (On M5 New Bar) ===
   if(G_TF[idx].setup_state < TF_STATE_M15_PULLBACK) return 0;
   if(!G_TF[idx].m15_pullback_valid) return 0;
   
   if(!IsNewBar_M5_TF(idx)) return 0;
   
   // Update indicator states for momentum check
   UpdateIndicatorsState(idx);
   
   // Track setup age
   G_TF[idx].setup_bar_count++;
   
   // Setup timeout
   if(G_TF[idx].setup_bar_count > TF_MAX_SETUP_BARS)
   {
      if(G_TF[idx].setup_state == TF_STATE_ENTRY_READY)
      {
         LogTFTimeoutSnapshot(idx);
      }
      
      // Reset M15 and M5 but keep H1
      ResetTFM15Evidence(idx);
      ResetTFM5Evidence(idx);
      
      SetTFState(idx, TF_STATE_H1_TREND, "M15_TIMEOUT");
      G_TF[idx].status = "M15 TIMEOUT RESTART";
      G_TF[idx].setup_bar_count = 0;
      PrintFormat("[TREND-FOLLOWING][%s] SETUP TIMEOUT -> Reset to H1", sym);
      return 0;
   }
   
   // Evaluate M5 evidence
   if(G_TF[idx].setup_state == TF_STATE_M15_PULLBACK)
   {
      SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M15_PULLBACK_READY");
      G_TF[idx].status = "WAIT SWEEP";
      if(G_TF[idx].m5_momentum_start_time == 0)
      {
         datetime m5_tm[];
         datetime cur_m5 = (CopyTime(sym, PERIOD_M5, 1, 1, m5_tm) >= 1) ? m5_tm[0] : 0;
         G_TF[idx].m5_momentum_start_time = (G_TF[idx].m15_pullback_start_time > 0) ? G_TF[idx].m15_pullback_start_time : cur_m5;
      }
   }
   else if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_SWEEP && G_TF[idx].m5_momentum_start_time == 0)
   {
      datetime m5_tm[];
      datetime cur_m5 = (CopyTime(sym, PERIOD_M5, 1, 1, m5_tm) >= 1) ? m5_tm[0] : 0;
      G_TF[idx].m5_momentum_start_time = cur_m5;
   }
   EvaluateM5Trigger(idx, dir);
   
   // Check if all evidence is ready
   double score = CalculateTFScore(idx);
   
   datetime m5_score_time = iTime(sym, PERIOD_M5, 1);
   TFDiag_RecordScore(idx, dir, score, InpTF_RequiredScore, m5_score_time);
   
   if(score >= InpTF_RequiredScore)
   {
      TFDiag_RecordFunnelStep(idx, dir, TF_FUNNEL_SCORE_PASS);
      TFDiag_LogFunnel(idx, dir, "SCORE", "PASS", StringFormat("SCORE=%.0f REQ=%.0f", score, InpTF_RequiredScore));
      
      Print("\n[SCORE_REQ_REACHED]");
      PrintFormat("SYMBOL=%s", sym);
      PrintFormat("H1=%.0f", G_TF[idx].score_h1_trend);
      PrintFormat("M15=%.0f", G_TF[idx].score_m15_pullback);
      PrintFormat("SWEEP=%.0f", G_TF[idx].score_sweep);
      PrintFormat("DISPLACEMENT=%.0f", G_TF[idx].score_displacement);
      PrintFormat("MSS=%.0f", G_TF[idx].score_mss);
      PrintFormat("COHERENCE=%.0f", G_TF[idx].score_event_coherence);
      PrintFormat("MOMENTUM=%.0f", G_TF[idx].score_momentum);
      PrintFormat("ENTRY_DISTANCE=%.0f", G_TF[idx].score_entry_distance);
      if(G_TF[idx].h1_trend_quality < 20.0) PrintFormat("DXY=%.0f", G_TF[idx].score_dxy);
      PrintFormat("TOTAL=%.0f", score);
      // === FINAL GATE ===
      SetTFState(idx, TF_STATE_ENTRY_READY, "SCORE_REQ_REACHED");
      
      string rejectReason = "";
      bool hardPass = ValidateTFPhase2EntryQuality(idx, dir, rejectReason);
      
      if(hardPass)
      {
         datetime decision_candle_time = iTime(sym, PERIOD_M5, 1);
         G_TF[idx].phase3_entry_candle_time = decision_candle_time;
         
         string p3RejectReason = "";
         bool p3Pass = ValidateTFPhase3EntryContext(idx, dir, p3RejectReason);
         
         if(p3Pass)
         {
            G_TF[idx].status = "TRIGGER";
            LogTFDecision(idx, dir, "ENTRY_READY", "All Gates Passed", score);
            
            Print("\n[TF_FINAL_PASS]");
            PrintFormat("SYMBOL=%s", sym);
            PrintFormat("DIRECTION=%s", (dir == 1 ? "BUY" : "SELL"));
            PrintFormat("SCORE=%.0f", score);
            PrintFormat("DXY=%s", (G_TF[idx].h1_trend_quality >= TF_H1_QUALITY_STRONG ? "NOT_REQUIRED (H1 STRONG)" : "PASS (H1 BASE)"));
            PrintFormat("PHASE2=PASS");
            PrintFormat("PHASE3=PASS");
            
            TFDiag_RecordFunnelStep(idx, dir, TF_FUNNEL_FINAL_ENTRY);
            TFDiag_RecordFinalEntry(idx, dir);
            TFDiag_LogFunnel(idx, dir, "FINAL_ENTRY", "TRIGGER", StringFormat("SCORE=%.0f", score));
            
            int result = dir;
            ResetTFSetup(idx, "Entry Triggered - Reset");
            return result;
         }
         else
         {
            LogTFDecision(idx, dir, "REJECT", p3RejectReason, score);
            
            if(p3RejectReason == "TF_P3_SPREAD_REJECT" || p3RejectReason == "TF_P3_VOLATILITY_REJECT" || p3RejectReason == "TF_P3_NO_POST_MSS_CANDLES")
            {
               // Environmental condition / waiting for post-MSS candle: do NOT reset H1/M15/M5 evidence. EA waits for next candle/tick.
               G_TF[idx].status = "WAIT: " + p3RejectReason;
               return 0;
            }
            else if(p3RejectReason == "TF_P3_ENTRY_CANDLE_REJECT")
            {
               // Entry candle quality not confirmed: wait for next closed candle within momentum window
               G_TF[idx].status = "WAIT: " + p3RejectReason;
               return 0;
            }
            else if(p3RejectReason == "TF_P3_DISPLACEMENT_EXTENSION_REJECT")
            {
               // Price overextended relative to displacement range: reset M5 only, keep H1+M15
               ResetTFM5Evidence(idx);
               SetTFState(idx, TF_STATE_M15_PULLBACK, "DISPLACEMENT_EXTENSION_REJECT");
               G_TF[idx].status = "M5 RE-ACCUMULATING (displacement_extension)";
               return 0;
            }
            else if(p3RejectReason == "TF_P3_ADVERSE_RETRACE_REJECT")
            {
               // Price retraced too deep against MSS: reset M5 only, keep H1+M15
               ResetTFM5Evidence(idx);
               SetTFState(idx, TF_STATE_M15_PULLBACK, "ADVERSE_RETRACE_REJECT");
               G_TF[idx].status = "M5 RE-ACCUMULATING (adverse_retrace)";
               return 0;
            }
            else
            {
               G_TF[idx].status = "WAIT: " + p3RejectReason;
               return 0;
            }
         }
      }
      else
      {
         if(StringFind(rejectReason, "DXY_") == 0 || rejectReason == "TF_P2_DXY_REJECT")
         {
            G_TF[idx].status = "WAIT: " + rejectReason;
            return 0;
         }
         else if(rejectReason == "TF_P2_ENTRY_LOCATION_REJECT" || rejectReason == "ENTRY_DISTANCE_TOO_FAR")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx); // Reset M5 only, keep H1+M15
            SetTFState(idx, TF_STATE_M15_PULLBACK, "ENTRY_LOCATION_REJECT");
            G_TF[idx].status = "M5 RE-ACCUMULATING (location)";
            return 0;
         }
         else if(rejectReason == "TF_P2_DISPLACEMENT_REJECT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx);
            SetTFState(idx, TF_STATE_M15_PULLBACK, "DISPLACEMENT_REJECT");
            G_TF[idx].status = "M5 RE-ACCUMULATING (displacement)";
            return 0;
         }
         else if(rejectReason == "TF_P2_MSS_REJECT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx);
            SetTFState(idx, TF_STATE_M15_PULLBACK, "MSS_REJECT");
            G_TF[idx].status = "M5 RE-ACCUMULATING (mss)";
            return 0;
         }
         else if(rejectReason == "TF_P2_M15_REJECT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM15Evidence(idx);
            ResetTFM5Evidence(idx);
            SetTFState(idx, TF_STATE_H1_TREND, "M15_QUALITY_REJECT");
            G_TF[idx].status = "H1 (M15 reject)";
            return 0;
         }
         else if(rejectReason == "TF_P2_H1_REJECT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFSetup(idx, "H1_QUALITY_REJECT");
            return 0;
         }
         else if(rejectReason == "EVENT_NOT_COHERENT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx); // Reset M5 only
            SetTFState(idx, TF_STATE_M15_PULLBACK, "EVENT_NOT_COHERENT_REJECT");
            G_TF[idx].status = "M5 RE-ACCUMULATING (coherence)";
            return 0;
         }
         else
         {
            // Do not reset setup_state here, keep it wherever it is (e.g. TF_STATE_ENTRY_READY or M5 wait state)
            G_TF[idx].status = "WAIT: " + rejectReason;
         }
      }
   }
   else
   {
      // Log missing components periodically
      string missing = "";
      if(G_TF[idx].score_h1_trend < 15.0) missing += "H1_TREND ";
      if(G_TF[idx].score_m15_pullback < 20.0) missing += "M15_PB ";
      if(!G_TF[idx].m5_sweep) missing += "SWEEP ";
      if(!G_TF[idx].m5_displacement) missing += "DISP ";
      if(!G_TF[idx].m5_mss) missing += "MSS ";
      if(G_TF[idx].score_momentum < 10.0) missing += "MOM ";
      
      G_TF[idx].status = "Score " + IntegerToString((int)score) + "/" + IntegerToString((int)InpTF_RequiredScore) + " | Missing: " + missing;
   }
   
   return 0;
}
//+------------------------------------------------------------------+
