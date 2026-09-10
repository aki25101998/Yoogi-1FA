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
   
   if(isUptrend) return REGIME_TREND_BULL;
   if(isDowntrend) return REGIME_TREND_BEAR;
   
   return REGIME_SIDEWAY;
}

// --- 6. SCORING ENGINE ---
double CalculateReversalScore(int idx, int direction)
{
   double score = 0.0;
   
   if(G_Pairs[idx].ltf_divergence) score += InpScore_Divergence;
   if(G_Pairs[idx].ltf_mss) score += InpScore_Structure;
   
   double ext = CalculateExtension(G_Pairs[idx].symbol, G_Pairs[idx].htf);
   if(ext >= InpReversal_Extension_Extreme) score += InpScore_Extension;
   else if(ext >= InpReversal_Extension_Strong) score += InpScore_Extension * 0.75;
   else if(ext >= InpReversal_Extension_Normal) score += InpScore_Extension * 0.5;
   
   if(DetectExhaustion(G_Pairs[idx].symbol, G_Pairs[idx].htf, direction)) score += InpScore_Exhaustion;
   
   if(G_Pairs[idx].htf_reversal_zone) score += InpScore_HTF;
   
   return score;
}

// --- 7. CORE REVERSAL SIGNAL LOGIC ---
int CheckReversalSignal(int idx)
{
   if(!InpUseReversalEngine) return 0;
   
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES htf = G_Pairs[idx].htf;
   ENUM_TIMEFRAMES ltf = G_Pairs[idx].ltf;
   
   // 1. HTF REVERSAL ZONE PERMISSION
   if(IsNewBar_HTF(idx))
   {
      G_Pairs[idx].regime = DetectMarketRegime(sym, htf);
      double htf_ext = CalculateExtension(sym, htf);
      
      bool htf_bull_div = DetectDivergence(sym, htf, 1);
      bool htf_bear_div = DetectDivergence(sym, htf, -1);
      bool htf_bull_exh = DetectExhaustion(sym, htf, 1);
      bool htf_bear_exh = DetectExhaustion(sym, htf, -1);
      
      G_Pairs[idx].htf_reversal_zone = false;
      
      // Allow searching for BUY if strongly extended down, or diverging/exhausting down
      if(G_Pairs[idx].regime == REGIME_TREND_BEAR || G_Pairs[idx].regime == REGIME_SIDEWAY)
      {
         if(htf_ext >= InpReversal_Extension_Normal || htf_bull_div || htf_bull_exh)
         {
            G_Pairs[idx].htf_reversal_zone = true;
            if(G_Pairs[idx].htf_trap_signal != 1) 
               PrintFormat("[REVERSAL] %s HTF Zone = POTENTIAL BUY (Ext: %.2f)", sym, htf_ext);
            G_Pairs[idx].htf_trap_signal = 1;
         }
      }
      
      // Allow searching for SELL if strongly extended up, or diverging/exhausting up
      if(G_Pairs[idx].regime == REGIME_TREND_BULL || G_Pairs[idx].regime == REGIME_SIDEWAY)
      {
         if(htf_ext >= InpReversal_Extension_Normal || htf_bear_div || htf_bear_exh)
         {
            G_Pairs[idx].htf_reversal_zone = true;
            if(G_Pairs[idx].htf_trap_signal != -1)
               PrintFormat("[REVERSAL] %s HTF Zone = POTENTIAL SELL (Ext: %.2f)", sym, htf_ext);
            G_Pairs[idx].htf_trap_signal = -1;
         }
      }
   }
   
   // 2. LTF TRIGGER LOGIC
   if(G_Pairs[idx].htf_trap_signal != 0 && IsNewBar_Multi(idx))
   {
      int dir = G_Pairs[idx].htf_trap_signal;
      
      G_Pairs[idx].ltf_divergence = DetectDivergence(sym, ltf, dir);
      G_Pairs[idx].ltf_mss = DetectStructureShift(sym, ltf, dir);
      
      // Evaluate base signal logic (CCI recovery + Filter confirmation)
      int baseSignal = CheckEntrySignal(idx); // Call original function to get CCI/Range Filter confirmation
      
      double score = CalculateReversalScore(idx, dir);
      G_Pairs[idx].reversal_score = score;
      
      // Logging
      if(baseSignal == dir || G_Pairs[idx].ltf_divergence || G_Pairs[idx].ltf_mss)
      {
         PrintFormat("[REVERSAL] %s %s | Div: %s | MSS: %s | Score: %.0f/100", 
                     sym, (dir == 1 ? "BUY" : "SELL"), 
                     (G_Pairs[idx].ltf_divergence ? "YES" : "NO"),
                     (G_Pairs[idx].ltf_mss ? "YES" : "NO"),
                     score);
      }
      
      // Hard Constraints
      if(score < InpReversal_MinScore) return 0;
      if(InpReversal_RequireStructureShift && !G_Pairs[idx].ltf_mss) return 0;
      
      // If we have LTF signal + sufficient score -> Return Final Trigger
      if(baseSignal == dir)
      {
         PrintFormat("[REVERSAL TRIGGER] %s %s APPROVED. Score: %.0f >= %.0f", sym, (dir == 1 ? "BUY" : "SELL"), score, InpReversal_MinScore);
         return dir;
      }
   }
   
   return 0;
}
