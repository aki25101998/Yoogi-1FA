//+------------------------------------------------------------------+
//|                                        TrendFollowingEngine.mqh  |
//|                                                  Yoogi Trading   |
//|   Trend-Following Entry Engine - 3-Layer Architecture            |
//|   Layer 1: H1 Trend Regime                                       |
//|   Layer 2: M15 Pullback Detection                                |
//|   Layer 3: M5 Entry Trigger                                      |
//+------------------------------------------------------------------+
#property strict

const string TF_ENGINE_VERSION = "TF_MOMENTUM_10BAR";

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
   G_TF[idx].h1_ema_aligned = false;
   G_TF[idx].h1_slope_positive = false;
   G_TF[idx].h1_price_above_ema = false;
   G_TF[idx].h1_structure_valid = false;
   G_TF[idx].h1_not_sideway = false;
   
   ResetTFM15Evidence(idx);
   ResetTFM5Evidence(idx);
   
   G_TF[idx].total_score = 0.0;
   G_TF[idx].setup_state = TF_STATE_NONE;
   G_TF[idx].setup_bar_count = 0;
   G_TF[idx].status = "NO SETUP";
   
   G_TF[idx].h1_protected_structure = 0.0;
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
      G_TF[idx].h1_trend_quality = buy_structure ? 20.0 : 15.0;
      G_TF[idx].score_h1_trend = buy_structure ? 20.0 : 15.0;
      
      // Set protected structure: if price breaks below recent swing low, trend invalid
      if(slCount >= 1) out_protected_struct = swL[0];
   }
   else if(sell_minimum)
   {
      direction = -1;
      G_TF[idx].h1_ema_aligned = sell_ema;
      G_TF[idx].h1_slope_positive = sell_slope;
      G_TF[idx].h1_price_above_ema = sell_price;
      G_TF[idx].h1_structure_valid = sell_structure;
      G_TF[idx].h1_not_sideway = not_sideway;
      G_TF[idx].h1_trend_quality = sell_structure ? 20.0 : 15.0;
      G_TF[idx].score_h1_trend = sell_structure ? 20.0 : 15.0;
      
      // Set protected structure: if price breaks above recent swing high, trend invalid
      if(shCount >= 1) out_protected_struct = swH[0];
   }
   else
   {
      G_TF[idx].h1_trend_quality = 0.0;
      G_TF[idx].score_h1_trend = 0.0;
   }
   
   return direction;
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
         
         bool depth_ok = (depth >= TF_PULLBACK_MIN_DEPTH_ATR && depth <= TF_PULLBACK_MAX_DEPTH_ATR);
         bool price_above_protected = (G_TF[idx].m15_protected_low > 0.0 && close[0] > G_TF[idx].m15_protected_low);
         
         if(depth_ok && distance_to_ema >= -0.5 && price_above_protected)
         {
            G_TF[idx].m15_pullback_quality = 20.0;
            G_TF[idx].score_m15_pullback = 20.0;
            G_TF[idx].m15_pullback_valid = true;
            return true;
         }
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
         
         bool depth_ok = (depth >= TF_PULLBACK_MIN_DEPTH_ATR && depth <= TF_PULLBACK_MAX_DEPTH_ATR);
         bool price_below_protected = (G_TF[idx].m15_protected_high > 0.0 && close[0] < G_TF[idx].m15_protected_high);
         
         if(depth_ok && distance_to_ema >= -0.5 && price_below_protected)
         {
            G_TF[idx].m15_pullback_quality = 20.0;
            G_TF[idx].score_m15_pullback = 20.0;
            G_TF[idx].m15_pullback_valid = true;
            return true;
         }
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
   
   // --- FRESHNESS UPDATE: Time-based bar calculation ---
   long period_sec = PeriodSeconds(m5);
   if(G_TF[idx].m5_sweep && G_TF[idx].m5_sweep_time > 0)
   {
      long bars_since_sweep = (current_time - G_TF[idx].m5_sweep_time) / period_sec;
      if(bars_since_sweep > TF_MAX_EVENT_BARS) { ResetTFM5Evidence(idx); SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M5_TIMEOUT"); return; }
   }
   if(G_TF[idx].m5_displacement && G_TF[idx].m5_displacement_time > 0)
   {
      long bars_since_disp = (current_time - G_TF[idx].m5_displacement_time) / period_sec;
      if(bars_since_disp > TF_MAX_EVENT_BARS) { ResetTFM5Evidence(idx); SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M5_TIMEOUT"); return; }
   }
   if(G_TF[idx].m5_mss && G_TF[idx].m5_mss_time > 0)
   {
      long bars_since_mss = (current_time - G_TF[idx].m5_mss_time) / period_sec;
      if(bars_since_mss > TF_MAX_EVENT_BARS) { ResetTFM5Evidence(idx); SetTFState(idx, TF_STATE_M5_WAIT_SWEEP, "M5_TIMEOUT"); return; }
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
      
      if(best_candidate_idx != -1)
      {
         G_TF[idx].m5_sweep = true;
         G_TF[idx].m5_sweep_time = current_time;
         G_TF[idx].m5_sweep_price = sweep_target;
         G_TF[idx].m5_sweep_level = sweep_target;
         G_TF[idx].score_sweep = 10.0;
         SetTFState(idx, TF_STATE_M5_WAIT_DISPLACEMENT, "M5_SWEEP_CONFIRMED");
         G_TF[idx].status = "WAIT DISPLACEMENT";
         
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
            G_TF[idx].m5_displacement = true;
            G_TF[idx].m5_displacement_time = current_time;
            G_TF[idx].m5_displacement_price = close[0];
            G_TF[idx].score_displacement = 10.0;
            SetTFState(idx, TF_STATE_M5_WAIT_MSS, "M5_DISPLACEMENT_CONFIRMED");
            G_TF[idx].status = "WAIT MSS";
            PrintFormat("[TREND-FOLLOWING][%s] M5 Displacement Confirmed (dir=%d) on time=%s", sym, trend_dir, TimeToString(current_time));
         }
         else
         {
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
            G_TF[idx].m5_mss = true;
            G_TF[idx].m5_mss_time = current_time;
            G_TF[idx].m5_mss_break_level = breakLvl;
            G_TF[idx].score_mss = 10.0;
            SetTFState(idx, TF_STATE_ENTRY_READY, "M5_MSS_CONFIRMED"); // Forward to entry validation
            G_TF[idx].status = "MSS CONFIRMED";
            PrintFormat("[TREND-FOLLOWING][%s] M5 MSS Confirmed (dir=%d, level=%.5f) on time=%s", sym, trend_dir, breakLvl, TimeToString(current_time));
            // Start Momentum Window
            G_TF[idx].m5_momentum_start_time = current_time;
            G_TF[idx].m5_momentum_bars_elapsed = 0;
            G_TF[idx].m5_momentum_last_closed_time = iTime(sym, PERIOD_M5, 1);
            G_TF[idx].m5_momentum_cci = false;
            G_TF[idx].m5_momentum_rf = false;
            G_TF[idx].m5_momentum_pc = false;
            G_TF[idx].score_momentum = 0.0;
         }
         else
         {
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
      
      Print("\n[TF_MOMENTUM_DIAGNOSTIC]");
      PrintFormat("SYMBOL=%s", sym);
      PrintFormat("DIRECTION=%s", (trend_dir == 1 ? "BUY" : "SELL"));
      PrintFormat("MSS_TIME=%s", TimeToString(G_TF[idx].m5_mss_time));
      PrintFormat("CLOSED_M5_TIME=%s", TimeToString(closed_m5_time));
      PrintFormat("BAR=%d/%d", bars_elapsed, TF_MOMENTUM_MAX_BARS);
      PrintFormat("CCI=%s", G_TF[idx].m5_momentum_cci ? "PASS" : "FAIL");
      PrintFormat("RF=%s", G_TF[idx].m5_momentum_rf ? "PASS" : "FAIL");
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
      
      if(G_TF[idx].score_momentum == 10.0)
      {
         Print("\n[TF_SCORE_DIAGNOSTIC]");
         PrintFormat("SYMBOL=%s", sym);
         PrintFormat("H1=%.0f", G_TF[idx].score_h1_trend);
         PrintFormat("M15=%.0f", G_TF[idx].score_m15_pullback);
         PrintFormat("SWEEP=%.0f", G_TF[idx].score_sweep);
         PrintFormat("DISPLACEMENT=%.0f", G_TF[idx].score_displacement);
         PrintFormat("MSS=%.0f", G_TF[idx].score_mss);
         PrintFormat("COHERENCE=%.0f", G_TF[idx].score_event_coherence);
         PrintFormat("MOMENTUM=%.0f", G_TF[idx].score_momentum);
         
         double d_atr=0, max_d=0;
         bool dist_valid = ValidateTFEntryDistance(idx, G_TF[idx].h1_trend_direction, d_atr, max_d);
         G_TF[idx].score_entry_distance = dist_valid ? 10.0 : 0.0;
         PrintFormat("ENTRY_DISTANCE=%.0f", G_TF[idx].score_entry_distance);
         
         double current_total = G_TF[idx].score_h1_trend + G_TF[idx].score_m15_pullback + G_TF[idx].score_sweep + G_TF[idx].score_displacement + G_TF[idx].score_mss + G_TF[idx].score_event_coherence + G_TF[idx].score_momentum + G_TF[idx].score_entry_distance;
         PrintFormat("TOTAL=%.0f", current_total);
         
         if(current_total == 100.0) {
             Print("[SCORE_100_REACHED]");
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
   
   // Reset to false on each new evaluation so it truly reflects the current closed candle
   cci_confirmed = false;
   rf_confirmed = false;
   pc_confirmed = false;
   
   if(cci_status == trend_dir && cci_time >= G_TF[idx].m5_mss_time)
   {
      cci_confirmed = true;
      G_TF[idx].m5_momentum_cci_time = closed_m5_time; 
   }
      
   if(rf_status == trend_dir && rf_time >= G_TF[idx].m5_mss_time)
   {
      rf_confirmed = true;
      G_TF[idx].m5_momentum_rf_time = closed_m5_time;
   }
   
   // Evaluate Price Continuation
   double close1 = iClose(sym, PERIOD_M5, 1);
   double close2 = iClose(sym, PERIOD_M5, 2);
   
   bool protected_intact = false;
   if(trend_dir == 1) {
      double prot_low = (G_TF[idx].m15_protected_low > 0.0) ? G_TF[idx].m15_protected_low : G_TF[idx].h1_protected_structure;
      if(prot_low > 0.0 && close1 >= prot_low) protected_intact = true;
      
      if(close1 > close2 && close1 > G_TF[idx].m5_mss_break_level && protected_intact)
         pc_confirmed = true;
   }
   else if(trend_dir == -1) {
      double prot_high = (G_TF[idx].m15_protected_high > 0.0) ? G_TF[idx].m15_protected_high : G_TF[idx].h1_protected_structure;
      if(prot_high > 0.0 && close1 <= prot_high) protected_intact = true;
      
      if(close1 < close2 && close1 < G_TF[idx].m5_mss_break_level && protected_intact)
         pc_confirmed = true;
   }
   
   if(pc_confirmed) G_TF[idx].m5_momentum_pc_time = closed_m5_time;
}

// ==================================================================
// EVENT COHERENCE CHECK
// ==================================================================
// Sweep → Displacement → MSS must be within TF_MAX_EVENT_BARS of each other

bool CheckTFEventCoherence(int idx)
{
   if(!G_TF[idx].m5_sweep || !G_TF[idx].m5_displacement || !G_TF[idx].m5_mss)
      return false;
   
   if(G_TF[idx].m5_sweep_time == 0 || G_TF[idx].m5_displacement_time == 0 || G_TF[idx].m5_mss_time == 0)
      return false;
      
   // Events can happen on the same candle (==), but must not happen backward in time (>)
   if(G_TF[idx].m5_sweep_time > G_TF[idx].m5_displacement_time) return false;
   if(G_TF[idx].m5_displacement_time > G_TF[idx].m5_mss_time) return false;
   if(G_TF[idx].m15_protected_confirmed_time > G_TF[idx].m5_sweep_time) return false;
   
   // Strict Freshness: entire sequence must complete within TF_MAX_EVENT_BARS
   long period_sec = PeriodSeconds(PERIOD_M5);
   long total_sequence_bars = (G_TF[idx].m5_mss_time - G_TF[idx].m5_sweep_time) / period_sec;
   if(total_sequence_bars > TF_MAX_EVENT_BARS) return false;
   
   G_TF[idx].score_event_coherence = 10.0;
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
   G_TF[idx].score_entry_distance = dist_valid ? 10.0 : 0.0;
   
   if(CheckTFEventCoherence(idx)) {
      G_TF[idx].score_event_coherence = 10.0;
   } else {
      G_TF[idx].score_event_coherence = 0.0;
   }

   G_TF[idx].total_score = G_TF[idx].score_h1_trend
                         + G_TF[idx].score_m15_pullback
                         + G_TF[idx].score_sweep
                         + G_TF[idx].score_displacement
                         + G_TF[idx].score_mss
                         + G_TF[idx].score_event_coherence
                         + G_TF[idx].score_momentum
                         + G_TF[idx].score_entry_distance;
   
   return G_TF[idx].total_score;
}

// ==================================================================
// TF HARD REQUIREMENTS VALIDATION
// ==================================================================

bool ValidateTFHardRequirements(int idx, int direction, string &rejectReason)
{
   bool pass = true;
   string first_reject = "";
   
   // 1. H1 Trend
   if(G_TF[idx].h1_trend_direction != direction) { if(first_reject=="") first_reject = "H1_TREND_NOT_STRONG"; pass = false; }
   if(G_TF[idx].h1_trend_quality < 20.0) { if(first_reject=="") first_reject = "H1_TREND_NOT_STRONG"; pass = false; }
   
   // 2. M15 Pullback
   if(!G_TF[idx].m15_pullback_valid) { 
      if(first_reject=="") first_reject = (G_TF[idx].m15_impulse_high == 0.0 && G_TF[idx].m15_impulse_low == 0.0) ? "M15_IMPULSE_NOT_FOUND" : "M15_PULLBACK_INVALID";
      pass = false; 
   }
   if(G_TF[idx].m15_pullback_quality < 20.0) { if(first_reject=="") first_reject = "M15_PULLBACK_INVALID"; pass = false; }
   
   // 3. M5 Events
   if(!G_TF[idx].m5_sweep) { if(first_reject=="") first_reject = "M5_SWEEP_NOT_FOUND"; pass = false; }
   if(!G_TF[idx].m5_displacement) { if(first_reject=="") first_reject = "M5_DISPLACEMENT_NOT_AFTER_SWEEP"; pass = false; }
   if(!G_TF[idx].m5_mss) { if(first_reject=="") first_reject = "M5_MSS_NOT_AFTER_DISPLACEMENT"; pass = false; }
   
   // 4. Event Coherence
   bool event_coherent = CheckTFEventCoherence(idx);
   if(!event_coherent) { 
      if(first_reject=="") first_reject = "EVENT_NOT_COHERENT";
      pass = false; 
   }
   
   // 5. Entry Distance
   double d_atr=0, max_d=0;
   bool dist_valid = ValidateTFEntryDistance(idx, direction, d_atr, max_d);
   if(G_TF[idx].m5_mss_break_level <= 0.0) { if(first_reject=="") first_reject = "MSS_BREAK_LEVEL_INVALID"; pass = false; }
   if(!dist_valid) { if(first_reject=="") first_reject = "ENTRY_DISTANCE_TOO_FAR"; pass = false; }
   
   // 6. Momentum (score-based: 2/3 with PC required)
   if(G_TF[idx].score_momentum < 10.0)
   {
      if(first_reject=="") first_reject = "MOMENTUM_INCOMPLETE";
      pass = false;
   }
   
   // 7. Score
   double score = CalculateTFScore(idx);
   if(score != 100.0) { if(first_reject=="") first_reject = (score > 100.0) ? "SCORE_OVER_100_LEAKAGE" : "SCORE_BELOW_100"; pass = false; }
   
   // 8. DXY Confirmation
   string dxy_reason = "";
   
   if(G_Pairs[idx].isUSDPair && score == 100.0)
   {
      PrintFormat("\n[TF_DXY_GATE]\nPAIR=%s\nCALLING=DXYTrendFollowingEngine", G_Pairs[idx].symbol);
   }
   
   bool dxy_pass = CheckDXYTrendFollowingConfirmation(idx, direction, dxy_reason);
   if(!dxy_pass)
   {
      if(first_reject=="") first_reject = dxy_reason;
      pass = false;
   }

   
   // Gather diagnostic values
   string sym = G_Pairs[idx].symbol;
   string dir_str = (direction == 1) ? "BUY" : ((direction == -1) ? "SELL" : "NONE");
   double m5_close = iClose(sym, PERIOD_M5, 1);
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
   PrintFormat("  MSS=%s", G_TF[idx].m5_mss ? "true" : "false");
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
   // Momentum Reason diagnostic
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
   PrintFormat("  CLOSE=%.5f", m5_close);
   PrintFormat("  ATR=%.5f", atr);
   PrintFormat("  DISTANCE_ATR=%.2f", d_atr);
   PrintFormat("  MAX_DISTANCE_ATR=%.2f", max_d);
   PrintFormat("  VALID=%s", dist_valid ? "true" : "false");
   PrintFormat("  SCORE=%.0f", G_TF[idx].score_entry_distance);
   Print("");

   PrintFormat("TOTAL_SCORE=%.0f", score);
   Print("");
   PrintFormat("FINAL_GATE=%s", pass ? "PASS" : "FAIL");
   if(!pass) PrintFormat("REJECT_REASON=%s", first_reject);
   
   rejectReason = first_reject;
   return pass;
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
   PrintFormat(" Score=%.0f/20", G_TF[idx].score_h1_trend);
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
   
   // Block progression if H1 is weakened
   if(G_TF[idx].h1_trend_quality < 20.0) return 0;
   
   int dir = G_TF[idx].h1_trend_direction;
   
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
   }
   EvaluateM5Trigger(idx, dir);
   
   // Check if all evidence is ready
   double score = CalculateTFScore(idx);
   
   if(score == 100.0)
   {
      Print("\n[SCORE_100_REACHED]");
      PrintFormat("SYMBOL=%s", sym);
      PrintFormat("H1=%.0f", G_TF[idx].score_h1_trend);
      PrintFormat("M15=%.0f", G_TF[idx].score_m15_pullback);
      PrintFormat("SWEEP=%.0f", G_TF[idx].score_sweep);
      PrintFormat("DISPLACEMENT=%.0f", G_TF[idx].score_displacement);
      PrintFormat("MSS=%.0f", G_TF[idx].score_mss);
      PrintFormat("COHERENCE=%.0f", G_TF[idx].score_event_coherence);
      PrintFormat("MOMENTUM=%.0f", G_TF[idx].score_momentum);
      PrintFormat("ENTRY_DISTANCE=%.0f", G_TF[idx].score_entry_distance);
      PrintFormat("TOTAL=%.0f", score);
      // === FINAL GATE ===
      SetTFState(idx, TF_STATE_ENTRY_READY, "SCORE_100_REACHED");
      
      string rejectReason = "";
      bool hardPass = ValidateTFHardRequirements(idx, dir, rejectReason);
      
      if(hardPass)
      {
         G_TF[idx].status = "TRIGGER";
         LogTFDecision(idx, dir, "ENTRY_READY", "All Gates Passed", score);
         
         Print("\n[TF_FINAL_PASS]");
         PrintFormat("SYMBOL=%s", sym);
         PrintFormat("DIRECTION=%s", (dir == 1 ? "BUY" : "SELL"));
         PrintFormat("SCORE=%.0f", score);
         PrintFormat("DXY=PASS");
         
         int result = dir;
         ResetTFSetup(idx, "Entry Triggered - Reset");
         return result;
      }
      else
      {
         if(StringFind(rejectReason, "DXY_") == 0)
         {
            G_TF[idx].status = "WAIT: " + rejectReason;
            return 0;
         }
         else if(rejectReason == "ENTRY_DISTANCE_TOO_FAR")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx); // Reset M5 only, keep H1+M15
            SetTFState(idx, TF_STATE_M15_PULLBACK, "ENTRY_DISTANCE_REJECT");
            G_TF[idx].status = "M5 RE-ACCUMULATING (distance)";
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
      if(G_TF[idx].score_h1_trend < 20.0) missing += "H1_TREND ";
      if(G_TF[idx].score_m15_pullback < 20.0) missing += "M15_PB ";
      if(!G_TF[idx].m5_sweep) missing += "SWEEP ";
      if(!G_TF[idx].m5_displacement) missing += "DISP ";
      if(!G_TF[idx].m5_mss) missing += "MSS ";
      if(G_TF[idx].score_momentum < 10.0) missing += "MOM ";
      
      G_TF[idx].status = "Score " + IntegerToString((int)score) + "/100 | Missing: " + missing;
   }
   
   return 0;
}
//+------------------------------------------------------------------+
