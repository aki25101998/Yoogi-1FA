//+------------------------------------------------------------------+
//|                                              ReversalEngine.mqh  |
//|                                                Yoogi Trading     |
//|   Reversal Quality Engine v1 - MTF + Scoring                     |
//+------------------------------------------------------------------+
#property strict

// --- 1. EXTENSION DETECTION ---
double CalculateExtension(string sym, ENUM_TIMEFRAMES tf)
{
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return 0.0;
   double ema = CalculateEMA_Generic(sym, tf, InpReversal_EquilibriumPeriod, 1);
   double close[];
   if(CopyClose(sym, tf, 1, 1, close) < 1) return 0.0;
   
   return MathAbs(close[0] - ema) / atr;
}

// --- 2. EXHAUSTION DETECTION ---
bool DetectExhaustion(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double open[], high[], low[], close[];
   if(CopyOpen(sym, tf, 1, 2, open) < 2) return false;
   if(CopyHigh(sym, tf, 1, 2, high) < 2) return false;
   if(CopyLow(sym, tf, 1, 2, low) < 2) return false;
   if(CopyClose(sym, tf, 1, 2, close) < 2) return false;
   
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   double body0 = MathAbs(close[0] - open[0]);
   double range0 = high[0] - low[0];
   
   if(direction == 1) // Bullish Exhaustion (Bearish Trend weakening)
   {
      double lowerWick = MathMin(open[0], close[0]) - low[0];
      // 1. Large rejection wick
      if(lowerWick > atr * 0.8 && lowerWick > body0 * 1.5) return true;
      // 2. Failed continuation (bearish attempt failed)
      if(low[0] < low[1] && close[0] > low[1] && close[0] > close[1]) return true;
   }
   else if(direction == -1) // Bearish Exhaustion (Bullish Trend weakening)
   {
      double upperWick = high[0] - MathMax(open[0], close[0]);
      // 1. Large rejection wick
      if(upperWick > atr * 0.8 && upperWick > body0 * 1.5) return true;
      // 2. Failed continuation (bullish attempt failed)
      if(high[0] > high[1] && close[0] < high[1] && close[0] < close[1]) return true;
   }
   
   return false;
}

// --- 3. SWING & DIVERGENCE DETECTION ---
bool DetectDivergence(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   int lookback = InpReversal_LookbackBars;
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   double highs[], lows[];
   if(!ReadHighLow_Generic(sym, tf, 1, lookback, highs, lows)) return false;
   
   int handle_cci = iCCI(sym, tf, CCI_LEN, PRICE_CLOSE);
   if(handle_cci == INVALID_HANDLE) return false;
   
   double cci[];
   if(CopyBuffer(handle_cci, 0, 1, lookback, cci) < lookback) { IndicatorRelease(handle_cci); return false; }
   ArraySetAsSeries(cci, true);
   IndicatorRelease(handle_cci);
   
   // Find latest confirmed swing
   int swing1 = -1;
   int swing2 = -1;
   
   for(int i = right; i < lookback - left; i++)
   {
      bool isSwing = true;
      if(direction == 1) // Bullish Divergence -> Need Swing Lows
      {
         for(int j = 1; j <= left; j++) if(lows[i] >= lows[i+j]) { isSwing = false; break; }
         if(!isSwing) continue;
         for(int j = 1; j <= right; j++) if(lows[i] > lows[i-j]) { isSwing = false; break; }
      }
      else // Bearish Divergence -> Need Swing Highs
      {
         for(int j = 1; j <= left; j++) if(highs[i] <= highs[i+j]) { isSwing = false; break; }
         if(!isSwing) continue;
         for(int j = 1; j <= right; j++) if(highs[i] < highs[i-j]) { isSwing = false; break; }
      }
      
      if(isSwing)
      {
         if(swing1 == -1) swing1 = i;
         else if(swing2 == -1) { swing2 = i; break; }
      }
   }
   
   if(swing1 != -1 && swing2 != -1)
   {
      if(direction == 1) // Bullish Divergence (Price LL, CCI HL)
      {
         if(lows[swing1] < lows[swing2] && cci[swing1] > cci[swing2]) return true;
      }
      else // Bearish Divergence (Price HH, CCI LH)
      {
         if(highs[swing1] > highs[swing2] && cci[swing1] < cci[swing2]) return true;
      }
   }
   
   return false;
}

// --- 4. STRUCTURE SHIFT ---
bool DetectStructureShift(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   if(!InpReversal_RequireStructureShift) return true; // Bypass if disabled
   
   int lookback = InpReversal_LookbackBars;
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   double highs[], lows[], close[];
   if(!ReadHighLow_Generic(sym, tf, 1, lookback, highs, lows)) return false;
   if(CopyClose(sym, tf, 1, 1, close) < 1) return false;
   
   // Find latest opposing swing
   int swing = -1;
   for(int i = right; i < lookback - left; i++)
   {
      bool isSwing = true;
      if(direction == 1) // Bullish MSS -> Break of recent swing HIGH
      {
         for(int j = 1; j <= left; j++) if(highs[i] <= highs[i+j]) { isSwing = false; break; }
         if(!isSwing) continue;
         for(int j = 1; j <= right; j++) if(highs[i] < highs[i-j]) { isSwing = false; break; }
      }
      else // Bearish MSS -> Break of recent swing LOW
      {
         for(int j = 1; j <= left; j++) if(lows[i] >= lows[i+j]) { isSwing = false; break; }
         if(!isSwing) continue;
         for(int j = 1; j <= right; j++) if(lows[i] > lows[i-j]) { isSwing = false; break; }
      }
      
      if(isSwing)
      {
         swing = i;
         break;
      }
   }
   
   if(swing != -1)
   {
      if(direction == 1) // Bullish MSS
      {
         if(close[0] > highs[swing]) return true;
      }
      else // Bearish MSS
      {
         if(close[0] < lows[swing]) return true;
      }
   }
   
   return false;
}

// --- 5. REGIME DETECTION ---
ENUM_MARKET_REGIME DetectMarketRegime(string sym, ENUM_TIMEFRAMES tf)
{
   double ema_fast = CalculateEMA_Generic(sym, tf, 20, 1);
   double ema_slow = CalculateEMA_Generic(sym, tf, 50, 1);
   
   double close[];
   if(CopyClose(sym, tf, 1, 1, close) < 1) return REGIME_UNKNOWN;
   
   bool isUptrend = (close[0] > ema_fast && ema_fast > ema_slow);
   bool isDowntrend = (close[0] < ema_fast && ema_fast < ema_slow);
   
   if(isUptrend)
   {
       if(DetectExhaustion(sym, tf, -1) || DetectDivergence(sym, tf, -1)) return REGIME_EXHAUSTION;
       return REGIME_TREND_BULL;
   }
   if(isDowntrend)
   {
       if(DetectExhaustion(sym, tf, 1) || DetectDivergence(sym, tf, 1)) return REGIME_EXHAUSTION;
       return REGIME_TREND_BEAR;
   }
   
   return REGIME_SIDEWAY;
}

// --- 6. SCORING ENGINE ---
double CalculateReversalScore(int idx, int direction)
{
   double score = 0.0;
   
   if(G_Pairs[idx].ltf_divergence) score += InpScore_Divergence;
   if(G_Pairs[idx].ltf_mss) score += InpScore_Structure;
   
   double ext = G_Pairs[idx].htf_ext;
   if(ext >= InpReversal_Extension_Extreme) score += InpScore_Extension;
   else if(ext >= InpReversal_Extension_Strong) score += InpScore_Extension * 0.75;
   else if(ext >= InpReversal_Extension_Normal) score += InpScore_Extension * 0.5;
   
   if(G_Pairs[idx].ltf_exh) score += InpScore_Exhaustion;
   
   if(G_Pairs[idx].htf_reversal_zone) score += InpScore_HTF;
   
   return score;
}

void LogReversalDecision(int idx, int direction, string decision, string reason, double score)
{
    string sym = G_Pairs[idx].symbol;
    string dir_str = (direction == 1) ? "BUY" : "SELL";
    string regime_str = EnumToString(G_Pairs[idx].regime);
    
    string cci_str = (G_Pairs[idx].ltf_cci_recov == direction) ? "RECOVERY" : "WAIT";
    string rf_str = (G_Pairs[idx].ltf_rf_state == 1) ? "BULL" : ((G_Pairs[idx].ltf_rf_state == -1) ? "BEAR" : "WAIT");
    
    string dxy_str = "N/A";
    if(G_Pairs[idx].isUSDPair && g_dxy_available && InpUseDXYReference)
    {
        dxy_str = (decision == "ENTRY") ? "CONFIRMED" : "WAITING";
    }

    if(decision == "REJECT")
    {
        PrintFormat("[REVERSAL] %s %s Decision = REJECT Reason = %s", sym, dir_str, reason);
    }
    else
    {
        PrintFormat("[REVERSAL] Symbol: %s Direction: %s HTF Regime: %s HTF Extension: %.2f ATR HTF Divergence: %s HTF Exhaustion: %s LTF Divergence: %s LTF Structure Shift: %s LTF Exhaustion: %s LTF CCI: %s LTF Range Filter: %s DXY: %s Score: %.0f Final Decision: %s",
                    sym, dir_str, regime_str, G_Pairs[idx].htf_ext,
                    (G_Pairs[idx].htf_div ? "TRUE" : "FALSE"),
                    (G_Pairs[idx].htf_exh ? "TRUE" : "FALSE"),
                    (G_Pairs[idx].ltf_divergence ? "TRUE" : "FALSE"),
                    (G_Pairs[idx].ltf_mss ? "TRUE" : "FALSE"),
                    (G_Pairs[idx].ltf_exh ? "TRUE" : "FALSE"),
                    cci_str, rf_str, dxy_str, score, decision);
    }
}

// --- 7. CORE REVERSAL SIGNAL LOGIC ---
int CheckReversalSignal(int idx)
{
   if(!InpUseReversalEngine) return 0;
   
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES htf = G_Pairs[idx].htf;
   ENUM_TIMEFRAMES ltf = G_Pairs[idx].ltf;
   
   // --- HTF PROCESSING ---
   if(IsNewBar_HTF(idx))
   {
      G_Pairs[idx].regime = DetectMarketRegime(sym, htf);
      G_Pairs[idx].htf_ext = CalculateExtension(sym, htf);
      
      bool htf_bull_div = DetectDivergence(sym, htf, 1);
      bool htf_bear_div = DetectDivergence(sym, htf, -1);
      bool htf_bull_exh = DetectExhaustion(sym, htf, 1);
      bool htf_bear_exh = DetectExhaustion(sym, htf, -1);
      
      G_Pairs[idx].htf_reversal_zone = false;
      
      if(G_Pairs[idx].regime == REGIME_TREND_BEAR || G_Pairs[idx].regime == REGIME_SIDEWAY || G_Pairs[idx].regime == REGIME_EXHAUSTION)
      {
         if(G_Pairs[idx].htf_ext >= InpReversal_Extension_Normal || htf_bull_div || htf_bull_exh)
         {
            G_Pairs[idx].htf_reversal_zone = true;
            G_Pairs[idx].htf_div = htf_bull_div;
            G_Pairs[idx].htf_exh = htf_bull_exh;
            G_Pairs[idx].htf_trap_signal = 1; // Potential BUY
            
            if(G_Pairs[idx].state_machine == 0) 
            {
               G_Pairs[idx].state_machine = 1;
               G_Pairs[idx].rev_status = "ZONE";
            }
         }
      }
      
      if(G_Pairs[idx].regime == REGIME_TREND_BULL || G_Pairs[idx].regime == REGIME_SIDEWAY || G_Pairs[idx].regime == REGIME_EXHAUSTION)
      {
         if(G_Pairs[idx].htf_ext >= InpReversal_Extension_Normal || htf_bear_div || htf_bear_exh)
         {
            G_Pairs[idx].htf_reversal_zone = true;
            G_Pairs[idx].htf_div = htf_bear_div;
            G_Pairs[idx].htf_exh = htf_bear_exh;
            G_Pairs[idx].htf_trap_signal = -1; // Potential SELL
            
            if(G_Pairs[idx].state_machine == 0) 
            {
               G_Pairs[idx].state_machine = 1;
               G_Pairs[idx].rev_status = "ZONE";
            }
         }
      }
      
      // Reset if zone is lost
      if(!G_Pairs[idx].htf_reversal_zone)
      {
         G_Pairs[idx].state_machine = 0;
         G_Pairs[idx].htf_trap_signal = 0;
         G_Pairs[idx].rev_status = "NO SETUP";
      }
   }
   
   // --- LTF PROCESSING & STATE MACHINE ---
   if(G_Pairs[idx].htf_trap_signal != 0 && IsNewBar_Multi(idx))
   {
      int dir = G_Pairs[idx].htf_trap_signal;
      
      // Update LTF Evidence
      G_Pairs[idx].ltf_divergence = DetectDivergence(sym, ltf, dir);
      G_Pairs[idx].ltf_mss = DetectStructureShift(sym, ltf, dir);
      G_Pairs[idx].ltf_exh = DetectExhaustion(sym, ltf, dir);
      
      // Check base signal for CCI recovery + Range Filter
      int baseSignal = CheckEntrySignal(idx); 
      if(baseSignal != 0)
      {
          G_Pairs[idx].ltf_cci_recov = baseSignal;
          G_Pairs[idx].ltf_rf_state = baseSignal;
      }
      
      double score = CalculateReversalScore(idx, dir);
      G_Pairs[idx].reversal_score = score;
      
      // Hard No-Trade Rules
      bool reject = false;
      string reject_reason = "";
      
      if(dir == 1 && G_Pairs[idx].regime == REGIME_TREND_BEAR && !G_Pairs[idx].ltf_divergence && G_Pairs[idx].htf_ext < InpReversal_Extension_Strong && !G_Pairs[idx].ltf_mss)
      {
          reject = true;
          reject_reason = "Strong Bear Trend + No Div + No Ext + No MSS";
      }
      if(dir == -1 && G_Pairs[idx].regime == REGIME_TREND_BULL && !G_Pairs[idx].ltf_divergence && G_Pairs[idx].htf_ext < InpReversal_Extension_Strong && !G_Pairs[idx].ltf_mss)
      {
          reject = true;
          reject_reason = "Strong Bull Trend + No Div + No Ext + No MSS";
      }
      
      if(reject)
      {
          LogReversalDecision(idx, dir, "REJECT", reject_reason, score);
          G_Pairs[idx].state_machine = 0;
          G_Pairs[idx].htf_trap_signal = 0;
          G_Pairs[idx].rev_status = "REJECTED";
          return 0;
      }

      // STATE MACHINE PROGRESSION
      if(G_Pairs[idx].state_machine == 1) // HTF Zone -> Watch for LTF Div/Exh
      {
          if(G_Pairs[idx].ltf_divergence || G_Pairs[idx].ltf_exh) 
          {
              G_Pairs[idx].state_machine = 2;
              G_Pairs[idx].rev_status = "WATCH";
          }
      }
      
      if(G_Pairs[idx].state_machine == 2) // Watch -> Structure Shift
      {
          if(G_Pairs[idx].ltf_mss || !InpReversal_RequireStructureShift) 
          {
              G_Pairs[idx].state_machine = 3;
              G_Pairs[idx].rev_status = "MSS";
          }
      }
      
      if(G_Pairs[idx].state_machine >= 1) // Can jump to state 4 if baseSignal hits and MSS is true
      {
          if(baseSignal == dir) 
          {
              if(InpReversal_RequireStructureShift && !G_Pairs[idx].ltf_mss) 
              {
                  LogReversalDecision(idx, dir, "REJECT", "Structure Shift Missing", score);
                  G_Pairs[idx].rev_status = "WAIT MSS";
                  return 0;
              }
              
              if(score < InpReversal_MinScore)
              {
                  LogReversalDecision(idx, dir, "REJECT", "Score too low: " + DoubleToString(score, 0), score);
                  G_Pairs[idx].rev_status = "LOW SCORE";
                  return 0; 
              }
              
              G_Pairs[idx].state_machine = 4; // CONFIRMATION
              G_Pairs[idx].rev_status = "TRIGGER";
              
              LogReversalDecision(idx, dir, "ENTRY", "", score);
              return dir;
          }
      }
   }
   
   return 0;
}
