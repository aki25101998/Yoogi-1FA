//+------------------------------------------------------------------+
//|                                              ReversalEngine.mqh  |
//|                                                Yoogi Trading     |
//|   Reversal Quality Engine V2 - 4-Layer Architecture              |
//|   Layer A: Location | Layer B: Exhaustion                        |
//|   Layer C: Reversal Confirmation | Layer D: External             |
//+------------------------------------------------------------------+
#property strict

// ==================================================================
// HELPER: Reset toàn bộ Reversal Setup về trạng thái ban đầu
// ==================================================================
void ResetReversalSetup(int idx, string reason)
{
   if(InpReversalDebug && G_Pairs[idx].state_machine != STATE_NO_SETUP)
   {
      PrintFormat("[REVERSAL][%s] RESET | Prev State=%d | Dir=%d | Reason=%s",
                  G_Pairs[idx].symbol, G_Pairs[idx].state_machine,
                  G_Pairs[idx].setup_direction, reason);
   }
   
   G_Pairs[idx].state_machine = STATE_NO_SETUP;
   G_Pairs[idx].setup_direction = 0;
   G_Pairs[idx].setup_start_bar = 0;
   G_Pairs[idx].setup_bar_count = 0;
   G_Pairs[idx].rev_status = "NO SETUP";
   
   G_Pairs[idx].htf_reversal_zone = false;
   G_Pairs[idx].htf_trap_signal = 0;
   G_Pairs[idx].htf_conflict = false;
   
   G_Pairs[idx].exh_divergence = false;
   G_Pairs[idx].exh_rejection = false;
   G_Pairs[idx].exh_failed_cont = false;
   G_Pairs[idx].exh_divergence_age = 0;
   G_Pairs[idx].exh_rejection_age = 0;
   G_Pairs[idx].exh_failed_cont_age = 0;
   
   G_Pairs[idx].conf_sweep = false;
   G_Pairs[idx].conf_displacement = false;
   G_Pairs[idx].conf_mss = false;
   G_Pairs[idx].conf_retest = false;
   G_Pairs[idx].conf_sweep_age = 0;
   G_Pairs[idx].conf_displacement_age = 0;
   G_Pairs[idx].conf_mss_age = 0;
   G_Pairs[idx].sweep_level = 0.0;
   G_Pairs[idx].mss_break_level = 0.0;
   G_Pairs[idx].retest_bar_count = 0;
   
   G_Pairs[idx].qual_swing_high = 0.0;
   G_Pairs[idx].qual_swing_low = 0.0;
   G_Pairs[idx].prev_swing_high = 0.0;
   G_Pairs[idx].prev_swing_low = 0.0;
   G_Pairs[idx].qual_swing_high_idx = -1;
   G_Pairs[idx].qual_swing_low_idx = -1;
   G_Pairs[idx].prev_swing_high_idx = -1;
   G_Pairs[idx].prev_swing_low_idx = -1;
   
   G_Pairs[idx].reversal_score = 0.0;
   G_Pairs[idx].score_location = 0.0;
   G_Pairs[idx].score_exhaustion = 0.0;
   G_Pairs[idx].score_sweep = 0.0;
   G_Pairs[idx].score_displacement = 0.0;
   G_Pairs[idx].score_mss = 0.0;
   G_Pairs[idx].score_momentum = 0.0;
}

// ==================================================================
// LAYER A – LOCATION
// ==================================================================

// --- A1. EXTENSION DETECTION ---
double CalculateExtension(string sym, ENUM_TIMEFRAMES tf)
{
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return 0.0;
   double ema = CalculateEMA_Generic(sym, tf, InpReversal_EquilibriumPeriod, 1);
   double close[];
   if(CopyClose(sym, tf, 1, 1, close) < 1) return 0.0;
   
   return MathAbs(close[0] - ema) / atr;
}

// --- A2. QUALIFIED SWING DETECTION ---
// Tìm swing points đủ chất lượng (lọc bỏ swing quá nhỏ / nhiễu)
void FindQualifiedSwings(int idx, string sym, ENUM_TIMEFRAMES tf, int lookback)
{
   G_Pairs[idx].qual_swing_high = 0.0;
   G_Pairs[idx].qual_swing_low = 0.0;
   G_Pairs[idx].prev_swing_high = 0.0;
   G_Pairs[idx].prev_swing_low = 0.0;
   G_Pairs[idx].qual_swing_high_idx = -1;
   G_Pairs[idx].qual_swing_low_idx = -1;
   G_Pairs[idx].prev_swing_high_idx = -1;
   G_Pairs[idx].prev_swing_low_idx = -1;
   
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   double highs[], lows[];
   if(!ReadHighLow_Generic(sym, tf, 1, lookback, highs, lows)) return;
   
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return;
   
   double minDistance = InpMinSwingDistanceATR * atr;
   
   // Tìm Swing High (gần nhất -> cũ hơn)
   for(int i = right; i < lookback - left; i++)
   {
      bool isSwing = true;
      for(int j = 1; j <= left; j++) if(highs[i] <= highs[i+j]) { isSwing = false; break; }
      if(!isSwing) continue;
      for(int j = 1; j <= right; j++) if(highs[i] < highs[i-j]) { isSwing = false; break; }
      
      if(isSwing)
      {
         if(G_Pairs[idx].qual_swing_high == 0.0)
         {
            G_Pairs[idx].qual_swing_high = highs[i];
            G_Pairs[idx].qual_swing_high_idx = i;
         }
         else if(G_Pairs[idx].prev_swing_high == 0.0)
         {
            // Noise filter: swing thứ 2 phải cách swing 1 một khoảng >= minDistance
            if(MathAbs(G_Pairs[idx].qual_swing_high - highs[i]) >= minDistance)
            {
               G_Pairs[idx].prev_swing_high = highs[i];
               G_Pairs[idx].prev_swing_high_idx = i;
               break; // Đã tìm đủ 2 swing high
            }
         }
      }
   }
   
   // Tìm Swing Low (gần nhất -> cũ hơn)
   for(int i = right; i < lookback - left; i++)
   {
      bool isSwing = true;
      for(int j = 1; j <= left; j++) if(lows[i] >= lows[i+j]) { isSwing = false; break; }
      if(!isSwing) continue;
      for(int j = 1; j <= right; j++) if(lows[i] > lows[i-j]) { isSwing = false; break; }
      
      if(isSwing)
      {
         if(G_Pairs[idx].qual_swing_low == 0.0)
         {
            G_Pairs[idx].qual_swing_low = lows[i];
            G_Pairs[idx].qual_swing_low_idx = i;
         }
         else if(G_Pairs[idx].prev_swing_low == 0.0)
         {
            // Noise filter: swing thứ 2 phải cách swing 1 một khoảng >= minDistance
            if(MathAbs(G_Pairs[idx].qual_swing_low - lows[i]) >= minDistance)
            {
               G_Pairs[idx].prev_swing_low = lows[i];
               G_Pairs[idx].prev_swing_low_idx = i;
               break; // Đã tìm đủ 2 swing low
            }
         }
      }
   }
}

// --- A3. MARKET REGIME DETECTION ---
ENUM_MARKET_REGIME DetectMarketRegime(string sym, ENUM_TIMEFRAMES tf)
{
   double ema_fast = CalculateEMA_Generic(sym, tf, 20, 1);
   double ema_slow = CalculateEMA_Generic(sym, tf, 50, 1);
   
   if(ema_fast <= 0 || ema_slow <= 0) return REGIME_UNKNOWN;
   
   // Đánh giá slope/bias của cấu trúc dựa trên tương quan EMA,
   // không ràng buộc giá đóng cửa phải nằm cùng phía với EMA để tránh conflict khi giá extended (reversal condition)
   bool isUptrend = (ema_fast > ema_slow);
   bool isDowntrend = (ema_fast < ema_slow);
   
   if(isUptrend) return REGIME_TREND_BULL;
   if(isDowntrend) return REGIME_TREND_BEAR;
   return REGIME_SIDEWAY;
}

// --- A. HTF ZONE EVALUATION ---
// Đơn giản hơn V1: chỉ đánh giá location (extension + regime)
// Divergence chuyển sang Layer B (Exhaustion)
void EvaluateHTFZone(int idx, int &direction)
{
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES htf = G_Pairs[idx].htf;
   
   G_Pairs[idx].regime = DetectMarketRegime(sym, htf);
   G_Pairs[idx].htf_ext = CalculateExtension(sym, htf);
   
   double ext = G_Pairs[idx].htf_ext;
   
   // HTF Reversal Zone = giá extended khỏi equilibrium
   // BUY zone: đang downtrend/sideway VÀ extension đủ (giá dưới EMA)
   // HOẶC uptrend nhưng có extension extreme + exhaustion
   // SELL zone: đang uptrend/sideway VÀ extension đủ (giá trên EMA)
   // HOẶC downtrend nhưng có extension extreme + exhaustion
   double ema = CalculateEMA_Generic(sym, htf, InpReversal_EquilibriumPeriod, 1);
   double close[];
   if(CopyClose(sym, htf, 1, 1, close) < 1) { direction = 0; return; }
   
   bool price_below_ema = (close[0] < ema);
   bool price_above_ema = (close[0] > ema);
   
   bool bullish_zone = false;
   bool bearish_zone = false;
   
   G_Pairs[idx].htf_div = DetectDivergence(sym, htf, price_below_ema ? 1 : -1);
   G_Pairs[idx].htf_exh = DetectCandleRejection(sym, htf, price_below_ema ? 1 : -1);
   bool htf_exhaustion = (G_Pairs[idx].htf_div || G_Pairs[idx].htf_exh);
   
   // BUY zone: giá extended phía dưới
   if(price_below_ema && ext >= InpReversal_Extension_Normal)
   {
      if(G_Pairs[idx].regime != REGIME_TREND_BULL || (ext >= InpReversal_Extension_Extreme && htf_exhaustion))
      {
         bullish_zone = true;
      }
   }
   
   // SELL zone: giá extended phía trên
   if(price_above_ema && ext >= InpReversal_Extension_Normal)
   {
      if(G_Pairs[idx].regime != REGIME_TREND_BEAR || (ext >= InpReversal_Extension_Extreme && htf_exhaustion))
      {
         bearish_zone = true;
      }
   }
   
   // Conflict Resolution
   G_Pairs[idx].htf_conflict = false;
   if(bullish_zone && !bearish_zone) direction = 1;
   else if(bearish_zone && !bullish_zone) direction = -1;
   else if(bullish_zone && bearish_zone) { direction = 0; G_Pairs[idx].htf_conflict = true; }
   else direction = 0;
}

// --- LOCATION SCORE (capped at 15) ---
double CalculateLocationScore(int idx)
{
   double ext = G_Pairs[idx].htf_ext;
   double score = 0.0;
   
   if(ext >= InpReversal_Extension_Extreme)      score = 15.0;
   else if(ext >= InpReversal_Extension_Strong)   score = 10.0;
   else if(ext >= InpReversal_Extension_Normal)   score = 5.0;
   
   return MathMin(score, 15.0); // Cap at 15
}

// ==================================================================
// LAYER B – EXHAUSTION
// ==================================================================

// --- B1. DIVERGENCE DETECTION ---
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
   
   int swing1 = -1;
   int swing2 = -1;
   
   for(int i = right; i < lookback - left; i++)
   {
      bool isSwing = true;
      if(direction == 1)
      {
         for(int j = 1; j <= left; j++) if(lows[i] >= lows[i+j]) { isSwing = false; break; }
         if(!isSwing) continue;
         for(int j = 1; j <= right; j++) if(lows[i] > lows[i-j]) { isSwing = false; break; }
      }
      else
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
      if(direction == 1)
      {
         // Bullish Div: Price Lower Low + CCI Higher Low
         if(lows[swing1] < lows[swing2] && cci[swing1] > cci[swing2]) return true;
      }
      else
      {
         // Bearish Div: Price Higher High + CCI Lower High
         if(highs[swing1] > highs[swing2] && cci[swing1] < cci[swing2]) return true;
      }
   }
   
   return false;
}

// --- B2. CANDLE REJECTION ---
// Cải thiện: kiểm tra wick + body + vị trí close
bool DetectCandleRejection(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double open[], high[], low[], close[];
   if(CopyOpen(sym, tf, 1, 1, open) < 1) return false;
   if(CopyHigh(sym, tf, 1, 1, high) < 1) return false;
   if(CopyLow(sym, tf, 1, 1, low) < 1) return false;
   if(CopyClose(sym, tf, 1, 1, close) < 1) return false;
   
   double body = MathAbs(close[0] - open[0]);
   double range = high[0] - low[0];
   if(range <= 0) return false;
   
   if(direction == 1) // Bullish rejection (bearish trend weakening)
   {
      double lowerWick = MathMin(open[0], close[0]) - low[0];
      double closePosition = (close[0] - low[0]) / range; // 0=bottom, 1=top
      
      // Wick phải đáng kể (>= 0.5 ATR), close phải ở nửa trên, wick > body
      if(lowerWick >= atr * 0.5 && closePosition >= 0.6 && lowerWick > body)
         return true;
   }
   else if(direction == -1) // Bearish rejection (bullish trend weakening)
   {
      double upperWick = high[0] - MathMax(open[0], close[0]);
      double closePosition = (high[0] - close[0]) / range; // 0=top, 1=bottom
      
      // Wick phải đáng kể, close phải ở nửa dưới, wick > body
      if(upperWick >= atr * 0.5 && closePosition >= 0.6 && upperWick > body)
         return true;
   }
   
   return false;
}

// --- B3. FAILED CONTINUATION ---
// Giá cố tiếp tục xu hướng → tạo extreme mới → nhưng close quay lại
bool DetectFailedContinuation(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   double open[], high[], low[], close[];
   if(CopyOpen(sym, tf, 1, 2, open) < 2) return false;
   if(CopyHigh(sym, tf, 1, 2, high) < 2) return false;
   if(CopyLow(sym, tf, 1, 2, low) < 2) return false;
   if(CopyClose(sym, tf, 1, 2, close) < 2) return false;
   
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(direction == 1) // Bullish: giá cố giảm tiếp nhưng thất bại
   {
      // Candle [0] tạo low mới (dưới low candle [1])
      // Nhưng close quay lại trên low candle [1]
      // Và close cao hơn close candle [1]
      if(low[0] < low[1] && close[0] > low[1] && close[0] > close[1])
         return true;
   }
   else if(direction == -1) // Bearish: giá cố tăng tiếp nhưng thất bại
   {
      // Candle [0] tạo high mới (trên high candle [1])
      // Nhưng close quay lại dưới high candle [1]
      // Và close thấp hơn close candle [1]
      if(high[0] > high[1] && close[0] < high[1] && close[0] < close[1])
         return true;
   }
   
   return false;
}

// --- EXHAUSTION SCORE (capped at 15) ---
// Divergence + Rejection + FailedCont cùng nhóm → KHÔNG cộng vô hạn
double CalculateExhaustionScore(int idx)
{
   double score = 0.0;
   int count = 0;
   
   if(G_Pairs[idx].exh_divergence)  { score += 8.0; count++; }
   if(G_Pairs[idx].exh_rejection)   { score += 6.0; count++; }
   if(G_Pairs[idx].exh_failed_cont) { score += 6.0; count++; }
   
   // Nếu nhiều signal cùng xuất hiện → tăng tin cậy nhưng cap
   // 1 signal: max 8, 2 signals: max 12, 3 signals: 15 (capped)
   if(count >= 2) score = MathMin(score, 12.0);
   if(count >= 3) score = 15.0;
   
   return MathMin(score, 15.0); // Hard cap at 15
}

// ==================================================================
// LAYER C – REVERSAL CONFIRMATION
// ==================================================================

// --- C1. LIQUIDITY SWEEP ---
// BUY: giá quét dưới swing low rồi close quay lại trên
// SELL: giá quét trên swing high rồi close quay lại dưới
bool DetectLiquiditySweep(string sym, ENUM_TIMEFRAMES tf, int direction, double swingLevel)
{
   if(!InpEnableLiquiditySweep) return true; // Disabled = auto pass
   if(swingLevel <= 0.0) return false;
   
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double tolerance = InpLiquiditySweepToleranceATR * atr;
   
   double high[], low[], close[];
   if(CopyHigh(sym, tf, 1, 1, high) < 1) return false;
   if(CopyLow(sym, tf, 1, 1, low) < 1) return false;
   if(CopyClose(sym, tf, 1, 1, close) < 1) return false;
   
   if(direction == 1) // BUY: sweep below swing low
   {
      // Low bắt buộc phải phá qua swing low
      bool swept = (low[0] <= swingLevel - tolerance);
      // Close BẮT BUỘC phải quay lại trên swing low
      bool closedBack = (close[0] > swingLevel);
      
      return (swept && closedBack);
   }
   else if(direction == -1) // SELL: sweep above swing high
   {
      // High bắt buộc phải phá qua swing high
      bool swept = (high[0] >= swingLevel + tolerance);
      // Close BẮT BUỘC phải quay lại dưới swing high
      bool closedBack = (close[0] < swingLevel);
      
      return (swept && closedBack);
   }
   
   return false;
}

// --- C2. DISPLACEMENT ---
// Candle đảo chiều có lực đủ mạnh (ATR-normalized)
bool DetectDisplacement(string sym, ENUM_TIMEFRAMES tf, int direction)
{
   if(!InpEnableDisplacement) return true; // Disabled = auto pass
   
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double open[], high[], low[], close[];
   if(CopyOpen(sym, tf, 1, 1, open) < 1) return false;
   if(CopyHigh(sym, tf, 1, 1, high) < 1) return false;
   if(CopyLow(sym, tf, 1, 1, low) < 1) return false;
   if(CopyClose(sym, tf, 1, 1, close) < 1) return false;
   
   double body = MathAbs(close[0] - open[0]);
   double range = high[0] - low[0];
   if(range <= 0) return false;
   
   double minBody = InpDisplacementMinBodyATR * atr;
   double minClosePercent = InpDisplacementClosePercent / 100.0;
   
   if(direction == 1) // Bullish displacement
   {
      bool isBullish = (close[0] > open[0]);
      bool bodyOK = (body >= minBody);
      double closePos = (close[0] - low[0]) / range;
      bool closePosOK = (closePos >= minClosePercent);
      
      return (isBullish && bodyOK && closePosOK);
   }
   else if(direction == -1) // Bearish displacement
   {
      bool isBearish = (close[0] < open[0]);
      bool bodyOK = (body >= minBody);
      double closePos = (high[0] - close[0]) / range;
      bool closePosOK = (closePos >= minClosePercent);
      
      return (isBearish && bodyOK && closePosOK);
   }
   
   return false;
}

// ==================================================================
// MSS STRUCTURE SEQUENCE VALIDATION
// ==================================================================
// BUY sequence: PrevHigh → ProtectedLow(LL) → CandidateLH → Break LH
// SELL sequence: PrevLow → ProtectedHigh(HH) → CandidateHL → Break HL
//
// Array orientation: ReadHighLow_Generic uses ArraySetAsSeries(true)
// so index 0 = newest closed bar, higher index = older bar.
// Chronology: older event has HIGHER index, newer event has LOWER index.
// ==================================================================

// Helper: detect if bar index i is a valid swing high
bool IsSwingHigh(const double &highs[], int i, int left, int right, int arraySize)
{
   if(i < right || i >= arraySize - left) return false;
   for(int j = 1; j <= left; j++) if(highs[i] <= highs[i+j]) return false;
   for(int j = 1; j <= right; j++) if(highs[i] < highs[i-j]) return false;
   return true;
}

// Helper: detect if bar index i is a valid swing low
bool IsSwingLow(const double &lows[], int i, int left, int right, int arraySize)
{
   if(i < right || i >= arraySize - left) return false;
   for(int j = 1; j <= left; j++) if(lows[i] >= lows[i+j]) return false;
   for(int j = 1; j <= right; j++) if(lows[i] > lows[i-j]) return false;
   return true;
}

bool ValidateBuyStructure(int idx, string sym, ENUM_TIMEFRAMES tf, double &breakLevel, string &rejectReason)
{
   int lookback = InpReversal_LookbackBars;
   double highs[], lows[];
   if(!ReadHighLow_Generic(sym, tf, 1, lookback, highs, lows)) { rejectReason = "NO_DATA"; return false; }
   
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) { rejectReason = "NO_ATR"; return false; }
   
   double minBreak = InpMSSMinBreakATR * atr;
   double minDistance = InpMinSwingDistanceATR * atr;
   
   double close[];
   if(CopyClose(sym, tf, 1, 1, close) < 1) { rejectReason = "NO_DATA"; return false; }
   
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   // ============================================================
   // BUY MSS requires proving the full sequence:
   //   PreviousHigh (oldest) → ProtectedLow/LL → CandidateLH → Break
   //
   // Strategy: collect swing highs and swing lows, then search
   // for valid triplets from newest to oldest.
   // ============================================================
   
   // Collect all swing highs (newest first, index ascending = older)
   double swHighPrices[];
   int    swHighIdxs[];
   int    swHighCount = 0;
   ArrayResize(swHighPrices, 0);
   ArrayResize(swHighIdxs, 0);
   
   for(int i = right; i < lookback - left; i++)
   {
      if(IsSwingHigh(highs, i, left, right, lookback))
      {
         ArrayResize(swHighPrices, swHighCount + 1);
         ArrayResize(swHighIdxs, swHighCount + 1);
         swHighPrices[swHighCount] = highs[i];
         swHighIdxs[swHighCount] = i;
         swHighCount++;
      }
   }
   
   // Collect all swing lows (newest first)
   double swLowPrices[];
   int    swLowIdxs[];
   int    swLowCount = 0;
   ArrayResize(swLowPrices, 0);
   ArrayResize(swLowIdxs, 0);
   
   for(int i = right; i < lookback - left; i++)
   {
      if(IsSwingLow(lows, i, left, right, lookback))
      {
         ArrayResize(swLowPrices, swLowCount + 1);
         ArrayResize(swLowIdxs, swLowCount + 1);
         swLowPrices[swLowCount] = lows[i];
         swLowIdxs[swLowCount] = i;
         swLowCount++;
      }
   }
   
   // Need at least 2 swing highs (candidateLH + prevHigh) and 1 swing low (protectedLow)
   if(swHighCount < 2) { rejectReason = (swHighCount == 0) ? "MSS_NO_LH" : "MSS_NO_PREVIOUS_HIGH"; return false; }
   if(swLowCount < 1) { rejectReason = "MSS_NO_PROTECTED_LOW"; return false; }
   
   // ============================================================
   // Search for the best (most recent) valid triplet:
   //   prevHigh(older) → protectedLow(middle) → candidateLH(newer)
   //
   // Iterate candidate LH from newest to oldest (swHighPrices[0..n])
   // For each candidate LH, find a protectedLow OLDER than it,
   // then find a prevHigh OLDER than the protectedLow.
   // ============================================================
   
   for(int lhI = 0; lhI < swHighCount - 1; lhI++)
   {
      double candidateLH = swHighPrices[lhI];
      int    candidateLHIdx = swHighIdxs[lhI];
      
      // Find the nearest protectedLow that is OLDER than candidateLH
      // (protectedLowIdx > candidateLHIdx since higher index = older)
      double protectedLow = 0.0;
      int    protectedLowIdx = -1;
      
      for(int lowI = 0; lowI < swLowCount; lowI++)
      {
         if(swLowIdxs[lowI] > candidateLHIdx) // older than LH
         {
            // Micro-structure filter: distance between LH and protected low
            if(MathAbs(candidateLH - swLowPrices[lowI]) >= minDistance)
            {
               protectedLow = swLowPrices[lowI];
               protectedLowIdx = swLowIdxs[lowI];
               break;
            }
         }
      }
      
      if(protectedLowIdx == -1) continue; // no valid protected low for this LH
      
      // Find the nearest prevHigh that is OLDER than protectedLow
      // (prevHighIdx > protectedLowIdx)
      // AND prevHigh must be structurally separate from candidateLH
      // AND candidateLH must be LOWER than prevHigh
      double prevHigh = 0.0;
      int    prevHighIdx = -1;
      
      for(int phI = lhI + 1; phI < swHighCount; phI++)
      {
         if(swHighIdxs[phI] > protectedLowIdx) // older than protected low
         {
            if(MathAbs(swHighPrices[phI] - candidateLH) >= minDistance)
            {
               prevHigh = swHighPrices[phI];
               prevHighIdx = swHighIdxs[phI];
               break;
            }
         }
      }
      
      if(prevHighIdx == -1) continue; // MANDATORY: cannot prove previous structure
      
      // Validate: candidateLH must be LOWER than prevHigh (bearish structure)
      if(candidateLH >= prevHigh) continue;
      
      // Validate chronology: prevHighIdx > protectedLowIdx > candidateLHIdx
      if(!(prevHighIdx > protectedLowIdx && protectedLowIdx > candidateLHIdx))
         continue;
      
      // Validate break: closed candle must break above candidateLH
      if(close[0] <= candidateLH) { rejectReason = "MSS_BREAK_NOT_CLOSED"; return false; }
      
      double breakDistance = close[0] - candidateLH;
      if(breakDistance < minBreak) { rejectReason = "MSS_BREAK_TOO_WEAK"; return false; }
      
      // All validations passed
      breakLevel = candidateLH;
      rejectReason = "MSS_VALID";
      return true;
   }
   
   // No valid triplet found
   rejectReason = "MSS_INVALID_SEQUENCE";
   return false;
}

bool ValidateSellStructure(int idx, string sym, ENUM_TIMEFRAMES tf, double &breakLevel, string &rejectReason)
{
   int lookback = InpReversal_LookbackBars;
   double highs[], lows[];
   if(!ReadHighLow_Generic(sym, tf, 1, lookback, highs, lows)) { rejectReason = "NO_DATA"; return false; }
   
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) { rejectReason = "NO_ATR"; return false; }
   
   double minBreak = InpMSSMinBreakATR * atr;
   double minDistance = InpMinSwingDistanceATR * atr;
   
   double close[];
   if(CopyClose(sym, tf, 1, 1, close) < 1) { rejectReason = "NO_DATA"; return false; }
   
   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   
   // ============================================================
   // SELL MSS requires proving the full sequence:
   //   PreviousLow (oldest) → ProtectedHigh/HH → CandidateHL → Break
   // ============================================================
   
   // Collect all swing lows (newest first)
   double swLowPrices[];
   int    swLowIdxs[];
   int    swLowCount = 0;
   ArrayResize(swLowPrices, 0);
   ArrayResize(swLowIdxs, 0);
   
   for(int i = right; i < lookback - left; i++)
   {
      if(IsSwingLow(lows, i, left, right, lookback))
      {
         ArrayResize(swLowPrices, swLowCount + 1);
         ArrayResize(swLowIdxs, swLowCount + 1);
         swLowPrices[swLowCount] = lows[i];
         swLowIdxs[swLowCount] = i;
         swLowCount++;
      }
   }
   
   // Collect all swing highs (newest first)
   double swHighPrices[];
   int    swHighIdxs[];
   int    swHighCount = 0;
   ArrayResize(swHighPrices, 0);
   ArrayResize(swHighIdxs, 0);
   
   for(int i = right; i < lookback - left; i++)
   {
      if(IsSwingHigh(highs, i, left, right, lookback))
      {
         ArrayResize(swHighPrices, swHighCount + 1);
         ArrayResize(swHighIdxs, swHighCount + 1);
         swHighPrices[swHighCount] = highs[i];
         swHighIdxs[swHighCount] = i;
         swHighCount++;
      }
   }
   
   // Need at least 2 swing lows (candidateHL + prevLow) and 1 swing high (protectedHigh)
   if(swLowCount < 2) { rejectReason = (swLowCount == 0) ? "MSS_NO_HL" : "MSS_NO_PREVIOUS_LOW"; return false; }
   if(swHighCount < 1) { rejectReason = "MSS_NO_PROTECTED_HIGH"; return false; }
   
   // ============================================================
   // Search for the best (most recent) valid triplet:
   //   prevLow(older) → protectedHigh(middle) → candidateHL(newer)
   //
   // Iterate candidate HL from newest to oldest
   // For each candidate HL, find a protectedHigh OLDER than it,
   // then find a prevLow OLDER than the protectedHigh.
   // ============================================================
   
   for(int hlI = 0; hlI < swLowCount - 1; hlI++)
   {
      double candidateHL = swLowPrices[hlI];
      int    candidateHLIdx = swLowIdxs[hlI];
      
      // Find the nearest protectedHigh that is OLDER than candidateHL
      // (protectedHighIdx > candidateHLIdx)
      double protectedHigh = 0.0;
      int    protectedHighIdx = -1;
      
      for(int highI = 0; highI < swHighCount; highI++)
      {
         if(swHighIdxs[highI] > candidateHLIdx) // older than HL
         {
            // Micro-structure filter
            if(MathAbs(swHighPrices[highI] - candidateHL) >= minDistance)
            {
               protectedHigh = swHighPrices[highI];
               protectedHighIdx = swHighIdxs[highI];
               break;
            }
         }
      }
      
      if(protectedHighIdx == -1) continue; // no valid protected high for this HL
      
      // Find the nearest prevLow that is OLDER than protectedHigh
      // (prevLowIdx > protectedHighIdx)
      // AND prevLow must be structurally separate from candidateHL
      // AND candidateHL must be HIGHER than prevLow
      double prevLow = 0.0;
      int    prevLowIdx = -1;
      
      for(int plI = hlI + 1; plI < swLowCount; plI++)
      {
         if(swLowIdxs[plI] > protectedHighIdx) // older than protected high
         {
            if(MathAbs(swLowPrices[plI] - candidateHL) >= minDistance)
            {
               prevLow = swLowPrices[plI];
               prevLowIdx = swLowIdxs[plI];
               break;
            }
         }
      }
      
      if(prevLowIdx == -1) continue; // MANDATORY: cannot prove previous structure
      
      // Validate: candidateHL must be HIGHER than prevLow (bullish structure)
      if(candidateHL <= prevLow) continue;
      
      // Validate chronology: prevLowIdx > protectedHighIdx > candidateHLIdx
      if(!(prevLowIdx > protectedHighIdx && protectedHighIdx > candidateHLIdx))
         continue;
      
      // Validate break: closed candle must break below candidateHL
      if(close[0] >= candidateHL) { rejectReason = "MSS_BREAK_NOT_CLOSED"; return false; }
      
      double breakDistance = candidateHL - close[0];
      if(breakDistance < minBreak) { rejectReason = "MSS_BREAK_TOO_WEAK"; return false; }
      
      // All validations passed
      breakLevel = candidateHL;
      rejectReason = "MSS_VALID";
      return true;
   }
   
   // No valid triplet found
   rejectReason = "MSS_INVALID_SEQUENCE";
   return false;
}

// --- C3. STRUCTURE SHIFT (Quality MSS) ---
// Cải thiện: dùng nearest protected structure thay vì global extremes
bool DetectStructureShift(int idx, string sym, ENUM_TIMEFRAMES tf, int direction,
                           double &breakLevel, string &rejectReason)
{
   if(!InpReversal_RequireStructureShift) { breakLevel = 0.0; rejectReason = "MSS_NOT_REQUIRED"; return true; }
   
   if(direction == 1) // Bullish MSS
   {
      return ValidateBuyStructure(idx, sym, tf, breakLevel, rejectReason);
   }
   else if(direction == -1) // Bearish MSS
   {
      return ValidateSellStructure(idx, sym, tf, breakLevel, rejectReason);
   }
   
   breakLevel = 0.0;
   rejectReason = "INVALID_DIRECTION";
   return false;
}

// --- C4. RETEST ---
// Giá quay lại test vùng vừa phá, giữ được và đóng candle xác nhận
bool DetectRetest(string sym, ENUM_TIMEFRAMES tf, int direction, 
                   double breakLevel, int &retestBarCount)
{
   if(!InpEnableRetest || !InpRequireRetest) return true; // Disabled = auto pass
   if(breakLevel <= 0.0) return false;
   
   double atr = CalculateATR_Generic(sym, tf, InpReversal_ATR_Period, 1);
   if(atr <= 0) return false;
   
   double tolerance = InpRetestToleranceATR * atr;
   
   double high[], low[], close[];
   if(CopyHigh(sym, tf, 1, 1, high) < 1) return false;
   if(CopyLow(sym, tf, 1, 1, low) < 1) return false;
   if(CopyClose(sym, tf, 1, 1, close) < 1) return false;
   
   retestBarCount++;
   
   if(direction == 1) // BUY retest: giá pullback xuống gần breakLevel, rồi hold trên
   {
      // Giá phải đã chạm gần vùng breakLevel
      bool touched = (low[0] <= breakLevel + tolerance);
      // Close phải giữ trên breakLevel
      bool held = (close[0] > breakLevel);
      
      if(touched && held) return true;
   }
   else if(direction == -1) // SELL retest: giá pullback lên gần breakLevel, rồi hold dưới
   {
      bool touched = (high[0] >= breakLevel - tolerance);
      bool held = (close[0] < breakLevel);
      
      if(touched && held) return true;
   }
   
   // Check timeout
   if(retestBarCount > InpRetestMaxBars) return false;
   
   return false;
}

// ==================================================================
// SCORING ENGINE (Grouped, Capped)
// ==================================================================

double CalculateReversalScore(int idx, int direction)
{
   // --- LOCATION (max 15) ---
   G_Pairs[idx].score_location = CalculateLocationScore(idx);
   
   // --- EXHAUSTION (max 15) ---
   G_Pairs[idx].score_exhaustion = CalculateExhaustionScore(idx);
   
   // --- LIQUIDITY SWEEP (max 20) ---
   G_Pairs[idx].score_sweep = G_Pairs[idx].conf_sweep ? 20.0 : 0.0;
   
   // --- DISPLACEMENT (max 15) ---
   G_Pairs[idx].score_displacement = G_Pairs[idx].conf_displacement ? 15.0 : 0.0;
   
   // --- STRUCTURE SHIFT (max 25) ---
   G_Pairs[idx].score_mss = G_Pairs[idx].conf_mss ? 25.0 : 0.0;
   
   // --- MOMENTUM (max 10) ---
   double mom = 0.0;
   int cci_status = 0, rf_status = 0;
   datetime cci_time = 0, rf_time = 0;
   CheckMomentumStatus(idx, cci_status, rf_status, cci_time, rf_time);
   G_Pairs[idx].ltf_cci_recov = cci_status;
   G_Pairs[idx].ltf_rf_state = rf_status;
   
   if(cci_status == direction) mom += 5.0;
   if(rf_status == direction)  mom += 5.0;
   G_Pairs[idx].score_momentum = MathMin(mom, 10.0);
   
   // --- TOTAL ---
   double total = G_Pairs[idx].score_location
                + G_Pairs[idx].score_exhaustion
                + G_Pairs[idx].score_sweep
                + G_Pairs[idx].score_displacement
                + G_Pairs[idx].score_mss
                + G_Pairs[idx].score_momentum;
   
   G_Pairs[idx].reversal_score = total;
   return total;
}

// ==================================================================
// HARD REQUIREMENTS VALIDATION
// ==================================================================
// Score KHÔNG được thay thế các điều kiện bắt buộc.
bool ValidateHardRequirements(int idx, int direction, string &rejectReason)
{
   // 1. HTF Location hợp lệ
   if(!G_Pairs[idx].htf_reversal_zone)
   {
      rejectReason = "NO_HTF_ZONE";
      return false;
   }
   
   // 2. Ít nhất 1 dấu hiệu Exhaustion
   if(!G_Pairs[idx].exh_divergence && !G_Pairs[idx].exh_rejection && !G_Pairs[idx].exh_failed_cont)
   {
      rejectReason = "NO_EXHAUSTION";
      return false;
   }
   
   // 3. Liquidity Sweep (nếu bật)
   if(InpEnableLiquiditySweep && !G_Pairs[idx].conf_sweep)
   {
      rejectReason = "SWEEP_NOT_CONFIRMED";
      return false;
   }
   
   // 4. Displacement (nếu bật)
   if(InpEnableDisplacement && !G_Pairs[idx].conf_displacement)
   {
      rejectReason = "DISPLACEMENT_NOT_CONFIRMED";
      return false;
   }
   
   // 5. Structure Shift phải được xác nhận (nếu bắt buộc)
   if(InpReversal_RequireStructureShift && !G_Pairs[idx].conf_mss)
   {
      rejectReason = "MSS_NOT_CONFIRMED";
      return false;
   }
   
   // 6. Score >= MinScore
   if(G_Pairs[idx].reversal_score < ENTRY_REQUIRED_SCORE)
   {
      rejectReason = "SCORE_BELOW_MIN";
      return false;
   }
   
   // 7. DXY không chống lại setup (nếu áp dụng)
   if(G_Pairs[idx].isUSDPair && g_dxy_available && InpUseDXYReference)
   {
      G_Pairs[idx].trapSignal = direction;
      int dxy_signal = CheckDXYConvergence_Dual(idx);
      
      if(dxy_signal == 0)
      {
         rejectReason = "DXY_NOT_READY";
         return false;
      }
      if(dxy_signal != direction)
      {
         rejectReason = "DXY_CONFLICT";
         return false;
      }
   }
   
   rejectReason = "";
   return true;
}

// ==================================================================
// SETUP TIMEOUT & INVALIDATION
// ==================================================================

bool CheckSetupTimeout(int idx)
{
   if(G_Pairs[idx].setup_bar_count > InpSafetyMaxSetupBars)
   {
      return true; // Safety Timeout!
   }
   return false;
}

// Kiểm tra invalidation: nếu giá tiếp tục tạo extreme mới mà không rejection
bool CheckSetupInvalidation(int idx, string sym, ENUM_TIMEFRAMES tf)
{
   if(G_Pairs[idx].state_machine <= STATE_HTF_LOCATION) return false;
   
   int dir = G_Pairs[idx].setup_direction;
   
   double close[];
   if(CopyClose(sym, tf, 1, 1, close) < 1) return false;
   
   if(dir == 1) // BUY setup
   {
      // Nếu giá phá qua dưới qualified swing low → cấu trúc mất
      if(G_Pairs[idx].qual_swing_low > 0.0 && close[0] < G_Pairs[idx].qual_swing_low)
      {
         // Chỉ invalidate nếu đã có exhaustion
         if(G_Pairs[idx].exh_divergence || G_Pairs[idx].exh_rejection || G_Pairs[idx].exh_failed_cont)
            return true;
      }
   }
   else if(dir == -1) // SELL setup
   {
      if(G_Pairs[idx].qual_swing_high > 0.0 && close[0] > G_Pairs[idx].qual_swing_high)
      {
         if(G_Pairs[idx].exh_divergence || G_Pairs[idx].exh_rejection || G_Pairs[idx].exh_failed_cont)
            return true;
      }
   }
   
   return false;
}

// Check if evidence meets hard requirements (excluding DXY and Retest)
bool IsEvidenceReady(int idx, int direction)
{
   if(!G_Pairs[idx].htf_reversal_zone) return false;
   if(!G_Pairs[idx].exh_divergence && !G_Pairs[idx].exh_rejection && !G_Pairs[idx].exh_failed_cont) return false;
   
   if(InpEnableLiquiditySweep && !G_Pairs[idx].conf_sweep) return false;
   if(InpEnableDisplacement && !G_Pairs[idx].conf_displacement) return false;
   
   if(InpReversal_RequireStructureShift && !G_Pairs[idx].conf_mss) return false;
   
   if(CalculateReversalScore(idx, direction) < ENTRY_REQUIRED_SCORE) return false;
   return true;
}

// ==================================================================
// DEBUG LOGGING
// ==================================================================
void LogReversalDecision(int idx, int direction, string decision, string reason, double score)
{
   if(!InpReversalDebug) return;
   
   string sym = G_Pairs[idx].symbol;
   string dir_str = (direction == 1) ? "BUY" : ((direction == -1) ? "SELL" : "NONE");
   string regime_str = EnumToString(G_Pairs[idx].regime);
   
   string state_str = "";
   switch(G_Pairs[idx].state_machine) {
      case STATE_NO_SETUP:        state_str = "NO_SETUP"; break;
      case STATE_HTF_LOCATION:    state_str = "HTF_LOCATION"; break;
      case STATE_EXHAUSTION:      state_str = "EXHAUSTION"; break;
      case STATE_LIQUIDITY:       state_str = "LIQUIDITY"; break;
      case STATE_REVERSAL_CONF:   state_str = "REVERSAL_CONF"; break;
      case STATE_STRUCTURE_SHIFT: state_str = "STRUCTURE_SHIFT"; break;
      case STATE_RETEST:          state_str = "RETEST"; break;
      case STATE_ENTRY_READY:     state_str = "ENTRY_READY"; break;
   }
   
   string dxy_str = "N/A";
   if(G_Pairs[idx].isUSDPair && g_dxy_available && InpUseDXYReference)
   {
      if(decision == "ENTRY_READY") dxy_str = "PASS";
      else dxy_str = "WAITING";
   }
   
   PrintFormat("[COUNTER-TREND] %s", sym);
   PrintFormat("  Direction=%s | State=%s | Regime=%s", dir_str, state_str, regime_str);
   PrintFormat("  Location: Ext=%.2f | Score=%.0f", G_Pairs[idx].htf_ext, G_Pairs[idx].score_location);
   PrintFormat("  Exhaustion: Div=%d | Rej=%d | FailCont=%d | Score=%.0f",
               G_Pairs[idx].exh_divergence, G_Pairs[idx].exh_rejection,
               G_Pairs[idx].exh_failed_cont, G_Pairs[idx].score_exhaustion);
   PrintFormat("  Confirmation: Sweep=%d | Displacement=%d | MSS=%d | Retest=%d",
               G_Pairs[idx].conf_sweep, G_Pairs[idx].conf_displacement,
               G_Pairs[idx].conf_mss, G_Pairs[idx].conf_retest);
   PrintFormat("  Score: Loc=%.0f Exh=%.0f Swp=%.0f Dsp=%.0f MSS=%.0f Mom=%.0f = Total=%.0f",
               G_Pairs[idx].score_location, G_Pairs[idx].score_exhaustion,
               G_Pairs[idx].score_sweep, G_Pairs[idx].score_displacement,
               G_Pairs[idx].score_mss, G_Pairs[idx].score_momentum,
               G_Pairs[idx].reversal_score);
   PrintFormat("  DXY=%s | Decision=%s | Reason=%s", dxy_str, decision, reason);
}

// ==================================================================
// CORE REVERSAL SIGNAL LOGIC (V2 STATE MACHINE)
// ==================================================================
// Returns: 1 = BUY Trigger, -1 = SELL Trigger, 0 = Wait/None
int CheckCounterTrendSignal(int idx)
{
   if(!InpUseReversalEngine) return 0;
   
   string sym = G_Pairs[idx].symbol;
   ENUM_TIMEFRAMES ltf = G_Pairs[idx].ltf;
   
   // === STATE 0 & 1: HTF EVALUATION (On HTF New Bar) ===
   if(IsNewBar_HTF(idx))
   {
      int new_dir = 0;
      EvaluateHTFZone(idx, new_dir);
      
      if(new_dir != 0)
      {
         G_Pairs[idx].htf_reversal_zone = true;
         G_Pairs[idx].htf_trap_signal = new_dir;
         
         if(G_Pairs[idx].state_machine == STATE_NO_SETUP)
         {
            G_Pairs[idx].state_machine = STATE_HTF_LOCATION;
            G_Pairs[idx].setup_direction = new_dir;
            G_Pairs[idx].setup_bar_count = 0;
            G_Pairs[idx].rev_status = "LOCATION";
            LogReversalDecision(idx, new_dir, "HTF_LOCATION", "Zone detected", 0);
         }
         else if(G_Pairs[idx].setup_direction != 0 && G_Pairs[idx].setup_direction != new_dir)
         {
            // HTF đổi hướng → reset hoàn toàn
            ResetReversalSetup(idx, "HTF Direction Changed");
         }
      }
      else
      {
         if(G_Pairs[idx].state_machine != STATE_NO_SETUP)
         {
            ResetReversalSetup(idx, "HTF Zone Lost or Conflict");
         }
      }
   }
   
   // Nếu không có direction → dừng
   if(G_Pairs[idx].setup_direction == 0) return 0;
   if(G_Pairs[idx].state_machine == STATE_NO_SETUP) return 0;
   
   // === LTF STATE MACHINE (On LTF New Bar) ===
   if(!IsNewBar_Multi(idx)) return 0;
   
   int dir = G_Pairs[idx].setup_direction;
   
   // Update indicator states (CCI + Range Filter) mỗi bar mới
   UpdateIndicatorsState(idx);
   
   // Tăng bar count cho timeout tracking
   G_Pairs[idx].setup_bar_count++;
   
   // --- CHECK TIMEOUT ---
   if(CheckSetupTimeout(idx))
   {
      ResetReversalSetup(idx, "SETUP_TIMEOUT");
      return 0;
   }
   
   // --- CHECK INVALIDATION ---
   if(CheckSetupInvalidation(idx, sym, ltf))
   {
      ResetReversalSetup(idx, "SETUP_INVALIDATED");
      return 0;
   }
   
   // --- FRESHNESS UPDATE ---
   if(G_Pairs[idx].exh_divergence) { G_Pairs[idx].exh_divergence_age++; if(G_Pairs[idx].exh_divergence_age > InpExhaustionMaxAgeBars) { G_Pairs[idx].exh_divergence = false; G_Pairs[idx].exh_divergence_age = 0; } }
   if(G_Pairs[idx].exh_rejection) { G_Pairs[idx].exh_rejection_age++; if(G_Pairs[idx].exh_rejection_age > InpExhaustionMaxAgeBars) { G_Pairs[idx].exh_rejection = false; G_Pairs[idx].exh_rejection_age = 0; } }
   if(G_Pairs[idx].exh_failed_cont) { G_Pairs[idx].exh_failed_cont_age++; if(G_Pairs[idx].exh_failed_cont_age > InpExhaustionMaxAgeBars) { G_Pairs[idx].exh_failed_cont = false; G_Pairs[idx].exh_failed_cont_age = 0; } }
   
   if(G_Pairs[idx].conf_sweep) { G_Pairs[idx].conf_sweep_age++; if(G_Pairs[idx].conf_sweep_age > InpSweepMaxAgeBars) { G_Pairs[idx].conf_sweep = false; G_Pairs[idx].conf_sweep_age = 0; } }
   if(G_Pairs[idx].conf_displacement) { G_Pairs[idx].conf_displacement_age++; if(G_Pairs[idx].conf_displacement_age > InpDisplacementMaxAgeBars) { G_Pairs[idx].conf_displacement = false; G_Pairs[idx].conf_displacement_age = 0; } }
   if(G_Pairs[idx].conf_mss) { G_Pairs[idx].conf_mss_age++; if(G_Pairs[idx].conf_mss_age > InpMSSMaxAgeBars) { G_Pairs[idx].conf_mss = false; G_Pairs[idx].conf_mss_age = 0; } }

   // === STATE: EVIDENCE ACCUMULATION ===
   if(G_Pairs[idx].state_machine >= STATE_HTF_LOCATION && G_Pairs[idx].state_machine < STATE_RETEST)
   {
      // Cập nhật qualified swings liên tục
      FindQualifiedSwings(idx, sym, ltf, InpLiquiditySweepLookback);
      
      // Kiểm tra Exhaustion (independent)
      if(!G_Pairs[idx].exh_divergence) { if(DetectDivergence(sym, ltf, dir)) { G_Pairs[idx].exh_divergence = true; G_Pairs[idx].exh_divergence_age = 0; } }
      if(!G_Pairs[idx].exh_rejection) { if(DetectCandleRejection(sym, ltf, dir)) { G_Pairs[idx].exh_rejection = true; G_Pairs[idx].exh_rejection_age = 0; } }
      if(!G_Pairs[idx].exh_failed_cont) { if(DetectFailedContinuation(sym, ltf, dir)) { G_Pairs[idx].exh_failed_cont = true; G_Pairs[idx].exh_failed_cont_age = 0; } }
      
      // Kiểm tra Sweep (independent)
      double sweepTarget = (dir == 1) ? G_Pairs[idx].qual_swing_low : G_Pairs[idx].qual_swing_high;
      if(!G_Pairs[idx].conf_sweep) {
         if(DetectLiquiditySweep(sym, ltf, dir, sweepTarget)) {
            G_Pairs[idx].conf_sweep = true;
            G_Pairs[idx].conf_sweep_age = 0;
            G_Pairs[idx].sweep_level = sweepTarget;
            LogReversalDecision(idx, dir, "LIQUIDITY", "Sweep detected", 0);
         }
      }
      
      // Kiểm tra Displacement (independent)
      if(!G_Pairs[idx].conf_displacement) {
         if(DetectDisplacement(sym, ltf, dir)) {
            G_Pairs[idx].conf_displacement = true;
            G_Pairs[idx].conf_displacement_age = 0;
            LogReversalDecision(idx, dir, "DISPLACEMENT", "Displacement candle detected", 0);
         }
      }
      
      // Kiểm tra MSS (independent)
      if(!G_Pairs[idx].conf_mss) {
         double breakLvl = 0.0;
         string mssRejectReason = "";
         if(DetectStructureShift(idx, sym, ltf, dir, breakLvl, mssRejectReason)) {
            G_Pairs[idx].conf_mss = true;
            G_Pairs[idx].conf_mss_age = 0;
            G_Pairs[idx].mss_break_level = breakLvl;
            LogReversalDecision(idx, dir, "MSS_CONFIRMED", "Structure shifted (quality)", 0);
         } else if (InpReversalDebug && mssRejectReason != "" && mssRejectReason != "MSS_BREAK_NOT_CLOSED") {
            // Log rejection reasons periodically or minimally to avoid spam (maybe only when something significant changes)
            // But we will log them for visibility
            // LogReversalDecision(idx, dir, "MSS_REJECTED", mssRejectReason, 0);
         }
      }
      
      // Kiểm tra xem đã đủ Evidence chưa
      if(IsEvidenceReady(idx, dir))
      {
         G_Pairs[idx].state_machine = STATE_RETEST;
         G_Pairs[idx].retest_bar_count = 0;
         G_Pairs[idx].rev_status = "EVIDENCE_READY_FOR_RETEST";
         LogReversalDecision(idx, dir, "EVIDENCE_READY", "All evidence gathered", CalculateReversalScore(idx, dir));
      }
      else
      {
         G_Pairs[idx].rev_status = "ACCUMULATING";
      }
   }
   
   // === STATE 6: RETEST ===
   if(G_Pairs[idx].state_machine == STATE_RETEST)
   {
      if(InpRequireRetest && InpEnableRetest)
      {
         bool retested = DetectRetest(sym, ltf, dir, G_Pairs[idx].mss_break_level,
                                      G_Pairs[idx].retest_bar_count);
         
         if(retested)
         {
            G_Pairs[idx].conf_retest = true;
            G_Pairs[idx].state_machine = STATE_ENTRY_READY;
            G_Pairs[idx].rev_status = "RETEST OK";
            LogReversalDecision(idx, dir, "RETEST", "Retest confirmed", 0);
         }
         else if(G_Pairs[idx].retest_bar_count > InpRetestMaxBars)
         {
            // Retest timeout BẮT BUỘC (Fix #4)
            LogReversalDecision(idx, dir, "RETEST_TIMEOUT", "Retest timeout, rejecting", 0);
            ResetReversalSetup(idx, "RETEST_TIMEOUT");
            return 0;
         }
         else
         {
            G_Pairs[idx].rev_status = "WAIT_RETEST";
         }
      }
      else
      {
         G_Pairs[idx].state_machine = STATE_ENTRY_READY;
         G_Pairs[idx].rev_status = "RETEST SKIP";
      }
   }
   
   // === STATE 7: ENTRY_READY (Final Gate) ===
   if(G_Pairs[idx].state_machine == STATE_ENTRY_READY)
   {
      double score = CalculateReversalScore(idx, dir);
      string rejectReason = "";
      bool hardPass = ValidateHardRequirements(idx, dir, rejectReason);
      
      if(hardPass)
      {
         G_Pairs[idx].rev_status = "TRIGGER";
         LogReversalDecision(idx, dir, "ENTRY_READY", "All Gates Passed", score);
         
         int result = dir;
         ResetReversalSetup(idx, "Entry Triggered - Reset");
         return result;
      }
      else
      {
         if(rejectReason == "DXY_CONFLICT")
         {
            LogReversalDecision(idx, dir, "REJECT", rejectReason, score);
            ResetReversalSetup(idx, rejectReason);
            return 0;
         }
         else if(rejectReason == "DXY_NOT_READY")
         {
            G_Pairs[idx].rev_status = "WAIT_DXY";
         }
         else
         {
            // Evidence timeout can make hardPass false again
            LogReversalDecision(idx, dir, "REJECT", rejectReason, score);
            G_Pairs[idx].state_machine = STATE_HTF_LOCATION; // Go back to accumulating
            G_Pairs[idx].rev_status = "RE-ACCUMULATING: " + rejectReason;
         }
      }
   }
   return 0;
}
