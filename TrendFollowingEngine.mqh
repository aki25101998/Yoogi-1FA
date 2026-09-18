//+------------------------------------------------------------------+
//|                                        TrendFollowingEngine.mqh  |
//|                                                  Yoogi Trading   |
//|   Trend-Following Entry Engine - 3-Layer Architecture            |
//|   Layer 1: H1 Trend Regime                                       |
//|   Layer 2: M15 Pullback Detection                                |
//|   Layer 3: M5 Entry Trigger                                      |
//+------------------------------------------------------------------+
#property strict

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
   
   ResetTFM5Evidence(idx);
   
   G_TF[idx].total_score = 0.0;
   G_TF[idx].setup_state = TF_STATE_NONE;
   G_TF[idx].setup_bar_count = 0;
   G_TF[idx].status = "NO SETUP";
   
   G_TF[idx].h1_protected_structure = 0.0;
   G_TF[idx].m15_protected_low = 0.0;
   G_TF[idx].m15_protected_high = 0.0;
}

// Reset only M5 evidence (keep H1 + M15 state)
void ResetTFM5Evidence(int idx)
{
   G_TF[idx].m5_sweep = false;
   G_TF[idx].m5_displacement = false;
   G_TF[idx].m5_mss = false;
   G_TF[idx].m5_momentum_cci = false;
   G_TF[idx].m5_momentum_rf = false;
   
   G_TF[idx].m5_sweep_time = 0;
   G_TF[idx].m5_displacement_time = 0;
   G_TF[idx].m5_mss_time = 0;
   G_TF[idx].m5_momentum_time = 0;
   
   G_TF[idx].m5_sweep_price = 0.0;
   G_TF[idx].m5_displacement_price = 0.0;
   
   G_TF[idx].m5_sweep_age = 0;
   G_TF[idx].m5_displacement_age = 0;
   G_TF[idx].m5_mss_age = 0;
   G_TF[idx].m5_mss_break_level = 0.0;
   G_TF[idx].m5_sweep_level = 0.0;
   
   G_TF[idx].score_sweep = 0.0;
   G_TF[idx].score_displacement = 0.0;
   G_TF[idx].score_mss = 0.0;
   G_TF[idx].score_event_coherence = 0.0;
   G_TF[idx].score_momentum = 0.0;
   G_TF[idx].score_entry_distance = 0.0;
}

// ==================================================================
// LAYER 1: H1 TREND REGIME
// ==================================================================

// Evaluate H1 Trend Quality - Returns direction (1=BUY, -1=SELL, 0=NONE)
int EvaluateH1TrendRegime(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES htf = G_Pairs[idx].htf; // H1
   
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
      if(slCount >= 1) G_TF[idx].h1_protected_structure = swL[0];
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
      if(shCount >= 1) G_TF[idx].h1_protected_structure = swH[0];
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
   
   // If we don't have an impulse yet, find a new one
   bool find_new_impulse = (G_TF[idx].m15_impulse_high == 0.0 && G_TF[idx].m15_impulse_low == 0.0);
   
   if(trend_dir == 1) // BUY trend → look for pullback DOWN
   {
      double distance_to_ema = (ema50 - close[0]) / atr;
      G_TF[idx].m15_ema_distance = distance_to_ema;
      
      if(find_new_impulse)
      {
         int best_hl = -1, best_hh = -1, best_ol = -1;
         double best_score = -1.0;
         int candidate_count = 0;
         
         for(int i_hl = right; i_hl < pb_lookback - left; i_hl++)
         {
            if(!IsSwingLow(m15_lows, i_hl, left, right, pb_lookback)) continue;
            
            for(int i_hh = i_hl + 1; i_hh < pb_lookback - left; i_hh++)
            {
               if(!IsSwingHigh(m15_highs, i_hh, left, right, pb_lookback)) continue;
               
               for(int i_ol = i_hh + 1; i_ol < pb_lookback - left; i_ol++)
               {
                  if(!IsSwingLow(m15_lows, i_ol, left, right, pb_lookback)) continue;
                  
                  // Validate structure: Origin Low -> HH -> Protected HL
                  if(m15_lows[i_ol] < m15_highs[i_hh] && 
                     m15_lows[i_hl] < m15_highs[i_hh] && 
                     m15_lows[i_hl] > m15_lows[i_ol])
                  {
                     candidate_count++;
                     
                     double freshness = 1.0 / (i_hl + 1.0);
                     double amplitude = (m15_highs[i_hh] - m15_lows[i_ol]) / atr;
                     double score = (freshness * 50.0) + (amplitude * 10.0);
                     
                     if(score > best_score)
                     {
                        best_score = score;
                        best_hl = i_hl;
                        best_hh = i_hh;
                        best_ol = i_ol;
                     }
                  }
               }
            }
         }
         
         PrintFormat("[M15_IMPULSE_CANDIDATES][%s] BUY candidates=%d", sym, candidate_count);
         
         if(candidate_count > 0 && best_hl != -1 && best_hh != -1 && best_ol != -1)
         {
             datetime t_hl[], t_hh[], t_ol[], t_conf[];
             if(CopyTime(sym, m15, best_hl + 1, 1, t_hl) == 1 && 
                CopyTime(sym, m15, best_hh + 1, 1, t_hh) == 1 && 
                CopyTime(sym, m15, best_ol + 1, 1, t_ol) == 1 &&
                CopyTime(sym, m15, best_hl - right + 1, 1, t_conf) == 1)
             {
                if(t_ol[0] < t_hh[0] && t_hh[0] < t_hl[0])
                {
                   if(G_TF[idx].m15_impulse_high != m15_highs[best_hh] || G_TF[idx].m15_impulse_low != m15_lows[best_ol]) {
                      ResetTFM5Evidence(idx);
                   }
                   G_TF[idx].m15_impulse_high = m15_highs[best_hh];
                   G_TF[idx].m15_impulse_low = m15_lows[best_ol];
                   G_TF[idx].m15_protected_low = m15_lows[best_hl];
                   G_TF[idx].m15_impulse_start_time = t_ol[0];
                   G_TF[idx].m15_impulse_end_time = t_hh[0];
                   G_TF[idx].m15_protected_time = t_hl[0];
                   G_TF[idx].m15_protected_confirmed_time = t_conf[0];
                   G_TF[idx].m15_pullback_start_time = t_hh[0];
                   
                   PrintFormat("[M15_SELECTED_IMPULSE][%s] direction=BUY impulse_high=%.5f impulse_low=%.5f protected_hl=%.5f age_bars=%d impulse_atr=%.2f",
                               sym, m15_highs[best_hh], m15_lows[best_ol], m15_lows[best_hl], best_hl, (m15_highs[best_hh] - m15_lows[best_ol])/atr);
                }
             }
         }
         else
         {
             PrintFormat("[M15_NO_VALID_IMPULSE][%s]", sym);
         }
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
      
      if(find_new_impulse)
      {
         int best_lh = -1, best_ll = -1, best_oh = -1;
         double best_score = -1.0;
         int candidate_count = 0;
         
         for(int i_lh = right; i_lh < pb_lookback - left; i_lh++)
         {
            if(!IsSwingHigh(m15_highs, i_lh, left, right, pb_lookback)) continue;
            
            for(int i_ll = i_lh + 1; i_ll < pb_lookback - left; i_ll++)
            {
               if(!IsSwingLow(m15_lows, i_ll, left, right, pb_lookback)) continue;
               
               for(int i_oh = i_ll + 1; i_oh < pb_lookback - left; i_oh++)
               {
                  if(!IsSwingHigh(m15_highs, i_oh, left, right, pb_lookback)) continue;
                  
                  // Validate structure: Origin High -> LL -> Protected LH
                  if(m15_highs[i_oh] > m15_lows[i_ll] && 
                     m15_highs[i_lh] > m15_lows[i_ll] && 
                     m15_highs[i_lh] < m15_highs[i_oh])
                  {
                     candidate_count++;
                     
                     double freshness = 1.0 / (i_lh + 1.0);
                     double amplitude = (m15_highs[i_oh] - m15_lows[i_ll]) / atr;
                     double score = (freshness * 50.0) + (amplitude * 10.0);
                     
                     if(score > best_score)
                     {
                        best_score = score;
                        best_lh = i_lh;
                        best_ll = i_ll;
                        best_oh = i_oh;
                     }
                  }
               }
            }
         }
         
         PrintFormat("[M15_IMPULSE_CANDIDATES][%s] SELL candidates=%d", sym, candidate_count);
         
         if(candidate_count > 0 && best_lh != -1 && best_ll != -1 && best_oh != -1)
         {
             datetime t_lh[], t_ll[], t_oh[], t_conf[];
             if(CopyTime(sym, m15, best_lh + 1, 1, t_lh) == 1 && 
                CopyTime(sym, m15, best_ll + 1, 1, t_ll) == 1 && 
                CopyTime(sym, m15, best_oh + 1, 1, t_oh) == 1 &&
                CopyTime(sym, m15, best_lh - right + 1, 1, t_conf) == 1)
             {
                if(t_oh[0] < t_ll[0] && t_ll[0] < t_lh[0])
                {
                   if(G_TF[idx].m15_impulse_high != m15_highs[best_oh] || G_TF[idx].m15_impulse_low != m15_lows[best_ll]) {
                      ResetTFM5Evidence(idx);
                   }
                   G_TF[idx].m15_impulse_low = m15_lows[best_ll];
                   G_TF[idx].m15_impulse_high = m15_highs[best_oh];
                   G_TF[idx].m15_protected_high = m15_highs[best_lh];
                   G_TF[idx].m15_impulse_start_time = t_oh[0];
                   G_TF[idx].m15_impulse_end_time = t_ll[0];
                   G_TF[idx].m15_protected_time = t_lh[0];
                   G_TF[idx].m15_protected_confirmed_time = t_conf[0];
                   G_TF[idx].m15_pullback_start_time = t_ll[0];
                   
                   PrintFormat("[M15_SELECTED_IMPULSE][%s] direction=SELL impulse_high=%.5f impulse_low=%.5f protected_lh=%.5f age_bars=%d impulse_atr=%.2f",
                               sym, m15_highs[best_oh], m15_lows[best_ll], m15_highs[best_lh], best_lh, (m15_highs[best_oh] - m15_lows[best_ll])/atr);
                }
             }
         }
         else
         {
             PrintFormat("[M15_NO_VALID_IMPULSE][%s]", sym);
         }
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
      if(bars_since_sweep > TF_MAX_EVENT_BARS) { ResetTFM5Evidence(idx); G_TF[idx].setup_state = TF_STATE_M5_WAIT_SWEEP; return; }
   }
   if(G_TF[idx].m5_displacement && G_TF[idx].m5_displacement_time > 0)
   {
      long bars_since_disp = (current_time - G_TF[idx].m5_displacement_time) / period_sec;
      if(bars_since_disp > TF_MAX_EVENT_BARS) { ResetTFM5Evidence(idx); G_TF[idx].setup_state = TF_STATE_M5_WAIT_SWEEP; return; }
   }
   if(G_TF[idx].m5_mss && G_TF[idx].m5_mss_time > 0)
   {
      long bars_since_mss = (current_time - G_TF[idx].m5_mss_time) / period_sec;
      if(bars_since_mss > TF_MAX_EVENT_BARS) { ResetTFM5Evidence(idx); G_TF[idx].setup_state = TF_STATE_M5_WAIT_SWEEP; return; }
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
      
      double atr = CalculateATR_Generic(sym, m5, InpReversal_ATR_Period, 1);
      
      if(trend_dir == 1) {
         for(int i = right; i < m5_lookback - left; i++) {
            if(IsSwingLow(m5_lows, i, left, right, m5_lookback)) {
               double target = m5_lows[i];
               if(target >= G_TF[idx].m15_protected_low && target <= G_TF[idx].m15_impulse_high) {
                  if(current_time > G_TF[idx].m15_protected_confirmed_time) {
                     // Filter: already consumed by intermediate candles?
                     bool consumed = false;
                     for(int j = 1; j < i; j++) {
                        if(m5_lows[j] < target) { consumed = true; break; }
                     }
                     
                     if(!consumed && DetectLiquiditySweep(sym, m5, trend_dir, target)) {
                        candidate_count++;
                        double freshness = 1.0 / (i + 1.0);
                        double dist = 0;
                        if(atr > 0) dist = MathAbs(target - G_TF[idx].m15_protected_low) / atr;
                        double score = (freshness * 50.0) - (dist * 10.0);
                        
                        if(score > best_score) {
                           best_score = score;
                           best_candidate_idx = i;
                           sweep_target = target;
                        }
                     }
                  }
               }
            }
         }
      } else {
         for(int i = right; i < m5_lookback - left; i++) {
            if(IsSwingHigh(m5_highs, i, left, right, m5_lookback)) {
               double target = m5_highs[i];
               if(target <= G_TF[idx].m15_protected_high && target >= G_TF[idx].m15_impulse_low) {
                  if(current_time > G_TF[idx].m15_protected_confirmed_time) {
                     // Filter: already consumed by intermediate candles?
                     bool consumed = false;
                     for(int j = 1; j < i; j++) {
                        if(m5_highs[j] > target) { consumed = true; break; }
                     }
                     
                     if(!consumed && DetectLiquiditySweep(sym, m5, trend_dir, target)) {
                        candidate_count++;
                        double freshness = 1.0 / (i + 1.0);
                        double dist = 0;
                        if(atr > 0) dist = MathAbs(target - G_TF[idx].m15_protected_high) / atr;
                        double score = (freshness * 50.0) - (dist * 10.0);
                        
                        if(score > best_score) {
                           best_score = score;
                           best_candidate_idx = i;
                           sweep_target = target;
                        }
                     }
                  }
               }
            }
         }
      }
      
      PrintFormat("[M5_SWEEP_CANDIDATES][%s] direction=%d candidates=%d", sym, trend_dir, candidate_count);
      
      if(best_candidate_idx != -1)
      {
         G_TF[idx].m5_sweep = true;
         G_TF[idx].m5_sweep_time = current_time;
         G_TF[idx].m5_sweep_price = sweep_target;
         G_TF[idx].m5_sweep_level = sweep_target;
         G_TF[idx].score_sweep = 10.0;
         G_TF[idx].setup_state = TF_STATE_M5_WAIT_DISPLACEMENT;
         G_TF[idx].status = "WAIT DISPLACEMENT";
         
         double dist_val = 0;
         if(atr > 0) dist_val = MathAbs(sweep_target - (trend_dir == 1 ? G_TF[idx].m15_protected_low : G_TF[idx].m15_protected_high)) / atr;
         
         PrintFormat("[M5_SELECTED_SWEEP][%s] direction=%d swing_price=%.5f age_bars=%d distance=%.2f", 
                     sym, trend_dir, sweep_target, best_candidate_idx, dist_val);
      }
      else
      {
         PrintFormat("[M5_NO_VALID_SWEEP][%s] direction=%d", sym, trend_dir);
      }
      return; // Wait for next candle for next event
   }
   
   if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_DISPLACEMENT)
   {
      if(current_time > G_TF[idx].m5_sweep_time)
      {
         if(DetectDisplacement(sym, m5, trend_dir))
         {
            double close[]; CopyClose(sym, m5, 1, 1, close);
            G_TF[idx].m5_displacement = true;
            G_TF[idx].m5_displacement_time = current_time;
            G_TF[idx].m5_displacement_price = close[0];
            G_TF[idx].score_displacement = 10.0;
            G_TF[idx].setup_state = TF_STATE_M5_WAIT_MSS;
            G_TF[idx].status = "WAIT MSS";
            PrintFormat("[TREND-FOLLOWING][%s] M5 Displacement Confirmed (dir=%d)", sym, trend_dir);
         }
      }
      return; // Wait for next candle for next event
   }
   
   if(G_TF[idx].setup_state == TF_STATE_M5_WAIT_MSS)
   {
      if(current_time > G_TF[idx].m5_displacement_time)
      {
         double breakLvl = 0.0;
         string mssReason = "";
         if(DetectStructureShift(idx, sym, m5, trend_dir, breakLvl, mssReason))
         {
            G_TF[idx].m5_mss = true;
            G_TF[idx].m5_mss_time = current_time;
            G_TF[idx].m5_mss_break_level = breakLvl;
            G_TF[idx].score_mss = 10.0;
            G_TF[idx].setup_state = TF_STATE_ENTRY_READY; // Forward to entry validation
            G_TF[idx].status = "MSS CONFIRMED";
            PrintFormat("[TREND-FOLLOWING][%s] M5 MSS Confirmed (dir=%d, level=%.5f)", sym, trend_dir, breakLvl);
            
            // Capture Momentum at MSS time
            int cci_status = 0, rf_status = 0;
            CheckMomentumStatus(idx, cci_status, rf_status);
            G_TF[idx].m5_momentum_cci = (cci_status == trend_dir);
            G_TF[idx].m5_momentum_rf = (rf_status == trend_dir);
            G_TF[idx].m5_momentum_time = current_time;
            double mom = 0.0;
            if(G_TF[idx].m5_momentum_cci) mom += 5.0;
            if(G_TF[idx].m5_momentum_rf)  mom += 5.0;
            G_TF[idx].score_momentum = MathMin(mom, 10.0);
         }
      }
      return;
   }
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
      
   // Strict chronological order
   if(G_TF[idx].m5_sweep_time >= G_TF[idx].m5_displacement_time) return false;
   if(G_TF[idx].m5_displacement_time >= G_TF[idx].m5_mss_time) return false;
   if(G_TF[idx].m15_protected_confirmed_time >= G_TF[idx].m5_sweep_time) return false;
   
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

bool CheckTFEntryDistance(int idx, int direction)
{
   if(G_TF[idx].m5_mss_break_level <= 0.0) return false; // MUST NOT BE SKIPPED
   
   string sym = G_Pairs[idx].symbol;
   double atr = CalculateATR_Generic(sym, PERIOD_M5, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false; // Fail-closed
   
   double close[];
   if(CopyClose(sym, PERIOD_M5, 1, 1, close) < 1) return false; // Fail-closed
   
   double distance = 0.0;
   if(direction == 1)
   {
      if(close[0] < G_TF[idx].m5_mss_break_level) return false;
      distance = close[0] - G_TF[idx].m5_mss_break_level;
   }
   else
   {
      if(close[0] > G_TF[idx].m5_mss_break_level) return false;
      distance = G_TF[idx].m5_mss_break_level - close[0];
   }
   
   if(distance > TF_MAX_ENTRY_DISTANCE_ATR * atr) return false;
   
   G_TF[idx].score_entry_distance = 10.0;
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
   // 1. H1 Trend must be valid with sufficient quality
   if(G_TF[idx].h1_trend_direction != direction || G_TF[idx].h1_trend_quality < 20.0)
   {
      rejectReason = "H1_TREND_NOT_STRONG";
      return false;
   }
   
   // 2. M15 Pullback must be valid
   if(!G_TF[idx].m15_pullback_valid || G_TF[idx].m15_pullback_quality < 20.0)
   {
      if (G_TF[idx].m15_impulse_high == 0.0 && G_TF[idx].m15_impulse_low == 0.0)
         rejectReason = "M15_IMPULSE_NOT_FOUND";
      else
         rejectReason = "M15_PULLBACK_INVALID";
      return false;
   }
   
   // 3. M5 Sweep
   if(!G_TF[idx].m5_sweep)
   {
      rejectReason = "M5_SWEEP_NOT_FOUND";
      return false;
   }
   
   // 4. M5 Displacement
   if(!G_TF[idx].m5_displacement)
   {
      rejectReason = "M5_DISPLACEMENT_NOT_AFTER_SWEEP";
      return false;
   }
   
   // 5. M5 MSS
   if(!G_TF[idx].m5_mss)
   {
      rejectReason = "M5_MSS_NOT_AFTER_DISPLACEMENT";
      return false;
   }
   
   // 6. Event Coherence
   if(!CheckTFEventCoherence(idx))
   {
      if(G_TF[idx].m15_protected_confirmed_time >= G_TF[idx].m5_sweep_time)
         rejectReason = "M5_SWEEP_BEFORE_PROTECTED_CONFIRMATION";
      else if(G_TF[idx].m5_sweep_time >= G_TF[idx].m5_displacement_time || G_TF[idx].m5_displacement_time >= G_TF[idx].m5_mss_time)
         rejectReason = "M5_EVENT_SEQUENCE_INVALID";
      else {
         long period_sec = PeriodSeconds(PERIOD_M5);
         long total_sequence_bars = (G_TF[idx].m5_mss_time - G_TF[idx].m5_sweep_time) / period_sec;
         if(total_sequence_bars > TF_MAX_EVENT_BARS) rejectReason = "M5_EVENT_STALE";
         else rejectReason = "M5_EVENT_OUTSIDE_M15_SETUP";
      }
      return false;
   }
   
   // 7. Entry Distance and Break Level Check
   if(G_TF[idx].m5_mss_break_level <= 0.0)
   {
      rejectReason = "MSS_BREAK_LEVEL_INVALID";
      return false;
   }
   
   if(!CheckTFEntryDistance(idx, direction))
   {
      rejectReason = "ENTRY_DISTANCE_TOO_FAR";
      return false;
   }
   
   // 8. Momentum check
   if(!G_TF[idx].m5_momentum_cci || !G_TF[idx].m5_momentum_rf)
   {
      rejectReason = "MOMENTUM_INCOMPLETE";
      return false;
   }
   
   // 9. Score == 100
   // 9. Score exactly == 100
   double score = CalculateTFScore(idx);
   if(score != 100.0)
   {
      rejectReason = (score > 100.0) ? "SCORE_OVER_100_LEAKAGE" : "SCORE_BELOW_100";
      return false;
   }
   
   // 9. DXY Confirmation (if applicable)
   if(G_Pairs[idx].isUSDPair && g_dxy_available && InpUseDXYReference)
   {
      int di = G_Pairs[idx].dxy_map_index;
      if(di >= 0)
      {
         int dxyTrapHTF = G_DXY_TrapSignal_HTF[di];
         int dxyTrapLTF = G_DXY_TrapSignal_LTF[di];
         
         if(dxyTrapHTF == 0 || dxyTrapLTF == 0)
         {
            rejectReason = "DXY_NOT_READY";
            return false;
         }
         if(dxyTrapHTF != dxyTrapLTF)
         {
            rejectReason = "DXY_CONFLICT_INTERNAL";
            return false;
         }
         
         int dxySignal = dxyTrapHTF;
         bool converges = false;
         
         if(G_Pairs[idx].isUSDSecond) // EURUSD, AUDUSD -> nguoc chieu
         {
            converges = (direction != dxySignal);
         }
         else if(G_Pairs[idx].isUSDFirst) // USDCAD, USDCHF -> cung chieu
         {
            converges = (direction == dxySignal);
         }
         
         if(!converges)
         {
            rejectReason = "DXY_CONFLICT";
            return false;
         }
      }
   }
   
   rejectReason = "";
   return true;
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
            int new_dir = EvaluateH1TrendRegime(idx);
            
            if(new_dir != 0)
            {
               if(G_TF[idx].setup_state == TF_STATE_NONE)
               {
                  G_TF[idx].h1_trend_direction = new_dir;
                  G_TF[idx].setup_state = TF_STATE_H1_TREND;
                  G_TF[idx].setup_bar_count = 0;
                  G_TF[idx].status = "H1 TREND";
                  LogTFDecision(idx, new_dir, "H1_TREND", "Trend detected", 0);
               }
               else if(prev_dir != 0 && prev_dir != new_dir)
               {
                  // H1 trend changed direction → full reset old, init new immediately
                  ResetTFSetup(idx, "H1_SETUP_INVALIDATED");
                  EvaluateH1TrendRegime(idx); // Re-evaluate to set new state
                  G_TF[idx].h1_trend_direction = new_dir;
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
      
      // Check M15 pullback invalidation
      if(G_TF[idx].setup_state >= TF_STATE_M15_PULLBACK && CheckM15PullbackInvalidation(idx))
      {
         // Pullback became reversal → reset M15 + M5 but keep H1
         G_TF[idx].m15_pullback_valid = false;
         G_TF[idx].m15_pullback_quality = 0.0;
         G_TF[idx].m15_pullback_bar_count = 0;
         G_TF[idx].score_m15_pullback = 0.0;
         G_TF[idx].m15_pullback_start_time = 0;
         G_TF[idx].m15_impulse_high = 0.0;
         G_TF[idx].m15_impulse_low = 0.0;
         G_TF[idx].m15_impulse_start_time = 0;
         G_TF[idx].m15_impulse_end_time = 0;
         G_TF[idx].m15_protected_time = 0;
         ResetTFM5Evidence(idx);
         G_TF[idx].setup_state = TF_STATE_H1_TREND;
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
      
      // Evaluate pullback
      if(G_TF[idx].setup_state == TF_STATE_H1_TREND || 
         (G_TF[idx].setup_state == TF_STATE_M15_PULLBACK && !G_TF[idx].m15_pullback_valid))
      {
         if(EvaluateM15Pullback(idx, dir))
         {
            G_TF[idx].setup_state = TF_STATE_M15_PULLBACK;
            G_TF[idx].status = "M15 PULLBACK";
            LogTFDecision(idx, dir, "M15_PULLBACK", "Pullback detected", 0);
         }
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
      // Reset M15 and M5 but keep H1
      G_TF[idx].m15_pullback_valid = false;
      G_TF[idx].m15_pullback_quality = 0.0;
      G_TF[idx].m15_pullback_bar_count = 0;
      G_TF[idx].score_m15_pullback = 0.0;
      G_TF[idx].m15_pullback_start_time = 0;
      G_TF[idx].m15_impulse_high = 0.0;
      G_TF[idx].m15_impulse_low = 0.0;
      G_TF[idx].m15_impulse_start_time = 0;
      G_TF[idx].m15_impulse_end_time = 0;
      G_TF[idx].m15_protected_time = 0;
      ResetTFM5Evidence(idx);
      
      G_TF[idx].setup_state = TF_STATE_H1_TREND;
      G_TF[idx].status = "M15 TIMEOUT RESTART";
      G_TF[idx].setup_bar_count = 0;
      PrintFormat("[TREND-FOLLOWING][%s] SETUP TIMEOUT -> Reset to H1", sym);
      return 0;
   }
   
   // Evaluate M5 evidence
   if(G_TF[idx].setup_state == TF_STATE_M15_PULLBACK)
   {
      G_TF[idx].setup_state = TF_STATE_M5_WAIT_SWEEP;
      G_TF[idx].status = "WAIT SWEEP";
   }
   EvaluateM5Trigger(idx, dir);
   
   // Check if all evidence is ready
   double score = CalculateTFScore(idx);
   
   if(score == 100.0)
   {
      // === FINAL GATE ===
      G_TF[idx].setup_state = TF_STATE_ENTRY_READY;
      
      string rejectReason = "";
      bool hardPass = ValidateTFHardRequirements(idx, dir, rejectReason);
      
      if(hardPass)
      {
         G_TF[idx].status = "TRIGGER";
         LogTFDecision(idx, dir, "ENTRY_READY", "All Gates Passed", score);
         
         int result = dir;
         ResetTFSetup(idx, "Entry Triggered - Reset");
         return result;
      }
      else
      {
         if(rejectReason == "DXY_CONFLICT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFSetup(idx, rejectReason);
            return 0;
         }
         else if(rejectReason == "DXY_NOT_READY")
         {
            G_TF[idx].status = "WAIT_DXY";
         }
         else if(rejectReason == "ENTRY_DISTANCE_TOO_FAR")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx); // Reset M5 only, keep H1+M15
            G_TF[idx].setup_state = TF_STATE_M15_PULLBACK;
            G_TF[idx].status = "M5 RE-ACCUMULATING (distance)";
            return 0;
         }
         else if(rejectReason == "EVENT_NOT_COHERENT")
         {
            LogTFDecision(idx, dir, "REJECT", rejectReason, score);
            ResetTFM5Evidence(idx); // Reset M5 only
            G_TF[idx].setup_state = TF_STATE_M15_PULLBACK;
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
