//+------------------------------------------------------------------+
//|                                                 Indicators.mqh   |
//|                                                  Yoogi Trading   |
//|   Bộ chỉ báo (v14.0 - MTF Dual Signal: HTF + LTF)               |
//+------------------------------------------------------------------+
#property strict

// ==================================================================
// HẰNG SỐ CHỈ BÁO
// ==================================================================
const int    CCI_LEN     = 20;
const int    CCI_OB      = 100;
const int    CCI_OS      = -100;
const double SENSITIVITY = 2.6;
const int    CCI_PERIOD  = 20;

// ==================================================================
// KHỞI TẠO / HỦY CHỈ BÁO
// ==================================================================
void InitIndicators()
{
   // --- PAIRS: 2 CCI handles per pair (HTF + LTF) ---
   for(int i=0; i<TOTAL_PAIRS; i++)
   {
      // LTF CCI (Entry)
      G_Pairs[i].handle_cci = iCCI(G_Pairs[i].symbol, G_Pairs[i].ltf, CCI_LEN, PRICE_CLOSE);
      if(G_Pairs[i].handle_cci == INVALID_HANDLE)
         PrintFormat("Lỗi: Không tạo được CCI LTF cho %s (%s).", G_Pairs[i].symbol, EnumToString(G_Pairs[i].ltf));

      // HTF CCI (Xu hướng)
      G_Pairs[i].htf_handle_cci = iCCI(G_Pairs[i].symbol, G_Pairs[i].htf, CCI_LEN, PRICE_CLOSE);
      if(G_Pairs[i].htf_handle_cci == INVALID_HANDLE)
         PrintFormat("Lỗi: Không tạo được CCI HTF cho %s (%s).", G_Pairs[i].symbol, EnumToString(G_Pairs[i].htf));
      else
         PrintFormat("   + Pair Indi Ready: %s (HTF: %s / LTF: %s)", G_Pairs[i].symbol, EnumToString(G_Pairs[i].htf), EnumToString(G_Pairs[i].ltf));
   }

   // --- DXY: Dual TF CCI handles ---
   if(g_dxy_available)
   {
      for(int d=0; d<DXY_CONTEXTS; d++)
      {
         // DXY HTF
         G_DXY_HTF[d].handle_cci = iCCI(G_DXY_HTF[d].symbol, G_DXY_HTF[d].ltf, CCI_LEN, PRICE_CLOSE);
         if(G_DXY_HTF[d].handle_cci == INVALID_HANDLE)
            PrintFormat("Loi: Khong tao duoc CCI cho DXY HTF %s.", EnumToString(G_DXY_HTF[d].ltf));
         else
            PrintFormat("   + DXY HTF Indi Ready: %s (%s)", G_DXY_HTF[d].symbol, EnumToString(G_DXY_HTF[d].ltf));

         // DXY LTF
         G_DXY_LTF[d].handle_cci = iCCI(G_DXY_LTF[d].symbol, G_DXY_LTF[d].ltf, CCI_LEN, PRICE_CLOSE);
         if(G_DXY_LTF[d].handle_cci == INVALID_HANDLE)
            PrintFormat("Loi: Khong tao duoc CCI cho DXY LTF %s.", EnumToString(G_DXY_LTF[d].ltf));
         else
            PrintFormat("   + DXY LTF Indi Ready: %s (%s)", G_DXY_LTF[d].symbol, EnumToString(G_DXY_LTF[d].ltf));
      }
   }
}

void DeinitIndicators()
{
   for(int i=0; i<TOTAL_PAIRS; i++)
   {
      if(G_Pairs[i].handle_cci != INVALID_HANDLE) IndicatorRelease(G_Pairs[i].handle_cci);
      if(G_Pairs[i].htf_handle_cci != INVALID_HANDLE) IndicatorRelease(G_Pairs[i].htf_handle_cci);
   }
   for(int d=0; d<DXY_CONTEXTS; d++)
   {
      if(G_DXY_HTF[d].handle_cci != INVALID_HANDLE) IndicatorRelease(G_DXY_HTF[d].handle_cci);
      if(G_DXY_LTF[d].handle_cci != INVALID_HANDLE) IndicatorRelease(G_DXY_LTF[d].handle_cci);
   }
}

// ==================================================================
// HÀM TÍNH TOÁN CHUNG (EMA, Range Filter)
// ==================================================================
bool EMA_OnSeries(const double &src[], int size, int period, double &result[])
{
   if(size < period) return false;
   ArrayResize(result, size);
   ArraySetAsSeries(result, true);
   double k = 2.0 / (period + 1);
   result[size-1] = src[size-1];
   for(int i = size-2; i >= 0; --i)
      result[i] = src[i] * k + result[i+1] * (1 - k);
   return true;
}

// --- Generic SmoothRng: Nhận symbol + timeframe trực tiếp ---
double CalculateSmoothRng_Generic(string sym, ENUM_TIMEFRAMES tf, int period, double multiplier, int for_shift)
{
   int t    = period;
   int wper = t * 2 - 1;
   int need = wper + t + 5;

   double close_prices[];
   if(CopyClose(sym, tf, for_shift, need, close_prices) < need) return 0.0;
   ArraySetAsSeries(close_prices, true);

   int n = ArraySize(close_prices);
   if(n < 2) return 0.0;

   double abs_diff[];
   ArrayResize(abs_diff, n-1);
   for(int i=0; i<n-1; ++i)
      abs_diff[i] = MathAbs(close_prices[i] - close_prices[i+1]);
   ArraySetAsSeries(abs_diff, true);

   double ema1[];
   if(!EMA_OnSeries(abs_diff, ArraySize(abs_diff), t, ema1)) return 0.0;

   double ema2[];
   if(!EMA_OnSeries(ema1, ArraySize(ema1), wper, ema2)) return 0.0;

   return ema2[0] * multiplier;
}

// --- Wrapper cho Pair LTF (tương thích code cũ) ---
double CalculateSmoothRng_Multi(int period, double multiplier, int for_shift, int idx)
{
   return CalculateSmoothRng_Generic(G_Pairs[idx].symbol, G_Pairs[idx].ltf, period, multiplier, for_shift);
}

// --- Wrapper cho Pair HTF ---
double CalculateSmoothRng_HTF(int period, double multiplier, int for_shift, int idx)
{
   return CalculateSmoothRng_Generic(G_Pairs[idx].symbol, G_Pairs[idx].htf, period, multiplier, for_shift);
}

double CalculateRngFilt(double price, double r, double prev)
{
   double nf = prev;
   if(price > prev) nf = (price - r < prev) ? prev : (price - r);
   else             nf = (price + r > prev) ? prev : (price + r);
   return nf;
}

// ==================================================================
// HỖ TRỢ ĐỌC DỮ LIỆU
// ==================================================================
bool ReadCCI_2Bars(int handle, double &cci_curr, double &cci_prev)
{
   double cci[2];
   if(handle == INVALID_HANDLE || CopyBuffer(handle, 0, 1, 2, cci) < 2) return false;
   ArraySetAsSeries(cci, true);
   cci_curr = cci[0];
   cci_prev = cci[1];
   return true;
}

// --- Generic ReadClose_3Bars ---
bool ReadClose_3Bars_Generic(string sym, ENUM_TIMEFRAMES tf, double &c0, double &c1, double &c2)
{
   double cbuf[3];
   if(CopyClose(sym, tf, 1, 3, cbuf) < 3) return false;
   ArraySetAsSeries(cbuf, true);
   c0 = cbuf[0];
   c1 = cbuf[1];
   c2 = cbuf[2];
   return true;
}

// --- Wrapper cho Pair LTF ---
bool ReadClose_3Bars_Multi(int idx, double &c0, double &c1, double &c2)
{
   return ReadClose_3Bars_Generic(G_Pairs[idx].symbol, G_Pairs[idx].ltf, c0, c1, c2);
}

// --- Wrapper cho Pair HTF ---
bool ReadClose_3Bars_HTF(int idx, double &c0, double &c1, double &c2)
{
   return ReadClose_3Bars_Generic(G_Pairs[idx].symbol, G_Pairs[idx].htf, c0, c1, c2);
}

// ==================================================================
// HỖ TRỢ ĐỌC DỮ LIỆU BỔ SUNG (REVERSAL ENGINE)
// ==================================================================
double CalculateATR_Generic(string sym, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iATR(sym, tf, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[1];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) { IndicatorRelease(handle); return 0.0; }
   IndicatorRelease(handle);
   return buf[0];
}

double CalculateEMA_Generic(string sym, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iMA(sym, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[1];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) { IndicatorRelease(handle); return 0.0; }
   IndicatorRelease(handle);
   return buf[0];
}

bool ReadHighLow_Generic(string sym, ENUM_TIMEFRAMES tf, int shift, int count, double &highs[], double &lows[])
{
   if(CopyHigh(sym, tf, shift, count, highs) < count) return false;
   if(CopyLow(sym, tf, shift, count, lows) < count) return false;
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   return true;
}

// ==================================================================
// NEW BAR DETECTION
// ==================================================================
bool IsNewBar_Multi(int idx)
{
   datetime tm[];
   if(CopyTime(G_Pairs[idx].symbol, G_Pairs[idx].ltf, 0, 1, tm) < 1) return false;
   if(tm[0] != G_Pairs[idx].last_bar_time)
   {
      G_Pairs[idx].last_bar_time = tm[0];
      return true;
   }
   return false;
}

bool IsNewBar_HTF(int idx)
{
   datetime tm[];
   if(CopyTime(G_Pairs[idx].symbol, G_Pairs[idx].htf, 0, 1, tm) < 1) return false;
   if(tm[0] != G_Pairs[idx].htf_last_bar_time)
   {
      G_Pairs[idx].htf_last_bar_time = tm[0];
      return true;
   }
   return false;
}

// ==================================================================
// TÍN HIỆU LTF (LOGIC GỐC - ENTRY)
// ==================================================================
int CheckEntrySignal(int idx)
{
   // 1. CHECK NEW BAR trên LTF
   if(!IsNewBar_Multi(idx)) return 0;

   // 2. ĐỌC DỮ LIỆU TỪ HANDLE CCI LTF
   double cci_val=0, cci_prev=0;
   if(!ReadCCI_2Bars(G_Pairs[idx].handle_cci, cci_val, cci_prev)) return 0;

   // 3. ĐỌC GIÁ CLOSE LTF
   double source=0, source_prev=0, source_prev2=0;
   if(!ReadClose_3Bars_Multi(idx, source, source_prev, source_prev2)) return 0;

   // Logic CCI Trap
   if(cci_prev <= CCI_OS && cci_val > CCI_OS)
   { 
      G_Pairs[idx].isReadyForBuy  = true;  
      G_Pairs[idx].isReadyForSell = false; 
   }
   if(cci_prev >= CCI_OB && cci_val < CCI_OB)
   { 
      G_Pairs[idx].isReadyForSell = true;  
      G_Pairs[idx].isReadyForBuy  = false; 
   }

   // 4. TÍNH RANGE FILTER LTF
   double s1 = CalculateSmoothRng_Multi(27, 1.5, 1, idx);
   double s2 = CalculateSmoothRng_Multi(55, SENSITIVITY, 1, idx);

   if(s1<=0.0 || s2<=0.0) return 0;

   double sr = (s1 + s2) / 2.0;

   // Khởi tạo Filt
   if(!G_Pairs[idx].g_inited_filt)
   {
      G_Pairs[idx].filt_prev          = source;
      G_Pairs[idx].filt_prev_for_calc = source_prev;
      G_Pairs[idx].upCount = 0;
      G_Pairs[idx].dnCount = 0;
      G_Pairs[idx].lastCond = 0;
      G_Pairs[idx].g_inited_filt = true;
   }

   double prev_filt = G_Pairs[idx].filt_prev;
   double prev_calc = G_Pairs[idx].filt_prev_for_calc;

   double f_curr = CalculateRngFilt(source,      sr, prev_filt);
   double f_prev = CalculateRngFilt(source_prev, sr, prev_calc);

   G_Pairs[idx].filt_prev          = f_curr;
   G_Pairs[idx].filt_prev_for_calc = f_prev;

   if(f_curr > f_prev){ G_Pairs[idx].upCount++; G_Pairs[idx].dnCount=0; }
   else if(f_curr < f_prev){ G_Pairs[idx].dnCount++; G_Pairs[idx].upCount=0; }

   bool bull = (source > f_curr) && (G_Pairs[idx].upCount > 0);
   bool bear = (source < f_curr) && (G_Pairs[idx].dnCount > 0);

   int lastp = G_Pairs[idx].lastCond;
   
   if(bull)      G_Pairs[idx].lastCond = 1;
   else if(bear) G_Pairs[idx].lastCond = -1;

   bool bullSignalBase = bull && (lastp == -1);
   bool bearSignalBase = bear && (lastp ==  1);

   // Kết hợp điều kiện
   if(G_Pairs[idx].isReadyForBuy  && bullSignalBase)
   { 
      G_Pairs[idx].isReadyForBuy=false;  
      return  1; 
   }
   if(G_Pairs[idx].isReadyForSell && bearSignalBase)
   { 
      G_Pairs[idx].isReadyForSell=false; 
      return -1; 
   }

   return 0;
}

// ==================================================================
// TÍN HIỆU HTF (XU HƯỚNG - LOGIC TƯƠNG TỰ TRÊN TF LỚN)
// ==================================================================
int CheckEntrySignal_HTF(int idx)
{
   // 1. CHECK NEW BAR trên HTF
   if(!IsNewBar_HTF(idx)) return 0;

   // 2. ĐỌC DỮ LIỆU TỪ HANDLE CCI HTF
   double cci_val=0, cci_prev=0;
   if(!ReadCCI_2Bars(G_Pairs[idx].htf_handle_cci, cci_val, cci_prev)) return 0;

   // 3. ĐỌC GIÁ CLOSE HTF
   double source=0, source_prev=0, source_prev2=0;
   if(!ReadClose_3Bars_HTF(idx, source, source_prev, source_prev2)) return 0;

   // Logic CCI Trap HTF
   if(cci_prev <= CCI_OS && cci_val > CCI_OS)
   { 
      G_Pairs[idx].htf_isReadyForBuy  = true;  
      G_Pairs[idx].htf_isReadyForSell = false; 
   }
   if(cci_prev >= CCI_OB && cci_val < CCI_OB)
   { 
      G_Pairs[idx].htf_isReadyForSell = true;  
      G_Pairs[idx].htf_isReadyForBuy  = false; 
   }

   // 4. TÍNH RANGE FILTER HTF
   double s1 = CalculateSmoothRng_HTF(27, 1.5, 1, idx);
   double s2 = CalculateSmoothRng_HTF(55, SENSITIVITY, 1, idx);

   if(s1<=0.0 || s2<=0.0) return 0;

   double sr = (s1 + s2) / 2.0;

   // Khởi tạo Filt HTF
   if(!G_Pairs[idx].htf_g_inited_filt)
   {
      G_Pairs[idx].htf_filt_prev          = source;
      G_Pairs[idx].htf_filt_prev_for_calc = source_prev;
      G_Pairs[idx].htf_upCount = 0;
      G_Pairs[idx].htf_dnCount = 0;
      G_Pairs[idx].htf_lastCond = 0;
      G_Pairs[idx].htf_g_inited_filt = true;
   }

   double prev_filt = G_Pairs[idx].htf_filt_prev;
   double prev_calc = G_Pairs[idx].htf_filt_prev_for_calc;

   double f_curr = CalculateRngFilt(source,      sr, prev_filt);
   double f_prev = CalculateRngFilt(source_prev, sr, prev_calc);

   G_Pairs[idx].htf_filt_prev          = f_curr;
   G_Pairs[idx].htf_filt_prev_for_calc = f_prev;

   if(f_curr > f_prev){ G_Pairs[idx].htf_upCount++; G_Pairs[idx].htf_dnCount=0; }
   else if(f_curr < f_prev){ G_Pairs[idx].htf_dnCount++; G_Pairs[idx].htf_upCount=0; }

   bool bull = (source > f_curr) && (G_Pairs[idx].htf_upCount > 0);
   bool bear = (source < f_curr) && (G_Pairs[idx].htf_dnCount > 0);

   int lastp = G_Pairs[idx].htf_lastCond;
   
   if(bull)      G_Pairs[idx].htf_lastCond = 1;
   else if(bear) G_Pairs[idx].htf_lastCond = -1;

   bool bullSignalBase = bull && (lastp == -1);
   bool bearSignalBase = bear && (lastp ==  1);

   // Kết hợp điều kiện HTF
   if(G_Pairs[idx].htf_isReadyForBuy  && bullSignalBase)
   { 
      G_Pairs[idx].htf_isReadyForBuy=false;  
      return  1; 
   }
   if(G_Pairs[idx].htf_isReadyForSell && bearSignalBase)
   { 
      G_Pairs[idx].htf_isReadyForSell=false; 
      return -1; 
   }

   return 0;
}

// ==================================================================
// TÍN HIỆU DXY - GENERIC (Dùng cho cả HTF và LTF)
// ==================================================================
bool IsNewBar_DXY_Ctx(PairContext &ctx)
{
   datetime tm[];
   if(CopyTime(ctx.symbol, ctx.ltf, 0, 1, tm) < 1) return false;
   if(tm[0] != ctx.last_bar_time)
   {
      ctx.last_bar_time = tm[0];
      return true;
   }
   return false;
}

bool ReadClose_3Bars_DXY_Ctx(PairContext &ctx, double &c0, double &c1, double &c2)
{
   return ReadClose_3Bars_Generic(ctx.symbol, ctx.ltf, c0, c1, c2);
}

double CalculateSmoothRng_DXY_Ctx(PairContext &ctx, int period, double multiplier, int for_shift)
{
   return CalculateSmoothRng_Generic(ctx.symbol, ctx.ltf, period, multiplier, for_shift);
}

int CheckEntrySignal_DXY_Ctx(PairContext &ctx)
{
   if(!IsNewBar_DXY_Ctx(ctx)) return 0;

   double cci_val=0, cci_prev=0;
   if(!ReadCCI_2Bars(ctx.handle_cci, cci_val, cci_prev)) return 0;

   double source=0, source_prev=0, source_prev2=0;
   if(!ReadClose_3Bars_DXY_Ctx(ctx, source, source_prev, source_prev2)) return 0;

   // CCI Trap
   if(cci_prev <= CCI_OS && cci_val > CCI_OS)
   {
      ctx.isReadyForBuy  = true;
      ctx.isReadyForSell = false;
   }
   if(cci_prev >= CCI_OB && cci_val < CCI_OB)
   {
      ctx.isReadyForSell = true;
      ctx.isReadyForBuy  = false;
   }

   // Range Filter
   double s1 = CalculateSmoothRng_DXY_Ctx(ctx, 27, 1.5, 1);
   double s2 = CalculateSmoothRng_DXY_Ctx(ctx, 55, SENSITIVITY, 1);
   if(s1<=0.0 || s2<=0.0) return 0;
   double sr = (s1 + s2) / 2.0;

   if(!ctx.g_inited_filt)
   {
      ctx.filt_prev          = source;
      ctx.filt_prev_for_calc = source_prev;
      ctx.upCount = 0;
      ctx.dnCount = 0;
      ctx.lastCond = 0;
      ctx.g_inited_filt = true;
   }

   double prev_filt = ctx.filt_prev;
   double prev_calc = ctx.filt_prev_for_calc;
   double f_curr = CalculateRngFilt(source,      sr, prev_filt);
   double f_prev = CalculateRngFilt(source_prev, sr, prev_calc);

   ctx.filt_prev          = f_curr;
   ctx.filt_prev_for_calc = f_prev;

   if(f_curr > f_prev){ ctx.upCount++; ctx.dnCount=0; }
   else if(f_curr < f_prev){ ctx.dnCount++; ctx.upCount=0; }

   bool bull = (source > f_curr) && (ctx.upCount > 0);
   bool bear = (source < f_curr) && (ctx.dnCount > 0);

   int lastp = ctx.lastCond;
   if(bull)      ctx.lastCond = 1;
   else if(bear) ctx.lastCond = -1;

   bool bullSignalBase = bull && (lastp == -1);
   bool bearSignalBase = bear && (lastp ==  1);

   if(ctx.isReadyForBuy  && bullSignalBase)
   {
      ctx.isReadyForBuy=false;
      return  1;
   }
   if(ctx.isReadyForSell && bearSignalBase)
   {
      ctx.isReadyForSell=false;
      return -1;
   }

   return 0;
}

// --- Convenience wrappers ---
int CheckEntrySignal_DXY_HTF(int dxy_idx)
{
   if(dxy_idx < 0 || dxy_idx >= DXY_CONTEXTS) return 0;
   return CheckEntrySignal_DXY_Ctx(G_DXY_HTF[dxy_idx]);
}

int CheckEntrySignal_DXY_LTF(int dxy_idx)
{
   if(dxy_idx < 0 || dxy_idx >= DXY_CONTEXTS) return 0;
   return CheckEntrySignal_DXY_Ctx(G_DXY_LTF[dxy_idx]);
}
//+------------------------------------------------------------------+
