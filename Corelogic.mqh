//+------------------------------------------------------------------+
//|                                                  CoreLogic.mqh   |
//|                                                  Yoogi Trading   |
//|   Logic giao dịch cốt lõi (v14.0 - MTF Dual Signal)             |
//|   (Mode: HTF Trap → LTF Confirm → DXY Dual Convergence)         |
//+------------------------------------------------------------------+
#property strict
#include "Trimming.mqh" // Chứa logic cắt tỉa thông minh đa cặp

// ==================================================================
// HỖ TRỢ CẤP THẤP (MULTI-SYMBOL)
// ==================================================================

// Lấy thông tin lệnh MỚI NHẤT trong chuỗi của một cặp cụ thể
bool GetLastPositionInfo_Multi(int idx, ulong chain_id, double &price, double &lot)
{
   long latest_time = -1;
   price = 0.0; lot = 0.0;
   bool found = false;

   string sym = G_Pairs[idx].symbol;

   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym)
         {
            if(GetPositionMagic(t) == chain_id)
            {
               long tt = (long)PositionGetInteger(POSITION_TIME);
               if(tt > latest_time)
               {
                  latest_time = tt;
                  price = PositionGetDouble(POSITION_PRICE_OPEN);
                  lot   = PositionGetDouble(POSITION_VOLUME);
                  found = true;
               }
            }
         }
      }
   }
   return found;
}

// Mở lệnh con (Dùng Symbol của cặp đang xét)
bool OpenChildOrder_Multi(int idx, ENUM_POSITION_TYPE ptype, double lot, const string comment)
{
   string sym = G_Pairs[idx].symbol;
   if(!IsTradable(sym)) return false;

   trade.SetExpertMagicNumber(G_Pairs[idx].active_chain_id);

   bool res=false;
   double sl = 0.0;
   int sl_pips = 0;

   if(ptype == POSITION_TYPE_BUY)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(sl_pips > 0) sl = price - sl_pips * G_Pairs[idx].pip_value;
      res = trade.Buy(lot, sym, price, sl, 0, comment);
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      if(sl_pips > 0) sl = price + sl_pips * G_Pairs[idx].pip_value;
      res = trade.Sell(lot, sym, price, sl, 0, comment);
   }
   return res;
}

// ==================================================================
// QUẢN LÝ PERSISTENCE (LƯU/TẢI TRẠNG THÁI)
// ==================================================================
void SaveChainState_Multi(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

   if(id == 0) return;

   // Persistent State
   GlobalVariableSet("Yoogi_CT_Debt_" + sym, G_Pairs[idx].ct_realized_bleed_loss);
   GlobalVariableSet("Yoogi_CT_RecLvl_" + sym, (double)G_Pairs[idx].ct_recovery_level);
   GlobalVariableSet("Yoogi_FT_Debt_" + sym, G_Pairs[idx].ft_realized_bleed_loss);
   GlobalVariableSet("Yoogi_FT_RecLvl_" + sym, (double)G_Pairs[idx].ft_recovery_level);
   GlobalVariableSet("Yoogi_DUAL_Debt_" + sym, G_Pairs[idx].dual_realized_bleed_loss);
   GlobalVariableSet("Yoogi_DUAL_RecLvl_" + sym, (double)G_Pairs[idx].dual_recovery_level);
   
   GlobalVariableSet("Yoogi_CT_DCASeq_" + sym, (double)G_Pairs[idx].ct_dca_sequence);
   GlobalVariableSet("Yoogi_FT_DCASeq_" + sym, (double)G_Pairs[idx].ft_dca_sequence);
   GlobalVariableSet("Yoogi_DUAL_DCASeq_" + sym, (double)G_Pairs[idx].dual_dca_sequence);

   // Chain Specific State
   GlobalVariableSet(GetVarName_Step(sym, id),  (double)G_Pairs[idx].chain_dca_count);
   GlobalVariableSet("Yoogi_DCAStep_" + sym + "_" + IntegerToString(id), (double)G_Pairs[idx].chain_step_pips);
   GlobalVariableSet(GetVarName_LockedBal(sym, id), G_Pairs[idx].locked_balance);
   
   int strat_val = 1; // 1: CT
   if(G_Pairs[idx].active_chain_strategy == "FT") strat_val = 2;
   else if(G_Pairs[idx].active_chain_strategy == "DUAL") strat_val = 3;
   GlobalVariableSet("Yoogi_Strat_" + sym + "_" + IntegerToString(id), (double)strat_val);

   if(InpEnableDynamicTP && G_TradeProfile[idx].is_valid)
   {
      SaveTradeProfile(idx, id);
   }
}

void LoadChainState_Multi(int idx, ulong chain_id)
{
   string sym = G_Pairs[idx].symbol;
   
   // Load Persistent State
   if(GlobalVariableCheck("Yoogi_CT_Debt_" + sym)) G_Pairs[idx].ct_realized_bleed_loss = GlobalVariableGet("Yoogi_CT_Debt_" + sym);
   else G_Pairs[idx].ct_realized_bleed_loss = 0.0;
   
   if(GlobalVariableCheck("Yoogi_CT_RecLvl_" + sym)) G_Pairs[idx].ct_recovery_level = (int)GlobalVariableGet("Yoogi_CT_RecLvl_" + sym);
   else G_Pairs[idx].ct_recovery_level = 0;
   
   if(GlobalVariableCheck("Yoogi_FT_Debt_" + sym)) G_Pairs[idx].ft_realized_bleed_loss = GlobalVariableGet("Yoogi_FT_Debt_" + sym);
   else G_Pairs[idx].ft_realized_bleed_loss = 0.0;
   
   if(GlobalVariableCheck("Yoogi_FT_RecLvl_" + sym)) G_Pairs[idx].ft_recovery_level = (int)GlobalVariableGet("Yoogi_FT_RecLvl_" + sym);
   else G_Pairs[idx].ft_recovery_level = 0;
   
   if(GlobalVariableCheck("Yoogi_DUAL_Debt_" + sym)) G_Pairs[idx].dual_realized_bleed_loss = GlobalVariableGet("Yoogi_DUAL_Debt_" + sym);
   else G_Pairs[idx].dual_realized_bleed_loss = 0.0;
   
   if(GlobalVariableCheck("Yoogi_DUAL_RecLvl_" + sym)) G_Pairs[idx].dual_recovery_level = (int)GlobalVariableGet("Yoogi_DUAL_RecLvl_" + sym);
   else G_Pairs[idx].dual_recovery_level = 0;
   
   if(GlobalVariableCheck("Yoogi_CT_DCASeq_" + sym)) G_Pairs[idx].ct_dca_sequence = (int)GlobalVariableGet("Yoogi_CT_DCASeq_" + sym);
   else G_Pairs[idx].ct_dca_sequence = 0;

   if(GlobalVariableCheck("Yoogi_FT_DCASeq_" + sym)) G_Pairs[idx].ft_dca_sequence = (int)GlobalVariableGet("Yoogi_FT_DCASeq_" + sym);
   else G_Pairs[idx].ft_dca_sequence = 0;

   if(GlobalVariableCheck("Yoogi_DUAL_DCASeq_" + sym)) G_Pairs[idx].dual_dca_sequence = (int)GlobalVariableGet("Yoogi_DUAL_DCASeq_" + sym);
   else G_Pairs[idx].dual_dca_sequence = 0;

   // Load Chain Specific State
   string n_step  = GetVarName_Step(sym, chain_id);
   string n_bal   = GetVarName_LockedBal(sym, chain_id);
   string n_dca_step = "Yoogi_DCAStep_" + sym + "_" + IntegerToString(chain_id);

   if(GlobalVariableCheck(n_step))  G_Pairs[idx].chain_dca_count = (int)GlobalVariableGet(n_step);
   else                             G_Pairs[idx].chain_dca_count = 0;

   if(GlobalVariableCheck(n_dca_step)) G_Pairs[idx].chain_step_pips = (int)GlobalVariableGet(n_dca_step);
   else                                G_Pairs[idx].chain_step_pips = InpDCA_MinStepPips;

   string n_strat = "Yoogi_Strat_" + sym + "_" + IntegerToString(chain_id);
   if(GlobalVariableCheck(n_strat)) {
       int sv = (int)GlobalVariableGet(n_strat);
       if(sv == 2) G_Pairs[idx].active_chain_strategy = "FT";
       else if(sv == 3) G_Pairs[idx].active_chain_strategy = "DUAL";
       else G_Pairs[idx].active_chain_strategy = "CT";
   } else {
       G_Pairs[idx].active_chain_strategy = "CT"; // Fallback
   }

   if(GlobalVariableCheck(n_bal))   G_Pairs[idx].locked_balance = GlobalVariableGet(n_bal);
   else                             G_Pairs[idx].locked_balance = 0.0;

   if(InpEnableDynamicTP)
   {
      LoadTradeProfile(idx, chain_id);
   }
}

void ClearChainState_Multi(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

   if(id == 0) return;

   // Only delete chain specific state
   GlobalVariableDel(GetVarName_Step(sym, id));
   GlobalVariableDel("Yoogi_DCAStep_" + sym + "_" + IntegerToString(id));
   GlobalVariableDel(GetVarName_LockedBal(sym, id));
   GlobalVariableDel("Yoogi_Strat_" + sym + "_" + IntegerToString(id));
   ClearTradeProfilePersistence(idx, id);

   // Reset chain specific memory
   G_Pairs[idx].chain_dca_count = 0;
   G_Pairs[idx].chain_step_pips = 0;
   G_Pairs[idx].locked_balance = 0.0;
   G_Pairs[idx].active_chain_id = 0;
   G_Pairs[idx].active_chain_strategy = "";
}

void CloseAndResolveChain(int idx, string reason)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;
   
   if(id == 0) return;

   // 1. Calculate PnL of this chain
   double pnl = 0.0;
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if (t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym && (ulong)PositionGetInteger(POSITION_MAGIC) == id)
         {
            pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
         }
      }
   }

   // 2. Close all positions
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if (t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym && (ulong)PositionGetInteger(POSITION_MAGIC) == id)
         {
            trade.PositionClose(t);
         }
      }
   }
   
   string strat = G_Pairs[idx].active_chain_strategy;
   if(strat == "") strat = "CT";
   
   double debt_before = 0.0;
   int rec_lvl = 0;
   
   if(strat == "CT") {
      debt_before = G_Pairs[idx].ct_realized_bleed_loss;
      rec_lvl = G_Pairs[idx].ct_recovery_level;
   } else if(strat == "FT") {
      debt_before = G_Pairs[idx].ft_realized_bleed_loss;
      rec_lvl = G_Pairs[idx].ft_recovery_level;
   } else if(strat == "DUAL") {
      debt_before = G_Pairs[idx].dual_realized_bleed_loss;
      rec_lvl = G_Pairs[idx].dual_recovery_level;
   }

   // 3. Update Debt and Recovery Level
   if (reason == "MAX_DCA")
   {
       double net_loss = 0.0;
       if(pnl < 0) {
           net_loss = MathAbs(pnl);
           debt_before += net_loss;
           rec_lvl++; // ONLY IF LOSS
           
           if(strat == "CT") { G_Pairs[idx].ct_realized_bleed_loss = debt_before; G_Pairs[idx].ct_recovery_level = rec_lvl; }
           else if(strat == "FT") { G_Pairs[idx].ft_realized_bleed_loss = debt_before; G_Pairs[idx].ft_recovery_level = rec_lvl; }
           else if(strat == "DUAL") { G_Pairs[idx].dual_realized_bleed_loss = debt_before; G_Pairs[idx].dual_recovery_level = rec_lvl; }
           
           PrintFormat("[ RECOVERY-DEBT ]\nSYMBOL=%s\nSTRAT=%s\nCHAIN_RESULT=%.2f\nDEBT_ADDED=%.2f\nDEBT_AFTER=%.2f\nNEXT_RECOVERY_LEVEL=%d",
                       sym, strat, pnl, net_loss, debt_before, rec_lvl);
       }
       else
       {
           PrintFormat("[ RECOVERY-MAX-DCA-NO-DEBT ]\nSYMBOL=%s\nSTRAT=%s\nCHAIN_RESULT=%.2f\nDEBT_ADDED=0\nDEBT_AFTER=%.2f\nRECOVERY_LEVEL_UNCHANGED=%d",
                       sym, strat, pnl, debt_before, rec_lvl);
       }
   }
   else
   {
       // Normal TP or Runner Exit
       debt_before -= pnl;
       
       if (debt_before <= 0)
       {
           debt_before = 0.0;
           rec_lvl = 0; // Reset to Level 1
           
           if(strat == "CT") { G_Pairs[idx].ct_realized_bleed_loss = 0; G_Pairs[idx].ct_recovery_level = 0; }
           else if(strat == "FT") { G_Pairs[idx].ft_realized_bleed_loss = 0; G_Pairs[idx].ft_recovery_level = 0; }
           else if(strat == "DUAL") { G_Pairs[idx].dual_realized_bleed_loss = 0; G_Pairs[idx].dual_recovery_level = 0; }
           
           PrintFormat("[ RECOVERY-COMPLETE ]\nSYMBOL=%s\nSTRAT=%s\nDEBT=0\nRECOVERY_LEVEL_RESET=1", sym, strat);
       }
       else
       {
           if(strat == "CT") { G_Pairs[idx].ct_realized_bleed_loss = debt_before; }
           else if(strat == "FT") { G_Pairs[idx].ft_realized_bleed_loss = debt_before; }
           else if(strat == "DUAL") { G_Pairs[idx].dual_realized_bleed_loss = debt_before; }
           
           // Partially recovered
           PrintFormat("[ RECOVERY-PARTIAL ]\nSYMBOL=%s\nSTRAT=%s\nCHAIN_RESULT=%.2f\nDEBT_REDUCED_TO=%.2f\nREMAINING_RECOVERY_LEVEL=%d",
                       sym, strat, pnl, debt_before, rec_lvl);
       }
   }

   // 4. Save persistent state & clear chain state
   ResetTradeProfile(idx);
   SaveChainState_Multi(idx);
   ClearChainState_Multi(idx);
}

// ==================================================================
// MỞ LỆNH MASTER (TẠO CHUỖI MỚI)
// ==================================================================
void OpenMasterTrade_Multi(int idx, int signal, string entry_mode = "")
{
   string sym = G_Pairs[idx].symbol;

   // Kiểm tra thời gian (tránh spam lệnh)
   static ulong lastOpenTime = 0;
   if(TimeCurrent() - lastOpenTime < 2) return;

   if(!IsTradable(sym)) return;

   ulong new_chain_id = EA_MAGIC_NUMBER * 1000 + idx;
   trade.SetExpertMagicNumber(new_chain_id);

   // --- DYNAMICAL STRATEGY STATE SELECTION ---
   G_Pairs[idx].active_chain_strategy = entry_mode;
   
   int current_rec_lvl = 0;
   double current_debt = 0.0;
   if(entry_mode == "CT") {
      current_rec_lvl = G_Pairs[idx].ct_recovery_level;
      current_debt = G_Pairs[idx].ct_realized_bleed_loss;
   } else if(entry_mode == "FT") {
      current_rec_lvl = G_Pairs[idx].ft_recovery_level;
      current_debt = G_Pairs[idx].ft_realized_bleed_loss;
   } else if(entry_mode == "DUAL") {
      current_rec_lvl = G_Pairs[idx].dual_recovery_level;
      current_debt = G_Pairs[idx].dual_realized_bleed_loss;
   }

   int current_dca_seq = 0;
   if(entry_mode == "CT") current_dca_seq = G_Pairs[idx].ct_dca_sequence;
   else if(entry_mode == "FT") current_dca_seq = G_Pairs[idx].ft_dca_sequence;
   else if(entry_mode == "DUAL") current_dca_seq = G_Pairs[idx].dual_dca_sequence;

   // --- COMMENT VỚI ENTRY MODE ---
   string comment = entry_mode + " | ENTRY";
   
   bool   res     = false;
   double sl=0.0, tp=0.0;

   // --- [LOGIC REAL TIME] TÍNH LOT THEO BALANCE THỰC TẾ HOẶC THỦ CÔNG ---
   double current_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot_calculation_bal = current_bal;

   if(InpSetBalance > 0.0)
   {
      lot_calculation_bal = InpSetBalance;
   }

   // Gọi hàm tính Lot từ Globals (Đã gán cứng Risk%)
   double base_lot = CalculateAutoLot(idx, lot_calculation_bal);
   double initial_lot = NormalizeLot(sym, base_lot * MathPow(InpHeSoLot, current_rec_lvl));

   // --- [QUAN TRỌNG] NẾU LOT = 0 (DO RISK = 0%), DỮNG NGAY ---
   if(initial_lot <= 0.0) return;

   // --- DETERMINE STRATEGY TYPE ---
   int strategy_type = GetStrategyType(entry_mode);

   // --- XAC DINH TP VA SL THEO CHE DO ---
   int sl_pips = 0;
   
   // DCA Mode: SL is 0, TP is 0 on individual orders, managed by basket

   // --- PRE-INIT Trade Profile (needed for Dynamic TP calculation) ---
   // We need to calculate entry price first for the profile
   double entry_price = (signal == 1) ? SymbolInfoDouble(sym, SYMBOL_ASK)
                                      : SymbolInfoDouble(sym, SYMBOL_BID);

   // --- CALCULATE TP ---
   double tp_pips_d = 0.0;
   if(InpEnableDynamicTP)
   {
      // Pre-init profile for TP calculation
      G_TradeProfile[idx].strategy_type = strategy_type;
      G_TradeProfile[idx].direction = signal;
      G_TradeProfile[idx].entry_price = entry_price;
      G_TradeProfile[idx].is_valid = true;
      tp_pips_d = CalculateNaturalTP(idx, signal, strategy_type);
      if(tp_pips_d <= 0.0) tp_pips_d = (double)InpMasterTPPips; // Failsafe
   }
   else
   {
      tp_pips_d = (double)InpMasterTPPips;  // Fixed 60 pip fallback
   }

   if(signal == 1)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_ASK);
      // DCA ON: Don't set TP on individual order — basket manages exit
      tp = 0;
      if(sl_pips > 0) sl = price - sl_pips * G_Pairs[idx].pip_value;
      res = trade.Buy(initial_lot, sym, price, sl, tp, comment);
   }
   else if(signal == -1)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      tp = 0;
      if(sl_pips > 0) sl = price + sl_pips * G_Pairs[idx].pip_value;
      res = trade.Sell(initial_lot, sym, price, sl, tp, comment);
   }

   if(res)
   {
      lastOpenTime = TimeCurrent();

      // Tính toán Dynamic Step
      double atr_val = CalculateATR_Generic(sym, PERIOD_M15, 14, 1);
      int dyn_step = InpDCA_MinStepPips;
      if (atr_val > 0) {
          double atr_pips = atr_val / G_Pairs[idx].pip_value;
          dyn_step = (int)MathRound(atr_pips * InpDCA_Step_ATRMultiplier);
          if(dyn_step < InpDCA_MinStepPips) dyn_step = InpDCA_MinStepPips;
          if(dyn_step > InpDCA_MaxStepPips) dyn_step = InpDCA_MaxStepPips;
      }

      // Cập nhật trạng thái Global cho cặp này
      G_Pairs[idx].active_chain_id = new_chain_id;
      G_Pairs[idx].chain_dca_count = 0;
      G_Pairs[idx].chain_step_pips = dyn_step;

      // Lưu Balance lấy tính Lot làm mốc để DCA sau này
      G_Pairs[idx].locked_balance = lot_calculation_bal;

      PrintFormat("[DCA-CHAIN-START]\nSYMBOL=%s\nRECOVERY_LEVEL=%d\nDYNAMIC_STEP=%d\nATR_M15=%.5f\nMAX_DCA=%d",
                  sym, current_rec_lvl, dyn_step, atr_val, InpMaxDCAPerChain);

      if(current_rec_lvl > 0)
      {
         PrintFormat("[ RECOVERY-ENTRY ]\nSYMBOL=%s\nRECOVERY_LEVEL=%d\nDEBT=%.2f\nLOT=%.2f\nSTEP=%d",
                     sym, current_rec_lvl, current_debt, initial_lot, dyn_step);
      }

      // Reset Reversal Engine sau khi vào lệnh thành công
      G_Pairs[idx].htf_trap_signal = 0;
      G_Pairs[idx].state_machine = STATE_NO_SETUP;
      G_Pairs[idx].setup_direction = 0;
      G_Pairs[idx].rev_status = "NO SETUP";

      // --- INIT DYNAMIC EXIT TRADE PROFILE ---
      if(InpEnableDynamicTP)
      {
         InitTradeProfile(idx, signal, strategy_type, entry_price, tp_pips_d);
      }

      SaveChainState_Multi(idx);

      PrintFormat("[%s] >>> OPEN MASTER [%s]: %.2f lots (Actual Bal: $%.2f, Ref Bal: $%.2f). ID: %I64u",
                  sym, entry_mode, initial_lot, current_bal, lot_calculation_bal, new_chain_id);
                  
      string mode_str = "DCA Mode (ALWAYS ON)";
      string dir_str = (signal == 1) ? "BUY" : "SELL";
      PrintFormat("[ENTRY]\nSYMBOL=%s\nSTRAT=%s\nTYPE=MASTER\nCOMMENT=%s\nRECOVERY_LEVEL=%d\nDCA_SEQUENCE=%d",
                  sym, entry_mode, comment, current_rec_lvl, current_dca_seq);
      PrintFormat("[ENTRY] %s %s\n[MODE] %s\n[ENTRY] Price: %.5f\n[SL] %d pips\n[TP] %.1f pips (Dynamic=%s)",
                  (entry_mode == "FT" ? "Following Trend" : (entry_mode == "CT" ? "Counter Trend" : "Dual Trend")),
                  dir_str, mode_str, entry_price, sl_pips, tp_pips_d, InpEnableDynamicTP ? "YES" : "NO");
   }
}

// ==================================================================
// DCA TREND (MULTI-SYMBOL)
// ==================================================================
void ManageTrendDCA_Multi(int idx, int current_orders, ENUM_POSITION_TYPE master_type)
{

   if(InpMaxDCAPerChain <= 0) return;

   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

   double last_price=0.0, last_lot=0.0;
   if(!GetLastPositionInfo_Multi(idx, id, last_price, last_lot)) return;

   // 1. PHANH KHẨN CẤP
   if(current_orders > InpTrimTriggerOrders + 1)
   {
      ApplySmartTrimming(idx);
      return;
   }

   // 2. Logic Khoảng cách
   int step_pips = G_Pairs[idx].chain_step_pips;
   if(step_pips <= 0) step_pips = InpDCA_MinStepPips; // Fallback an toàn
   double step = step_pips * G_Pairs[idx].pip_value;
   double current_price = (master_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);

   bool enough=false;
   if(master_type==POSITION_TYPE_BUY  && (current_price <= last_price - step)) enough=true;
   if(master_type==POSITION_TYPE_SELL && (current_price >= last_price + step)) enough=true;

   if(enough)
   {
      if(G_Pairs[idx].chain_dca_count >= InpMaxDCAPerChain)
      {
         PrintFormat("[ DCA-LIMIT ]\nSYMBOL=%s\nCHAIN_DCA_COUNT=%d\nMAX_DCA=%d\nACTION=CLOSE_CHAIN", sym, G_Pairs[idx].chain_dca_count, InpMaxDCAPerChain);
         CloseAndResolveChain(idx, "MAX_DCA");
         return;
      }

      int current_dca = G_Pairs[idx].chain_dca_count + 1;
      
      // Select correct recovery level and dca sequence based on strategy
      string strat = G_Pairs[idx].active_chain_strategy;
      if (strat == "") strat = "CT"; // Fallback
      
      int current_rec_lvl = 0;
      int next_dca_seq = 0;
      
      if(strat == "CT") {
         current_rec_lvl = G_Pairs[idx].ct_recovery_level;
         next_dca_seq = G_Pairs[idx].ct_dca_sequence + 1;
      }
      else if(strat == "FT") {
         current_rec_lvl = G_Pairs[idx].ft_recovery_level;
         next_dca_seq = G_Pairs[idx].ft_dca_sequence + 1;
      }
      else if(strat == "DUAL") {
         current_rec_lvl = G_Pairs[idx].dual_recovery_level;
         next_dca_seq = G_Pairs[idx].dual_dca_sequence + 1;
      }

      // 3. Tính Lot (Dùng Locked Balance hoặc Fallback về Actual Balance)
      double working_balance = (G_Pairs[idx].locked_balance > 0) ? G_Pairs[idx].locked_balance : AccountInfoDouble(ACCOUNT_BALANCE);

      if(InpSetBalance > 0.0)
      {
         working_balance = InpSetBalance;
      }

      double base_lot = CalculateAutoLot(idx, working_balance);

      double calculated_lot = base_lot * MathPow(InpHeSoLot, current_rec_lvl);
      double new_lot = NormalizeLot(sym, calculated_lot);

      // 4. Mở lệnh
      string cmt = strat + " | DCA " + IntegerToString(next_dca_seq);
      bool res = OpenChildOrder_Multi(idx, master_type, new_lot, cmt);

      if(res)
      {
         G_Pairs[idx].chain_dca_count = current_dca;
         
         if(strat == "CT") {
            G_Pairs[idx].ct_dca_sequence = next_dca_seq;
         } else if(strat == "FT") {
            G_Pairs[idx].ft_dca_sequence = next_dca_seq;
         } else if(strat == "DUAL") {
            G_Pairs[idx].dual_dca_sequence = next_dca_seq;
         }
         
         SaveChainState_Multi(idx);

         PrintFormat("[DCA-ENTRY]\nSYMBOL=%s\nSTRAT=%s\nDCA_SEQUENCE=%d\nCHAIN_DCA_COUNT=%d\nRECOVERY_LEVEL=%d\nSTEP=%d\nLOT=%.2f", 
                     sym, strat, next_dca_seq, current_dca, current_rec_lvl, step_pips, new_lot);

         ApplySmartTrimming(idx);
      }
   }
}

// ==================================================================
// KIEM TRA HOP LUU DXY DUAL TF (CONVERGENCE CHECK)
// ==================================================================
int CheckDXYConvergence_Dual(int idx)
{
   int di = G_Pairs[idx].dxy_map_index;
   if(di < 0) return 0;

   int mainTrap = G_Pairs[idx].trapSignal;
   int dxyTrapHTF = G_DXY_TrapSignal_HTF[di];
   int dxyTrapLTF = G_DXY_TrapSignal_LTF[di];

   // Neu main trap chua co tin hieu -> Cho tiep
   if(mainTrap == 0) return 0;

   // DXY phai co tin hieu tren CA 2 TF
   if(dxyTrapHTF == 0 || dxyTrapLTF == 0) return 0;

   // DXY HTF va LTF phai cung huong
   if(dxyTrapHTF != dxyTrapLTF)
   {
      PrintFormat("DXY Filter: DXY HTF/LTF XUNG DOT (%s vs %s) -> RESET!",
                  (dxyTrapHTF == 1 ? "BUY" : "SELL"),
                  (dxyTrapLTF == 1 ? "BUY" : "SELL"));
      G_DXY_TrapSignal_HTF[di] = 0;
      G_DXY_TrapSignal_LTF[di] = 0;
      return 0;
   }

   // DXY da dong bo (HTF == LTF), kiem tra hop luu voi cap tien
   int dxySignal = dxyTrapHTF; // Ca 2 giong nhau, lay 1

   bool converges = false;

   if(G_Pairs[idx].isUSDSecond)
   {
      // xxxUSD: Hop luu khi NGUOC CHIEU
      converges = (mainTrap != dxySignal);
   }
   else if(G_Pairs[idx].isUSDFirst)
   {
      // USDxxx: Hop luu khi CUNG CHIEU
      converges = (mainTrap == dxySignal);
   }

   if(converges)
   {
      int finalSignal = mainTrap;
      G_Pairs[idx].trapSignal = 0;
      G_DXY_TrapSignal_HTF[di] = 0;
      G_DXY_TrapSignal_LTF[di] = 0;

      PrintFormat("DXY Filter: HOP LUU DUAL! %s Trap=%s, DXY HTF=%s, DXY LTF=%s -> Vao lenh %s",
                  G_Pairs[idx].symbol,
                  (mainTrap == 1 ? "BUY" : "SELL"),
                  (dxyTrapHTF == 1 ? "BUY" : "SELL"),
                  (dxyTrapLTF == 1 ? "BUY" : "SELL"),
                  (finalSignal == 1 ? "BUY" : "SELL"));
      return finalSignal;
   }
   else
   {
      PrintFormat("DXY Filter: XUNG DOT! %s Trap=%s, DXY=%s -> RESET!",
                  G_Pairs[idx].symbol,
                  (mainTrap == 1 ? "BUY" : "SELL"),
                  (dxySignal == 1 ? "BUY" : "SELL"));
      G_Pairs[idx].trapSignal = 0;
      G_DXY_TrapSignal_HTF[di] = 0;
      G_DXY_TrapSignal_LTF[di] = 0;
      return 0;
   }
}

// ==================================================================
// HELPER: EXACTLY-ONCE DCA OFF / BROKER CLOSE RESOLUTION
// ==================================================================
bool ResolveClosedChainFromHistory(int idx, ulong chain_id)
{
   if(chain_id == 0) return false;
   string sym = G_Pairs[idx].symbol;
   
   string gv_name = "Yoogi_LastDeal_" + sym;
   ulong last_processed_ticket = 0;
   if(GlobalVariableCheck(gv_name))
   {
       last_processed_ticket = (ulong)GlobalVariableGet(gv_name);
   }

   datetime from_date = TimeCurrent() - 30 * 24 * 60 * 60;
   if(!HistorySelect(from_date, TimeCurrent() + 86400)) return false;

   int deals = HistoryDealsTotal();
   double realized_pnl = 0.0;
   int close_deals_found = 0;
   ulong max_ticket_found = last_processed_ticket;

   for(int d = 0; d < deals; d++)
   {
      ulong ticket = HistoryDealGetTicket(d);
      if(ticket > 0 && ticket > last_processed_ticket)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == sym && 
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == chain_id)
         {
            long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY)
            {
               realized_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                               HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                               HistoryDealGetDouble(ticket, DEAL_SWAP);
               close_deals_found++;
            }
            if(ticket > max_ticket_found) max_ticket_found = ticket;
         }
      }
   }

   if(close_deals_found == 0) return false;

   string strat = G_Pairs[idx].active_chain_strategy;
   if(strat == "") strat = "CT"; // Fallback
   
   double debt_before_print = 0.0;
   int rec_lvl = 0;
   
   if(strat == "CT") {
      debt_before_print = G_Pairs[idx].ct_realized_bleed_loss;
      rec_lvl = G_Pairs[idx].ct_recovery_level;
   } else if(strat == "FT") {
      debt_before_print = G_Pairs[idx].ft_realized_bleed_loss;
      rec_lvl = G_Pairs[idx].ft_recovery_level;
   } else if(strat == "DUAL") {
      debt_before_print = G_Pairs[idx].dual_realized_bleed_loss;
      rec_lvl = G_Pairs[idx].dual_recovery_level;
   }
   
   double debt_after = debt_before_print - realized_pnl;

   if(debt_after <= 0)
   {
       debt_after = 0.0;
       rec_lvl = 0;
       
       if(strat == "CT") { G_Pairs[idx].ct_realized_bleed_loss = 0.0; G_Pairs[idx].ct_recovery_level = 0; }
       else if(strat == "FT") { G_Pairs[idx].ft_realized_bleed_loss = 0.0; G_Pairs[idx].ft_recovery_level = 0; }
       else if(strat == "DUAL") { G_Pairs[idx].dual_realized_bleed_loss = 0.0; G_Pairs[idx].dual_recovery_level = 0; }

       PrintFormat("[ DCA-OFF-RESOLVE-COMPLETE ]\nSYMBOL=%s\nSTRAT=%s\nCHAIN_RESULT=%.2f\nDEBT=0\nRECOVERY_LEVEL_RESET=0", sym, strat, realized_pnl);
   }
   else
   {
       if(strat == "CT") { G_Pairs[idx].ct_realized_bleed_loss = debt_after; }
       else if(strat == "FT") { G_Pairs[idx].ft_realized_bleed_loss = debt_after; }
       else if(strat == "DUAL") { G_Pairs[idx].dual_realized_bleed_loss = debt_after; }

       PrintFormat("[ DCA-OFF-RESOLVE-PARTIAL ]\nSYMBOL=%s\nSTRAT=%s\nCHAIN_RESULT=%.2f\nDEBT_BEFORE=%.2f\nDEBT_AFTER=%.2f\nREMAINING_RECOVERY_LEVEL=%d",
                   sym, strat, realized_pnl, debt_before_print, debt_after, rec_lvl);
   }
   
   GlobalVariableSet(gv_name, (double)max_ticket_found);
   SaveChainState_Multi(idx);
   
   return true;
}

// ==================================================================
// HAM QUET VA DIEU PHOI (MAIN LOOP - MTF DUAL SIGNAL)
// ==================================================================
void ManagePairs()
{
   activeChainsCount = 0;

   // --- RÚT TIỀN TỰ ĐỘNG TRONG TESTER ---
   ManageTesterWithdrawal();

   // --- TINH TOAN VIRTUAL BALANCE ---
   double real_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double total_debt   = GetTotalSystemDebt();
   double virtual_bal  = real_balance + total_debt;

   bool allow_new_entry = true;
   string limit_msg = "";

   if(InpEnableBalanceLimit)
   {
      if(virtual_bal < LIMIT_MIN_VIRTUAL)
      {
         allow_new_entry = false;
         limit_msg = "STANDBY: Low Capital (< 10k)";
      }
      else if(virtual_bal > LIMIT_MAX_VIRTUAL)
      {
         allow_new_entry = false;
         limit_msg = "LIMIT REACHED: Cap > 500k";
      }
   }

   // --- [PRE-SCAN] DXY SIGNAL DUAL TF ---
   if(g_dxy_available && InpUseDXYReference)
   {
      for(int d = 0; d < DXY_CONTEXTS; d++)
      {
         // DXY HTF Signal
         int dxyHTF = CheckEntrySignal_DXY_HTF(d);
         if(dxyHTF != 0 && dxyHTF != G_DXY_TrapSignal_HTF[d])
         {
            G_DXY_TrapSignal_HTF[d] = dxyHTF;
            G_DXY_TrapSignalTime_HTF[d] = iTime(G_DXY_HTF[d].symbol, G_DXY_HTF[d].ltf, 1);
            PrintFormat("DXY Filter: DXY HTF(%s) dat bay %s",
                        EnumToString(G_DXY_HTF[d].ltf), (dxyHTF == 1 ? "BUY" : "SELL"));
         }

         // DXY LTF Signal
         int dxyLTF = CheckEntrySignal_DXY_LTF(d);
         if(dxyLTF != 0 && dxyLTF != G_DXY_TrapSignal_LTF[d])
         {
            G_DXY_TrapSignal_LTF[d] = dxyLTF;
            G_DXY_TrapSignalTime_LTF[d] = iTime(G_DXY_LTF[d].symbol, G_DXY_LTF[d].ltf, 1);
            PrintFormat("DXY Filter: DXY LTF(%s) dat bay %s",
                        EnumToString(G_DXY_LTF[d].ltf), (dxyLTF == 1 ? "BUY" : "SELL"));
         }
      }
   }

   // --- VONG LAP QUA 5 CAP TIEN ---
   for(int i = 0; i < TOTAL_PAIRS; ++i)
   {
      string sym = G_Pairs[i].symbol;

      // A. Thu thap thong tin
      int    count = 0;
      double pnl   = 0.0;
      ulong  found_chain_id = 0;
      ENUM_POSITION_TYPE m_type = (ENUM_POSITION_TYPE)-1;
      ulong  master_ticket = 0;
      long   oldest_time   = LONG_MAX;

      ulong expected_chain_id = EA_MAGIC_NUMBER * 1000 + i;

      for(int k = PositionsTotal()-1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym)
            {
               ulong pos_magic = (ulong)PositionGetInteger(POSITION_MAGIC);
               if(pos_magic == expected_chain_id || pos_magic == 0)
               {
                   count++;
                   pnl += ProfitOf(t);
                   
                   long t_time = (long)PositionGetInteger(POSITION_TIME);
                   if(t_time < oldest_time)
                   {
                      oldest_time = t_time;
                      master_ticket = t;
                      m_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                   }
               }
            }
         }
      }

      // B. XU LY LOGIC
      if(count > 0)
      {
         activeChainsCount++;

         if(G_Pairs[i].active_chain_id == 0)
         {
            G_Pairs[i].active_chain_id = expected_chain_id;
            LoadChainState_Multi(i, expected_chain_id);
         }
         else if(InpEnableDynamicTP && !G_TradeProfile[i].is_valid)
         {
            LoadTradeProfile(i, G_Pairs[i].active_chain_id);
         }

         // --- DYNAMIC EXIT ENGINE ---
         if(InpEnableDynamicTP && G_TradeProfile[i].is_valid)
         {
            // Update Dynamic Exit state (compression, runner, basket avg)
            UpdateDynamicExit(i);

            int basket_dir = (m_type == POSITION_TYPE_BUY) ? 1 : -1;

               // DCA ON: Use basket average entry for TP
               double avg_entry = CalcBasketAverageEntry(i);
               double basket_tp = GetBasketTPPrice(i, avg_entry, basket_dir);
               double current_price = (basket_dir == 1) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                                       : SymbolInfoDouble(sym, SYMBOL_ASK);

               // Check Runner exit
               if(G_TradeProfile[i].runner_active && IsRunnerStopped(i))
               {
                  PrintFormat("[%s] >>> RUNNER EXIT: Trailing stop hit. Closing...", sym);
                  CloseAndResolveChain(i, "RUNNER");
                  continue;
               }

               // Check basket TP hit
               bool tp_hit = false;
               if(basket_dir == 1 && current_price >= basket_tp) tp_hit = true;
               if(basket_dir == -1 && current_price <= basket_tp) tp_hit = true;

               if(tp_hit && !G_TradeProfile[i].runner_active)
               {
                  // Check if runner should activate instead of closing
                  if(CheckRunnerConditions(i))
                  {
                     ActivateRunner(i);
                     // Don't close, runner will manage exit
                  }
                  else
                  {
                     PrintFormat("[%s] >>> DYNAMIC TP HIT: AvgEntry=%.5f TP=%.5f Current=%.5f (%.1f pips). Closing...",
                                 sym, avg_entry, basket_tp, current_price, G_TradeProfile[i].current_dynamic_tp);

                     PrintFormat("[DCA] Step=%d pips | AvgEntry=%.5f | BasketTP=%.5f",
                                 InpKhoangMoPip, avg_entry, basket_tp);

                     CloseAndResolveChain(i, "TP");
                     continue;
                  }
               }
         }
         else
         {
            // --- ORIGINAL LOGIC (fallback when Dynamic TP disabled) ---
            double working_balance = (G_Pairs[i].locked_balance > 0) ? G_Pairs[i].locked_balance : real_balance;
            double base_tp_usd = CalculateAutoTP(sym, working_balance);

            string strat = G_Pairs[i].active_chain_strategy;
            double current_debt = 0.0;
            if(strat == "CT")
               current_debt = G_Pairs[i].ct_realized_bleed_loss;
            else if(strat == "FT")
               current_debt = G_Pairs[i].ft_realized_bleed_loss;
            else if(strat == "DUAL")
               current_debt = G_Pairs[i].dual_realized_bleed_loss;
            else
               current_debt = G_Pairs[i].ct_realized_bleed_loss; // Safe fallback

            double total_target = base_tp_usd + current_debt;

            if(pnl >= total_target)
            {
               PrintFormat("[%s] >>> TAKE PROFIT: $%.2f (Target $%.2f). Closing...", sym, pnl, total_target);
               CloseAndResolveChain(i, "TP");
               continue;
            }
         }

         ApplySmartTrimming(i);
         ManageTrendDCA_Multi(i, count, m_type);
      }
      else
      {
         if(G_Pairs[i].active_chain_id != 0)
         {
             if(ResolveClosedChainFromHistory(i, G_Pairs[i].active_chain_id))
             {
                 ClearChainState_Multi(i);
             }
         }

         // === DUAL ENTRY ENGINE — SIGNAL MANAGER ===
         if(InpAutoSignalTrading && allow_new_entry && G_Pairs[i].enabled)
         {
            int ct_signal = 0; // Counter-Trend signal
            int tf_signal = 0; // Trend-Following signal
            
            // --- Engine 1: Counter-Trend ---
            if(InpEnableCounterTrend && InpUseReversalEngine)
            {
               ct_signal = CheckCounterTrendSignal(i);
            }
            
            // --- Engine 2: Trend-Following ---
            if(InpEnableTrendFollowing)
            {
               tf_signal = CheckTrendFollowingSignal(i);
            }
            
            // --- SIGNAL MANAGER: Conflict Resolution ---
            int final_signal = 0;
            string entry_mode = "";
            
            if(ct_signal != 0 && tf_signal != 0)
            {
               // Both engines have signals
               if(ct_signal == tf_signal)
               {
                  // Same direction = strong confirmation
                  final_signal = ct_signal;
                  entry_mode = "DUAL";
                  PrintFormat("[%s] >>> DUAL CONFIRMATION: CT=%s + FT=%s",
                              sym, (ct_signal == 1 ? "BUY" : "SELL"),
                              (tf_signal == 1 ? "BUY" : "SELL"));
               }
               else
               {
                  // Opposite directions = CONFLICT → DO NOT ENTER
                  final_signal = 0;
                  PrintFormat("[%s] >>> ENTRY CONFLICT: CT=%s vs FT=%s → NO ENTRY",
                              sym, (ct_signal == 1 ? "BUY" : "SELL"),
                              (tf_signal == 1 ? "BUY" : "SELL"));
               }
            }
            else if(ct_signal != 0)
            {
               final_signal = ct_signal;
               entry_mode = "CT";
            }
            else if(tf_signal != 0)
            {
               final_signal = tf_signal;
               entry_mode = "FT";
            }
            
            // --- OPEN MASTER ORDER ---
            if(final_signal != 0)
            {
               if(final_signal == 1  && !InpAllowBuy) { /* skip */ }
               else if(final_signal == -1 && !InpAllowSell) { /* skip */ }
               else
               {
                  PrintFormat("[%s] >>> ENTRY ENGINE [%s] CONFIRMED: Opening %s trade...",
                              sym, entry_mode, (final_signal == 1 ? "BUY" : "SELL"));
                  OpenMasterTrade_Multi(i, final_signal, entry_mode);
               }
            }
         }

      }
   }

   trade.SetExpertMagicNumber(0);
}

//+------------------------------------------------------------------+
//| QUẢN LÝ RÚT TIỀN TRONG TESTER                                    |
//+------------------------------------------------------------------+
void ManageTesterWithdrawal()
{
   if(!MQLInfoInteger(MQL_TESTER)) return; // Chỉ chạy trong Tester
   if(!InpTesterWithdrawalEnabled) return;

   // Vòng lặp rút liên tục cho đến khi balance < base + threshold
   while(true)
   {
       double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
       double excess_balance = current_balance - InpTesterBaseBalance;

       // Nếu phần dư chưa đạt ngưỡng → dừng
       if(excess_balance < InpTesterWithdrawThreshold) break;

       // Xác định số tiền rút mỗi lần
       double amount_to_withdraw = InpTesterWithdrawAmount;
       if(amount_to_withdraw <= 0 || amount_to_withdraw > excess_balance)
           amount_to_withdraw = excess_balance;

       PrintFormat("[TESTER WITHDRAWAL] Balance=%.2f, Excess=%.2f (Nguong %.2f). Rut %.2f...", 
           current_balance, excess_balance, InpTesterWithdrawThreshold, amount_to_withdraw);

       if(TesterWithdrawal(amount_to_withdraw))
       {
           PrintFormat("[TESTER WITHDRAWAL] >>> RUT THANH CONG %.2f. Balance: %.2f -> %.2f <<<", 
               amount_to_withdraw, current_balance, AccountInfoDouble(ACCOUNT_BALANCE));
       }
       else
       {
           PrintFormat("[TESTER WITHDRAWAL] Rut that bai. Kiem tra lai.");
           break;
       }

       // Nếu đã rút toàn bộ phần dư → thoát
       if(amount_to_withdraw >= excess_balance) break;
   }
}
//+------------------------------------------------------------------+
