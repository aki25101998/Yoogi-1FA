//+------------------------------------------------------------------+
//|                                          DynamicExitEngine.mqh   |
//|                                                  Yoogi Trading   |
//|   Dynamic Exit / Take Profit Engine                              |
//|   - ATR-based TP                                                 |
//|   - Structure Target TP                                          |
//|   - Available Space TP                                           |
//|   - Momentum Adaptation                                          |
//|   - TP Compression                                               |
//|   - Runner Mode (FT only)                                        |
//+------------------------------------------------------------------+
#property strict

// ==================================================================
// STRATEGY TYPE CONSTANTS
// ==================================================================
#define STRATEGY_CT     1   // Counter-Trend
#define STRATEGY_FT     2   // Following-Trend
#define STRATEGY_DUAL   3   // CT + FT confirmed

// ==================================================================
// MOMENTUM STATE CONSTANTS
// ==================================================================
#define MOM_STRONG      1
#define MOM_NEUTRAL     0
#define MOM_WEAK       -1

// ==================================================================
// TRADE PROFILE — Stores Dynamic Exit state per pair
// ==================================================================
struct TradeProfile
{
   int    strategy_type;       // STRATEGY_CT / STRATEGY_FT / STRATEGY_DUAL
   int    direction;           // 1=BUY, -1=SELL
   double entry_price;         // Master entry price (or basket average)
   double initial_atr;         // ATR(14) M15 at trade open
   double initial_dynamic_tp;  // Initial TP in pips (before compression)
   double current_dynamic_tp;  // Current TP in pips (after compression)
   double tp_price;            // Absolute TP price level

   // TP Candidate Values (for logging/debug)
   double atr_target_pips;     // ATR-based target
   double structure_target_pips; // Structure-based target
   double available_space_pips;  // Available space
   int    momentum_state;      // MOM_STRONG / MOM_NEUTRAL / MOM_WEAK

   // Runner Mode
   bool   runner_active;       // Runner mode activated?
   double runner_trail_price;  // Trailing stop price for Runner

   // Compression
   bool   compression_active;  // Compression has occurred?
   double last_compression_tp; // Last compressed TP (anti-jitter)
   datetime last_update_time;  // Last Dynamic Exit update time

   // State
   bool   is_valid;            // Profile initialized?
};

TradeProfile G_TradeProfile[TOTAL_PAIRS];

// ==================================================================
// HELPER: Determine strategy type from entry_mode string
// ==================================================================
int GetStrategyType(string entry_mode)
{
   if(entry_mode == "CT")    return STRATEGY_CT;
   if(entry_mode == "TF")    return STRATEGY_FT;
   if(entry_mode == "CT+TF") return STRATEGY_DUAL;
   return STRATEGY_CT; // Default fallback
}

// ==================================================================
// HELPER: Convert pips to price distance
// ==================================================================
double PipsToPrice(int idx, double pips)
{
   return pips * G_Pairs[idx].pip_value;
}

// ==================================================================
// HELPER: Convert price distance to pips
// ==================================================================
double PriceToPips(int idx, double price_distance)
{
   if(G_Pairs[idx].pip_value <= 0.0) return 0.0;
   return price_distance / G_Pairs[idx].pip_value;
}

// ==================================================================
// TP CANDIDATE 1: ATR TARGET
// ==================================================================
// Uses ATR(14) on M15 timeframe × multiplier, scaled by strategy type
double CalcATRTarget(int idx)
{
   string sym = G_Pairs[idx].symbol;

   // Use M15 ATR for better stability than M5
   double atr = CalculateATR_Generic(sym, PERIOD_M15, InpReversal_ATR_Period, 1);
   if(atr <= 0.0) return 0.0;

   double base_target = atr * InpDynamicTP_ATRMultiplier;

   // Scale by strategy type
   int st = G_TradeProfile[idx].strategy_type;
   if(st == STRATEGY_CT)
      base_target *= 0.8;  // CT: more conservative
   else if(st == STRATEGY_FT)
      base_target *= 1.2;  // FT: more aggressive
   // DUAL: use base (1.0)

   // Convert to pips
   double pips = PriceToPips(idx, base_target);
   return pips;
}

// ==================================================================
// TP CANDIDATE 2: STRUCTURE TARGET
// ==================================================================
// Find nearest swing high/low in trade direction on M15
double CalcStructureTarget(int idx)
{
   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double entry = G_TradeProfile[idx].entry_price;
   if(entry <= 0.0) return 0.0;

   double highs[], lows[];
   int lookback = 50;
   if(!ReadHighLow_Generic(sym, PERIOD_M15, 1, lookback, highs, lows))
      return 0.0;

   int left = InpReversal_SwingLeft;
   int right = InpReversal_SwingRight;
   double min_distance = PipsToPrice(idx, 10.0); // At least 10 pips away

   if(direction == 1) // BUY → look for resistance (swing highs above entry)
   {
      double nearest = 0.0;
      for(int i = right; i < lookback - left; i++)
      {
         if(IsSwingHigh(highs, i, left, right, lookback))
         {
            if(highs[i] > entry + min_distance)
            {
               if(nearest == 0.0 || highs[i] < nearest)
                  nearest = highs[i]; // Closest swing high above entry
            }
         }
      }
      if(nearest > 0.0)
         return PriceToPips(idx, nearest - entry);
   }
   else if(direction == -1) // SELL → look for support (swing lows below entry)
   {
      double nearest = 0.0;
      for(int i = right; i < lookback - left; i++)
      {
         if(IsSwingLow(lows, i, left, right, lookback))
         {
            if(lows[i] < entry - min_distance)
            {
               if(nearest == 0.0 || lows[i] > nearest)
                  nearest = lows[i]; // Closest swing low below entry
            }
         }
      }
      if(nearest > 0.0)
         return PriceToPips(idx, entry - nearest);
   }

   return 0.0; // No valid structure target found
}

// ==================================================================
// TP CANDIDATE 3: AVAILABLE SPACE
// ==================================================================
// Distance to nearest major obstacle (EMA50, strong swing level)
double CalcAvailableSpace(int idx)
{
   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double entry = G_TradeProfile[idx].entry_price;
   if(entry <= 0.0) return 0.0;

   double ema50 = CalculateEMA_Generic(sym, PERIOD_M15, 50, 1);
   if(ema50 <= 0.0) return 0.0;

   double space = 0.0;

   if(direction == 1) // BUY
   {
      // If EMA50 is above entry = resistance ahead
      if(ema50 > entry)
         space = ema50 - entry;
      else
         space = 99999.0; // EMA50 below, no immediate resistance from EMA
   }
   else if(direction == -1) // SELL
   {
      // If EMA50 is below entry = support ahead
      if(ema50 < entry)
         space = entry - ema50;
      else
         space = 99999.0; // EMA50 above, no immediate support from EMA
   }

   // Also check H1 EMA50 as a stronger level
   double ema50_h1 = CalculateEMA_Generic(sym, PERIOD_H1, 50, 1);
   if(ema50_h1 > 0.0)
   {
      double h1_space = 99999.0;
      if(direction == 1 && ema50_h1 > entry)
         h1_space = ema50_h1 - entry;
      else if(direction == -1 && ema50_h1 < entry)
         h1_space = entry - ema50_h1;

      if(h1_space < space)
         space = h1_space;
   }

   if(space >= 99999.0)
      return 0.0; // No obstacle found → don't use available space as limiter

   return PriceToPips(idx, space);
}

// ==================================================================
// TP CANDIDATE 4: MOMENTUM STATE
// ==================================================================
// Reuse existing CCI + Range Filter momentum data
int CalcMomentumState(int idx)
{
   int direction = G_TradeProfile[idx].direction;

   int cci_status = 0, rf_status = 0;
   datetime cci_time = 0, rf_time = 0;
   CheckMomentumStatus(idx, cci_status, rf_status, cci_time, rf_time);

   int aligned = 0;
   if(cci_status == direction) aligned++;
   if(rf_status == direction) aligned++;

   if(aligned >= 2)      return MOM_STRONG;
   else if(aligned == 1) return MOM_NEUTRAL;
   else                  return MOM_WEAK;
}

// ==================================================================
// NATURAL TP CALCULATION
// ==================================================================
double CalculateNaturalTP(int idx, int direction, int strategy_type)
{
   // Store state for logging
   G_TradeProfile[idx].atr_target_pips = CalcATRTarget(idx);
   G_TradeProfile[idx].structure_target_pips = CalcStructureTarget(idx);
   G_TradeProfile[idx].available_space_pips = CalcAvailableSpace(idx);
   G_TradeProfile[idx].momentum_state = CalcMomentumState(idx);

   double atr_tp    = G_TradeProfile[idx].atr_target_pips;
   double struct_tp = G_TradeProfile[idx].structure_target_pips;
   double space_tp  = G_TradeProfile[idx].available_space_pips;
   int    mom_state = G_TradeProfile[idx].momentum_state;

   // --- Momentum Factor ---
   double mom_factor = 1.0;
   if(mom_state == MOM_STRONG)      mom_factor = 1.2;
   else if(mom_state == MOM_NEUTRAL) mom_factor = 1.0;
   else if(mom_state == MOM_WEAK)   mom_factor = 0.8;

   // --- Calculate Base TP ---
   double base_tp = 0.0;

   if(struct_tp > 0.0 && struct_tp >= InpDynamicTP_MinPips && struct_tp <= InpDynamicTP_MaxPips)
   {
      // Structure target is valid and within range
      if(strategy_type == STRATEGY_CT)
      {
         // CT: ưu tiên target thận trọng → lấy MIN
         if(atr_tp > 0.0)
            base_tp = MathMin(struct_tp, atr_tp);
         else
            base_tp = struct_tp;
      }
      else
      {
         // FT/DUAL: weighted average, leaning toward structure
         if(atr_tp > 0.0)
            base_tp = struct_tp * 0.6 + atr_tp * 0.4;
         else
            base_tp = struct_tp;
      }
   }
   else if(atr_tp > 0.0)
   {
      // Fallback: ATR target
      base_tp = atr_tp;
   }
   else
   {
      // Ultimate fallback
      base_tp = (double)InpMasterTPPips;
   }

   // --- Apply Momentum Factor ---
   base_tp = base_tp * mom_factor;

   // --- Available Space Limiter ---
   if(space_tp > 0.0 && base_tp > space_tp * 0.9)
   {
      // Don't place TP beyond 85% of available space
      base_tp = space_tp * 0.85;
   }

   // --- Final Clamp ---
   if(base_tp < InpDynamicTP_MinPips) base_tp = (double)InpDynamicTP_MinPips;
   if(base_tp > InpDynamicTP_MaxPips) base_tp = (double)InpDynamicTP_MaxPips;

   return base_tp;
}

// ==================================================================
// INIT TRADE PROFILE — Called when a new trade is opened
// ==================================================================
void InitTradeProfile(int idx, int direction, int strategy_type, double entry_price, double natural_tp)
{
   G_TradeProfile[idx].strategy_type = strategy_type;
   G_TradeProfile[idx].direction = direction;
   G_TradeProfile[idx].entry_price = entry_price;
   G_TradeProfile[idx].initial_atr = CalculateATR_Generic(G_Pairs[idx].symbol, PERIOD_M15, InpReversal_ATR_Period, 1);

   G_TradeProfile[idx].initial_dynamic_tp = natural_tp;
   G_TradeProfile[idx].current_dynamic_tp = natural_tp;

   // Calculate absolute TP price
   if(direction == 1)
      G_TradeProfile[idx].tp_price = entry_price + PipsToPrice(idx, natural_tp);
   else
      G_TradeProfile[idx].tp_price = entry_price - PipsToPrice(idx, natural_tp);

   // Initialize state
   G_TradeProfile[idx].runner_active = false;
   G_TradeProfile[idx].runner_trail_price = 0.0;
   G_TradeProfile[idx].compression_active = false;
   G_TradeProfile[idx].last_compression_tp = natural_tp;
   G_TradeProfile[idx].last_update_time = TimeCurrent();
   G_TradeProfile[idx].is_valid = true;

   // --- LOG ---
   string sym = G_Pairs[idx].symbol;
   string st_str = (strategy_type == STRATEGY_CT) ? "CT" :
                   (strategy_type == STRATEGY_FT) ? "FT" : "CT+TF";
   string dir_str = (direction == 1) ? "BUY" : "SELL";
   string mom_str = (G_TradeProfile[idx].momentum_state == MOM_STRONG) ? "STRONG" :
                    (G_TradeProfile[idx].momentum_state == MOM_NEUTRAL) ? "NEUTRAL" : "WEAK";

   Print("\n[DYNAMIC-TP]");
   PrintFormat("SYMBOL=%s", sym);
   PrintFormat("Strategy=%s", st_str);
   PrintFormat("Direction=%s", dir_str);
   PrintFormat("Entry=%.5f", entry_price);
   PrintFormat("ATR=%.5f", G_TradeProfile[idx].initial_atr);
   PrintFormat("ATR_Target=%.1f pips", G_TradeProfile[idx].atr_target_pips);
   PrintFormat("StructureTarget=%.1f pips", G_TradeProfile[idx].structure_target_pips);
   PrintFormat("AvailableSpace=%.1f pips", G_TradeProfile[idx].available_space_pips);
   PrintFormat("Momentum=%s", mom_str);
   PrintFormat("NaturalTP=%.1f pips", natural_tp);
   PrintFormat("FinalTP=%.1f pips", natural_tp);
   PrintFormat("TP_Price=%.5f", G_TradeProfile[idx].tp_price);
   PrintFormat("MinTP=%d | MaxTP=%d", InpDynamicTP_MinPips, InpDynamicTP_MaxPips);
}

// ==================================================================
// RESET TRADE PROFILE — Called when trade is closed
// ==================================================================
void ResetTradeProfile(int idx)
{
   G_TradeProfile[idx].is_valid = false;
   G_TradeProfile[idx].strategy_type = 0;
   G_TradeProfile[idx].direction = 0;
   G_TradeProfile[idx].entry_price = 0.0;
   G_TradeProfile[idx].initial_atr = 0.0;
   G_TradeProfile[idx].initial_dynamic_tp = 0.0;
   G_TradeProfile[idx].current_dynamic_tp = 0.0;
   G_TradeProfile[idx].tp_price = 0.0;
   G_TradeProfile[idx].atr_target_pips = 0.0;
   G_TradeProfile[idx].structure_target_pips = 0.0;
   G_TradeProfile[idx].available_space_pips = 0.0;
   G_TradeProfile[idx].momentum_state = MOM_NEUTRAL;
   G_TradeProfile[idx].runner_active = false;
   G_TradeProfile[idx].runner_trail_price = 0.0;
   G_TradeProfile[idx].compression_active = false;
   G_TradeProfile[idx].last_compression_tp = 0.0;
   G_TradeProfile[idx].last_update_time = 0;
}

// ==================================================================
// TP COMPRESSION — Reduce TP when conditions deteriorate
// ==================================================================
// Returns true if TP was compressed
bool TryTPCompression(int idx)
{
   if(!InpEnableTPCompression) return false;
   if(!G_TradeProfile[idx].is_valid) return false;

   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double entry = G_TradeProfile[idx].entry_price;
   double current_tp = G_TradeProfile[idx].current_dynamic_tp;

   // --- Check minimum profit before compression ---
   double current_price = (direction == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                           : SymbolInfoDouble(sym, SYMBOL_ASK);
   double profit_pips = 0.0;
   if(direction == 1)
      profit_pips = PriceToPips(idx, current_price - entry);
   else
      profit_pips = PriceToPips(idx, entry - current_price);

   // Only compress if trade has at least 10 pips profit
   if(profit_pips < 10.0) return false;

   // --- Re-evaluate TP candidates ---
   double new_struct_tp = CalcStructureTarget(idx);
   double new_space_tp  = CalcAvailableSpace(idx);
   int    new_mom_state = CalcMomentumState(idx);

   // --- Determine new TP ---
   double new_tp = current_tp;
   string reason = "";

   // Momentum weakening
   if(new_mom_state == MOM_WEAK && G_TradeProfile[idx].momentum_state != MOM_WEAK)
   {
      new_tp = current_tp * 0.75;
      reason = "MOMENTUM_WEAKENING";
   }

   // Structure target closer than current TP
   if(new_struct_tp > 0.0 && new_struct_tp < current_tp && new_struct_tp >= InpDynamicTP_MinPips)
   {
      if(new_struct_tp < new_tp)
      {
         new_tp = new_struct_tp;
         reason = "STRUCTURE_TARGET_CLOSER";
      }
   }

   // Available space reduced
   if(new_space_tp > 0.0 && new_space_tp * 0.85 < current_tp)
   {
      double space_limited_tp = new_space_tp * 0.85;
      if(space_limited_tp >= InpDynamicTP_MinPips && space_limited_tp < new_tp)
      {
         new_tp = space_limited_tp;
         reason = "AVAILABLE_SPACE_REDUCED";
      }
   }

   // --- Anti-Jitter Checks ---
   // 1. Only compress DOWN, never up
   if(new_tp >= current_tp) return false;

   // 2. Minimum change threshold: at least 5 pips difference
   if(MathAbs(new_tp - G_TradeProfile[idx].last_compression_tp) < 5.0) return false;

   // 3. Rate limit: max once per M5 bar (5 minutes)
   if(TimeCurrent() - G_TradeProfile[idx].last_update_time < 300) return false;

   // --- Clamp ---
   if(new_tp < InpDynamicTP_MinPips) new_tp = (double)InpDynamicTP_MinPips;

   double old_tp = current_tp;
   double new_tp_price = 0.0;
   if(direction == 1)
      new_tp_price = entry + PipsToPrice(idx, new_tp);
   else
      new_tp_price = entry - PipsToPrice(idx, new_tp);



   // --- Apply Compression (Update Internal State) ---
   G_TradeProfile[idx].current_dynamic_tp = new_tp;
   G_TradeProfile[idx].compression_active = true;
   G_TradeProfile[idx].last_compression_tp = new_tp;
   G_TradeProfile[idx].last_update_time = TimeCurrent();
   G_TradeProfile[idx].momentum_state = new_mom_state;
   G_TradeProfile[idx].tp_price = new_tp_price;

   // --- LOG ---
   PrintFormat("\n[DYNAMIC-TP-UPDATE]\nSYMBOL=%s\nStrategy=%s\nMode=BASKET\nOldTP=%.1f\nNewTP=%.1f\nAverageEntry=%.5f\nBasketTP=%.5f\nReason=%s",
               sym, (G_TradeProfile[idx].strategy_type == STRATEGY_CT) ? "CT" : "FT",
               old_tp, new_tp, G_TradeProfile[idx].entry_price, G_TradeProfile[idx].tp_price, reason);

   return true;
}

// ==================================================================
// RUNNER MODE — Keep trade running when trend continues (FT only)
// ==================================================================
bool CheckRunnerConditions(int idx)
{
   if(!InpEnableRunnerMode) return false;
   if(!G_TradeProfile[idx].is_valid) return false;

   // Runner only for FT
   if(G_TradeProfile[idx].strategy_type == STRATEGY_CT) return false;

   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double entry = G_TradeProfile[idx].entry_price;
   double current_tp_pips = G_TradeProfile[idx].current_dynamic_tp;

   // --- Check if trade has reached threshold (80% of initial TP) ---
   double current_price = (direction == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                           : SymbolInfoDouble(sym, SYMBOL_ASK);
   double profit_pips = 0.0;
   if(direction == 1)
      profit_pips = PriceToPips(idx, current_price - entry);
   else
      profit_pips = PriceToPips(idx, entry - current_price);

   double threshold = G_TradeProfile[idx].initial_dynamic_tp * 0.8;
   if(profit_pips < threshold) return false;

   // --- Check momentum still strong ---
   int mom = CalcMomentumState(idx);
   if(mom != MOM_STRONG) return false;

   // --- Check M15 protected structure intact ---
   // For BUY: price must be above M15 protected low
   // For SELL: price must be below M15 protected high
   if(direction == 1 && G_TF[idx].m15_protected_low > 0.0)
   {
      if(current_price < G_TF[idx].m15_protected_low) return false;
   }
   if(direction == -1 && G_TF[idx].m15_protected_high > 0.0)
   {
      if(current_price > G_TF[idx].m15_protected_high) return false;
   }

   return true;
}

void ActivateRunner(int idx)
{
   if(G_TradeProfile[idx].runner_active) return;

   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double atr = CalculateATR_Generic(sym, PERIOD_M15, InpReversal_ATR_Period, 1);
   if(atr <= 0.0) return;

   double current_price = (direction == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                           : SymbolInfoDouble(sym, SYMBOL_ASK);



   if(direction == 1)
   {
      double candidate = current_price - atr * 1.5;
      G_TradeProfile[idx].runner_trail_price = candidate;
   }
   else
   {
      double candidate = current_price + atr * 1.5;
      G_TradeProfile[idx].runner_trail_price = candidate;
   }

   G_TradeProfile[idx].runner_active = true;

   // --- LOG ---
   double profit_pips = (direction == 1) ? PriceToPips(idx, current_price - G_TradeProfile[idx].entry_price)
                                         : PriceToPips(idx, G_TradeProfile[idx].entry_price - current_price);
   double threshold = G_TradeProfile[idx].initial_dynamic_tp * 0.8;
   
   PrintFormat("\n[RUNNER]\nSYMBOL=%s\nStrategy=FT\nInitialTP=%.1f\nThreshold=%.1f\nProfit=%.1f\nMomentum=STRONG\nRunner=ACTIVATED",
               sym, G_TradeProfile[idx].initial_dynamic_tp, threshold, profit_pips);
}

// Update runner trailing stop (move trail only in favor direction)
void UpdateRunnerTrail(int idx)
{
   if(!G_TradeProfile[idx].runner_active) return;

   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double atr = CalculateATR_Generic(sym, PERIOD_M15, InpReversal_ATR_Period, 1);
   if(atr <= 0.0) return;

   double current_price = (direction == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                           : SymbolInfoDouble(sym, SYMBOL_ASK);
   double trail_distance = atr * 1.5;

   bool sl_updated = false;
   double old_trail = G_TradeProfile[idx].runner_trail_price;

   if(direction == 1)
   {
      double new_trail = current_price - trail_distance;
      if(new_trail > G_TradeProfile[idx].runner_trail_price)
      {
         G_TradeProfile[idx].runner_trail_price = new_trail;
         sl_updated = true;
      }
   }
   else
   {
      double new_trail = current_price + trail_distance;
      if(new_trail < G_TradeProfile[idx].runner_trail_price)
      {
         G_TradeProfile[idx].runner_trail_price = new_trail;
         sl_updated = true;
      }
   }
   

}

// Check if runner trailing stop is hit → should exit
bool IsRunnerStopped(int idx)
{
   if(!G_TradeProfile[idx].runner_active) return false;

   string sym = G_Pairs[idx].symbol;
   int direction = G_TradeProfile[idx].direction;
   double current_price = (direction == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                           : SymbolInfoDouble(sym, SYMBOL_ASK);

   if(direction == 1 && current_price <= G_TradeProfile[idx].runner_trail_price)
      return true;
   if(direction == -1 && current_price >= G_TradeProfile[idx].runner_trail_price)
      return true;

   return false;
}

// ==================================================================
// BASKET HELPERS
// ==================================================================

// Calculate weighted average entry price for basket
double CalcBasketAverageEntry(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong chain_id = G_Pairs[idx].active_chain_id;
   if(chain_id == 0) return 0.0;

   double total_price_lot = 0.0;
   double total_lots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym &&
            (ulong)PositionGetInteger(POSITION_MAGIC) == chain_id)
         {
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            double lot   = PositionGetDouble(POSITION_VOLUME);
            total_price_lot += price * lot;
            total_lots += lot;
         }
      }
   }

   if(total_lots <= 0.0) return 0.0;
   return total_price_lot / total_lots;
}

// Get direction from master (oldest) order in basket
int GetBasketDirection(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong chain_id = G_Pairs[idx].active_chain_id;
   if(chain_id == 0) return 0;

   long oldest_time = LONG_MAX;
   int direction = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym &&
            (ulong)PositionGetInteger(POSITION_MAGIC) == chain_id)
         {
            long tt = (long)PositionGetInteger(POSITION_TIME);
            if(tt < oldest_time)
            {
               oldest_time = tt;
               ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
            }
         }
      }
   }
   return direction;
}

// Get basket TP price from average entry + dynamic TP
double GetBasketTPPrice(int idx, double avg_entry, int direction)
{
   if(!G_TradeProfile[idx].is_valid) return 0.0;
   if(avg_entry <= 0.0) return 0.0;

   double tp_distance = PipsToPrice(idx, G_TradeProfile[idx].current_dynamic_tp);

   double tp_price = 0.0;
   if(direction == 1)
      tp_price = avg_entry + tp_distance;
   else if(direction == -1)
      tp_price = avg_entry - tp_distance;

   // --- Failsafe: TP must be on correct side ---
   if(direction == 1 && tp_price <= avg_entry)
   {
      Print("[DYNAMIC-TP-FAILSAFE] BUY TP below avg entry! Using fallback.");
      tp_price = avg_entry + PipsToPrice(idx, InpDynamicTP_MinPips);
   }
   if(direction == -1 && tp_price >= avg_entry)
   {
      Print("[DYNAMIC-TP-FAILSAFE] SELL TP above avg entry! Using fallback.");
      tp_price = avg_entry - PipsToPrice(idx, InpDynamicTP_MinPips);
   }

   return tp_price;
}

// ==================================================================
// UPDATE DYNAMIC EXIT — Called each tick when trade is open
// ==================================================================
void UpdateDynamicExit(int idx)
{
   if(!InpEnableDynamicTP) return;
   if(!G_TradeProfile[idx].is_valid) return;

   // --- Update entry price to basket average if DCA is active ---
   double avg = CalcBasketAverageEntry(idx);
   if(avg > 0.0)
   {
      G_TradeProfile[idx].entry_price = avg;

      // Recalculate absolute TP price from average entry
      int dir = G_TradeProfile[idx].direction;
      double tp_dist = PipsToPrice(idx, G_TradeProfile[idx].current_dynamic_tp);
      if(dir == 1)
         G_TradeProfile[idx].tp_price = avg + tp_dist;
      else
         G_TradeProfile[idx].tp_price = avg - tp_dist;
   }

   // --- Runner Mode (FT only) ---
   if(G_TradeProfile[idx].runner_active)
   {
      UpdateRunnerTrail(idx);
      return; // When runner is active, don't compress
   }

   // Check if should activate runner
   if(CheckRunnerConditions(idx))
   {
      ActivateRunner(idx);
      return;
   }

   // --- TP Compression ---
   TryTPCompression(idx);
}

// ==================================================================
// DYNAMIC TP CHECK — Should we close the trade?
// ==================================================================
// Returns: 0 = hold, 1 = close at TP, 2 = close by runner stop
int CheckDynamicTPHit(int idx, double current_price, int direction)
{
   if(!G_TradeProfile[idx].is_valid) return 0;

   // --- Runner Mode Exit ---
   if(G_TradeProfile[idx].runner_active)
   {
      if(IsRunnerStopped(idx))
      {
         PrintFormat("[DYNAMIC-TP-RUNNER-EXIT] SYMBOL=%s TrailPrice=%.5f CurrentPrice=%.5f",
                     G_Pairs[idx].symbol, G_TradeProfile[idx].runner_trail_price, current_price);
         return 2;
      }
      // In runner mode, don't check normal TP
      return 0;
   }

   // --- Normal TP Check ---
   double tp_price = G_TradeProfile[idx].tp_price;

   if(direction == 1 && current_price >= tp_price)
      return 1;
   if(direction == -1 && current_price <= tp_price)
      return 1;

   return 0;
}

// ==================================================================
// DYNAMIC TP — Get TP pips for single order (DCA OFF mode)
// ==================================================================
double GetDynamicTPPips(int idx)
{
   if(!InpEnableDynamicTP) return (double)InpMasterTPPips;
   if(!G_TradeProfile[idx].is_valid) return (double)InpMasterTPPips;
   return G_TradeProfile[idx].current_dynamic_tp;
}

// ==================================================================
// FALLBACK — Safe TP when Dynamic Engine fails
// ==================================================================
double GetFallbackTP(int idx, int direction, double entry_price)
{
   double fallback_pips = (double)InpMasterTPPips;

   Print("[DYNAMIC-TP-FALLBACK]");
   PrintFormat("SYMBOL=%s", G_Pairs[idx].symbol);
   PrintFormat("Reason=DYNAMIC_ENGINE_FAILED");
   PrintFormat("FallbackTP=%.0f pips", fallback_pips);

   if(direction == 1)
      return entry_price + PipsToPrice(idx, fallback_pips);
   else
      return entry_price - PipsToPrice(idx, fallback_pips);
}

// ==================================================================
// INIT ALL TRADE PROFILES — Called in OnInit
// ==================================================================
void InitAllTradeProfiles()
{
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      ResetTradeProfile(i);
   }
}
//+------------------------------------------------------------------+
