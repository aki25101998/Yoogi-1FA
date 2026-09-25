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
void SavePersistentState(int idx)
{
   string sym = G_Pairs[idx].symbol;
   // Save SYSTEM-LEVEL state (AUTHORITATIVE)
   GlobalVariableSet("Yoogi_SystemDebt_" + sym, G_Pairs[idx].system_debt);
   GlobalVariableSet("Yoogi_SystemRecLvl_" + sym, (double)G_Pairs[idx].system_recovery_level);
   GlobalVariableSet("Yoogi_SystemDCASeq_" + sym, (double)G_Pairs[idx].system_dca_sequence);
   
   // Save legacy per-strategy state (backward compatibility only)
   GlobalVariableSet("Yoogi_CT_Debt_" + sym, G_Pairs[idx].ct_realized_bleed_loss);
   GlobalVariableSet("Yoogi_CT_RecLvl_" + sym, (double)G_Pairs[idx].ct_recovery_level);
   GlobalVariableSet("Yoogi_FT_Debt_" + sym, G_Pairs[idx].ft_realized_bleed_loss);
   GlobalVariableSet("Yoogi_FT_RecLvl_" + sym, (double)G_Pairs[idx].ft_recovery_level);
   GlobalVariableSet("Yoogi_DUAL_Debt_" + sym, G_Pairs[idx].dual_realized_bleed_loss);
   GlobalVariableSet("Yoogi_DUAL_RecLvl_" + sym, (double)G_Pairs[idx].dual_recovery_level);
   
   GlobalVariableSet("Yoogi_CT_DCASeq_" + sym, (double)G_Pairs[idx].ct_dca_sequence);
   GlobalVariableSet("Yoogi_FT_DCASeq_" + sym, (double)G_Pairs[idx].ft_dca_sequence);
   GlobalVariableSet("Yoogi_DUAL_DCASeq_" + sym, (double)G_Pairs[idx].dual_dca_sequence);
}

void SaveChainState_Multi(int idx)
{
   // Always save permanent persistent state first
   SavePersistentState(idx);

   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

   if(id == 0) return;

   // Chain Specific State
   GlobalVariableSet("Yoogi_ActiveChainID_" + sym, (double)id);
   GlobalVariableSet(GetVarName_Step(sym, id),     (double)G_Pairs[idx].chain_position_count);
   GlobalVariableSet(GetVarName_StartSeq(sym, id), (double)G_Pairs[idx].chain_start_dca_seq);
   GlobalVariableSet(GetVarName_EndSeq(sym, id),   (double)G_Pairs[idx].chain_end_dca_seq);
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

   // Load SYSTEM-LEVEL Recovery State (AUTHORITATIVE)
   bool has_debt   = GlobalVariableCheck("Yoogi_SystemDebt_" + sym);
   bool has_reclvl = GlobalVariableCheck("Yoogi_SystemRecLvl_" + sym);
   bool has_dcaseq = GlobalVariableCheck("Yoogi_SystemDCASeq_" + sym);

   if(has_debt && has_reclvl && has_dcaseq)
   {
      G_Pairs[idx].system_debt = GlobalVariableGet("Yoogi_SystemDebt_" + sym);
      G_Pairs[idx].system_recovery_level = (int)GlobalVariableGet("Yoogi_SystemRecLvl_" + sym);
      G_Pairs[idx].system_dca_sequence = (int)GlobalVariableGet("Yoogi_SystemDCASeq_" + sym);
      G_Pairs[idx].system_recovery_active = (G_Pairs[idx].system_debt > 0.001);
   }
   else
   {
      // MIGRATION / RECONCILIATION: Safely merge if System State is incomplete or missing
      double total_legacy_debt = G_Pairs[idx].ct_realized_bleed_loss 
                               + G_Pairs[idx].ft_realized_bleed_loss 
                               + G_Pairs[idx].dual_realized_bleed_loss;
                               
      int max_legacy_seq = MathMax(G_Pairs[idx].ct_dca_sequence,
                           MathMax(G_Pairs[idx].ft_dca_sequence,
                                   G_Pairs[idx].dual_dca_sequence));
                                   
      int max_legacy_lvl = MathMax(G_Pairs[idx].ct_recovery_level,
                           MathMax(G_Pairs[idx].ft_recovery_level,
                                   G_Pairs[idx].dual_recovery_level));
                                   
      if(has_debt) G_Pairs[idx].system_debt = GlobalVariableGet("Yoogi_SystemDebt_" + sym);
      else         G_Pairs[idx].system_debt = total_legacy_debt;
      
      if(has_reclvl) G_Pairs[idx].system_recovery_level = (int)GlobalVariableGet("Yoogi_SystemRecLvl_" + sym);
      else           G_Pairs[idx].system_recovery_level = max_legacy_lvl;
      
      if(has_dcaseq) G_Pairs[idx].system_dca_sequence = (int)GlobalVariableGet("Yoogi_SystemDCASeq_" + sym);
      else           G_Pairs[idx].system_dca_sequence = max_legacy_seq;
      
      G_Pairs[idx].system_recovery_active = (G_Pairs[idx].system_debt > 0.001);
      
      // Persist immediately so migration/reconciliation only happens once
      GlobalVariableSet("Yoogi_SystemDebt_" + sym, G_Pairs[idx].system_debt);
      GlobalVariableSet("Yoogi_SystemRecLvl_" + sym, (double)G_Pairs[idx].system_recovery_level);
      GlobalVariableSet("Yoogi_SystemDCASeq_" + sym, (double)G_Pairs[idx].system_dca_sequence);
      
      if(!has_debt && !has_reclvl && !has_dcaseq)
      {
         if(total_legacy_debt > 0.001 || max_legacy_seq > 0)
         {
            PrintFormat("[STATE-MIGRATION]\nSYMBOL=%s\nLEGACY_CT_DEBT=%.2f\nLEGACY_FT_DEBT=%.2f\nLEGACY_DUAL_DEBT=%.2f\nSYSTEM_DEBT=%.2f\nLEGACY_CT_DCA=%d\nLEGACY_FT_DCA=%d\nLEGACY_DUAL_DCA=%d\nSYSTEM_DCA=%d\nACTION=MIGRATED",
                        sym, G_Pairs[idx].ct_realized_bleed_loss, G_Pairs[idx].ft_realized_bleed_loss, G_Pairs[idx].dual_realized_bleed_loss, total_legacy_debt, 
                        G_Pairs[idx].ct_dca_sequence, G_Pairs[idx].ft_dca_sequence, G_Pairs[idx].dual_dca_sequence, max_legacy_seq);
         }
      }
      else
      {
         PrintFormat("[STATE-RECONCILE]\nSYMBOL=%s\nSYSTEM_DEBT_EXISTING=%.2f\nLEGACY_DEBT=%.2f\nSYSTEM_DEBT_FINAL=%.2f\nSYSTEM_DCA_FINAL=%d\nACTION=RECONCILED",
                     sym, has_debt ? GlobalVariableGet("Yoogi_SystemDebt_" + sym) : 0.0, total_legacy_debt, G_Pairs[idx].system_debt, G_Pairs[idx].system_dca_sequence);
      }
   }

   // Load Chain Specific State
   if(chain_id == 0)
   {
      if(GlobalVariableCheck("Yoogi_ActiveChainID_" + sym))
         chain_id = (ulong)GlobalVariableGet("Yoogi_ActiveChainID_" + sym);
   }
   G_Pairs[idx].active_chain_id = chain_id;
   if(chain_id == 0) return;

   string n_step     = GetVarName_Step(sym, chain_id);
   string n_start    = GetVarName_StartSeq(sym, chain_id);
   string n_end      = GetVarName_EndSeq(sym, chain_id);
   string n_bal      = GetVarName_LockedBal(sym, chain_id);
   string n_dca_step = "Yoogi_DCAStep_" + sym + "_" + IntegerToString(chain_id);

   if(GlobalVariableCheck(n_step))  G_Pairs[idx].chain_position_count = (int)GlobalVariableGet(n_step);
   else                             G_Pairs[idx].chain_position_count = 0;

   if(GlobalVariableCheck(n_start)) G_Pairs[idx].chain_start_dca_seq = (int)GlobalVariableGet(n_start);
   else                             G_Pairs[idx].chain_start_dca_seq = 0;

   if(GlobalVariableCheck(n_end))   G_Pairs[idx].chain_end_dca_seq = (int)GlobalVariableGet(n_end);
   else                             G_Pairs[idx].chain_end_dca_seq = 0;

   if(GlobalVariableCheck(n_dca_step)) G_Pairs[idx].chain_step_pips = (int)GlobalVariableGet(n_dca_step);
   else                                G_Pairs[idx].chain_step_pips = InpDCA_MinStepPips;

   G_Pairs[idx].active_chain_strategy = DetectChainStrategy(idx, chain_id);

   if(GlobalVariableCheck(n_bal))   G_Pairs[idx].locked_balance = GlobalVariableGet(n_bal);
   else                             G_Pairs[idx].locked_balance = 0.0;

   // Failsafe: if chain_position_count is 0 but positions exist for this chain, count them
   if(G_Pairs[idx].chain_position_count <= 0)
   {
      int pos_found = CountOrdersInChain(sym, chain_id);
      if(pos_found > 0) G_Pairs[idx].chain_position_count = pos_found;
   }

   // Failsafe: reconstruct DCA sequence numbers from actual market orders if missing
   if(G_Pairs[idx].chain_end_dca_seq <= 0)
   {
      int min_seq = 999999, max_seq = 0;
      for(int k = PositionsTotal() - 1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym &&
               (ulong)PositionGetInteger(POSITION_MAGIC) == chain_id)
            {
               int s = ExtractDCASeqFromComment(PositionGetString(POSITION_COMMENT));
               if(s > 0)
               {
                  if(s < min_seq) min_seq = s;
                  if(s > max_seq) max_seq = s;
               }
            }
         }
      }
      if(max_seq > 0)
      {
         G_Pairs[idx].chain_start_dca_seq = min_seq;
         G_Pairs[idx].chain_end_dca_seq   = max_seq;
         if(GetSystemDCASeq(idx) < max_seq)
         {
            SetSystemDCASeq(idx, max_seq);
         }
      }
   }

   if(InpEnableDynamicTP)
   {
      LoadTradeProfile(idx, chain_id);
   }
}

void ClearChainState_Multi(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

   if(id != 0)
   {
      // Only delete chain specific state
      GlobalVariableDel(GetVarName_Step(sym, id));
      GlobalVariableDel(GetVarName_StartSeq(sym, id));
      GlobalVariableDel(GetVarName_EndSeq(sym, id));
      GlobalVariableDel("Yoogi_DCAStep_" + sym + "_" + IntegerToString(id));
      GlobalVariableDel(GetVarName_LockedBal(sym, id));
      GlobalVariableDel("Yoogi_Strat_" + sym + "_" + IntegerToString(id));
      GlobalVariableDel("Yoogi_ActiveChainID_" + sym);
      ClearTradeProfilePersistence(idx, id);
   }

   // Reset chain specific memory
   G_Pairs[idx].chain_position_count = 0;
   G_Pairs[idx].chain_start_dca_seq = 0;
   G_Pairs[idx].chain_end_dca_seq = 0;
   G_Pairs[idx].chain_step_pips = 0;
   G_Pairs[idx].locked_balance = 0.0;
   G_Pairs[idx].active_chain_id = 0;
   G_Pairs[idx].active_chain_strategy = "";
}

// ==================================================================
// AUTHORITATIVE RESOLUTION OF CLOSED CHAIN FROM ACCOUNT HISTORY
// ==================================================================
bool ResolveClosedChainFromHistory(int idx, ulong chain_id, string reason)
{
   if(chain_id == 0) return false;
   string sym = G_Pairs[idx].symbol;
   
   // Idempotency: verify this chain has not already been resolved
   string resolved_gv = "Yoogi_Resolved_" + sym + "_" + IntegerToString(chain_id);
   if(GlobalVariableCheck(resolved_gv)) return false;

   datetime from_date = 0; // Look at entire available history to ensure we find IN deals
   if(!HistorySelect(from_date, TimeCurrent() + 86400)) return false;

   int deals = HistoryDealsTotal();
   double realized_pnl = 0.0;
   int close_deals_found = 0;
   ulong max_ticket_found = 0;

   // Pass 1: Find all Position IDs belonging to this chain
   long pos_ids[];
   int pos_count = 0;
   for(int d = 0; d < deals; d++)
   {
      ulong ticket = HistoryDealGetTicket(d);
      if(ticket > 0 && HistoryDealGetString(ticket, DEAL_SYMBOL) == sym)
      {
         if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) == chain_id && 
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            long pid = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            bool exists = false;
            for(int j=0; j<pos_count; j++) { if(pos_ids[j] == pid) { exists = true; break; } }
            if(!exists)
            {
               ArrayResize(pos_ids, pos_count + 1);
               pos_ids[pos_count] = pid;
               pos_count++;
            }
         }
      }
   }

   // Pass 2: Calculate PnL for these Position IDs (even if OUT deal magic is 0 due to manual/broker close)
   for(int d = 0; d < deals; d++)
   {
      ulong ticket = HistoryDealGetTicket(d);
      if(ticket > 0 && HistoryDealGetString(ticket, DEAL_SYMBOL) == sym)
      {
         long pid = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         bool matches_chain = false;
         for(int j=0; j<pos_count; j++) { if(pos_ids[j] == pid) { matches_chain = true; break; } }
         
         if(matches_chain)
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

   if(close_deals_found == 0)
   {
      PrintFormat("[WARNING] Chain %I64u on %s has no closed deals but is empty! Forcing resolve.", chain_id, sym);
   }

   // Check pending close reason if closed by broker / delayed
   string pending_reason_gv = "Yoogi_PendingReason_" + sym + "_" + IntegerToString(chain_id);
   if(GlobalVariableCheck(pending_reason_gv))
   {
      double pr_val = GlobalVariableGet(pending_reason_gv);
      if(pr_val == 1.0) reason = "MAX_DCA";
      else if(pr_val == 2.0) reason = "TP";
      else if(pr_val == 3.0) reason = "RUNNER";
      GlobalVariableDel(pending_reason_gv);
   }
   else if(reason == "BROKER_CLOSE")
   {
      // Inspect deal reasons in history: if closed by TP, reason is TP
      for(int d = 0; d < deals; d++)
      {
         ulong dticket = HistoryDealGetTicket(d);
         if(dticket > 0 && HistoryDealGetString(dticket, DEAL_SYMBOL) == sym && 
            (ulong)HistoryDealGetInteger(dticket, DEAL_MAGIC) == chain_id)
         {
            long deal_entry = HistoryDealGetInteger(dticket, DEAL_ENTRY);
            if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY)
            {
               long deal_reason = HistoryDealGetInteger(dticket, DEAL_REASON);
               if(deal_reason == DEAL_REASON_TP)
               {
                  reason = "TP";
                  break;
               }
            }
         }
      }
   }

   string strat = DetectChainStrategy(idx, chain_id);
   G_Pairs[idx].active_chain_strategy = strat;
   
   // USE SYSTEM-LEVEL state (AUTHORITATIVE) - not per-strategy state
   double debt_before     = GetSystemDebt(idx);
   int rec_lvl            = GetSystemRecLvl(idx);
   int current_dca_seq    = GetSystemDCASeq(idx);

   int dca_from = G_Pairs[idx].chain_start_dca_seq;
   int dca_to   = G_Pairs[idx].chain_end_dca_seq;
   if(dca_to <= 0)
   {
      // Recover sequence bounds from history deals if active context missing
      int min_seq = 999999, max_seq = 0;
      for(int d = 0; d < deals; d++)
      {
         ulong dticket = HistoryDealGetTicket(d);
         if(dticket > 0 && HistoryDealGetString(dticket, DEAL_SYMBOL) == sym && 
            (ulong)HistoryDealGetInteger(dticket, DEAL_MAGIC) == chain_id)
         {
            int s = ExtractDCASeqFromComment(HistoryDealGetString(dticket, DEAL_COMMENT));
            if(s > 0)
            {
               if(s < min_seq) min_seq = s;
               if(s > max_seq) max_seq = s;
            }
         }
      }
      if(max_seq > 0)
      {
         dca_from = min_seq;
         dca_to   = max_seq;
      }
      else
      {
         dca_to = current_dca_seq;
         dca_from = MathMax(1, dca_to - G_Pairs[idx].chain_position_count + 1);
      }
   }
   if(dca_from <= 0) dca_from = MathMax(1, dca_to - G_Pairs[idx].chain_position_count + 1);

   // Ensure system DCA seq is at least dca_to (in case it wasn't updated)
   if(current_dca_seq < dca_to)
   {
      current_dca_seq = dca_to;
      SetSystemDCASeq(idx, current_dca_seq);
   }

   // Update Debt, Recovery State & DCA Sequence based on Reason and Realized P&L
   if(reason == "MAX_DCA")
   {
      if(realized_pnl < 0.0)
      {
         double net_loss = MathAbs(realized_pnl);
         double debt_after = debt_before + net_loss;
         rec_lvl++;
         
         SetSystemDebt(idx, debt_after);
         SetSystemRecLvl(idx, rec_lvl);
         // Global DCA sequence stays at current_dca_seq (does NOT reset)
         
         PrintFormat("[DEBT-ADD]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nDCA_FROM=%d\nDCA_TO=%d\nCHAIN_RESULT=%.2f\nDEBT_BEFORE=%.2f\nDEBT_ADDED=%.2f\nDEBT_AFTER=%.2f\nDCA_SEQUENCE=%d\nMODE=RECOVERY",
                     sym, strat, chain_id, dca_from, dca_to, realized_pnl, debt_before, net_loss, debt_after, current_dca_seq);
      }
      else
      {
         // MAX_DCA with profit (not TP)
         if(debt_before > 0.001 && realized_pnl > 0.0)
         {
            double debt_target = 0.0;
            if(pos_count == 1) debt_target = debt_before * 0.50;
            else if(pos_count == 2) debt_target = debt_before * 0.50;
            else debt_target = debt_before;

            double debt_reduction = MathMin(debt_target, realized_pnl);
            debt_reduction = MathMin(debt_reduction, debt_before);

            double normal_profit = realized_pnl - debt_reduction;
            double debt_after = debt_before - debt_reduction;
            
            PrintFormat("\n[RECOVERY CHAIN CLOSED]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nRealizedProfit=%.2f\nDebtBefore=%.2f\nDebtReduction=%.2f\nNormalProfit=%.2f\nDebtAfter=%.2f\nRecoveryComplete=%s\nDCA_SEQUENCE=%d",
                        sym, strat, chain_id, realized_pnl, debt_before, debt_reduction, normal_profit, debt_after, (debt_after <= 0.00001 ? "true" : "false"), current_dca_seq);

            if(debt_after <= 0.00001)
            {
               // Full Recovery Complete!
               SetSystemDebt(idx, 0.0);
               SetSystemRecLvl(idx, 0);
               SetSystemDCASeq(idx, 0);
            }
            else
            {
               // Partial Recovery
               SetSystemDebt(idx, debt_after);
            }
         }
         else
         {
            // Normal profitable chain, no debt or non-positive profit
            string mode_str = (debt_before > 0.001) ? "RECOVERY" : "NORMAL";
            PrintFormat("[CHAIN-CLOSE-PROFIT]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nCHAIN_RESULT=%.2f\nDEBT_BEFORE=%.2f\nDEBT_AFTER=%.2f\nMODE=%s",
                        sym, strat, chain_id, realized_pnl, debt_before, debt_before, mode_str);
         }
      }
   }
   else if(reason == "TP" || reason == "RUNNER")
   {
      if(debt_before <= 0.001)
      {
         // Normal TP: no debt, reset sequence to 0 (ready for next chain starting at DCA 1)
         SetSystemDCASeq(idx, 0);
         SetSystemRecLvl(idx, 0);
         SetSystemDebt(idx, 0.0);
         
         PrintFormat("[NORMAL-TP]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_RESULT=%.2f\nRESET_DCA_SEQUENCE=true\nMODE=NORMAL",
                     sym, strat, realized_pnl);
      }
      else
      {
         // Recovery TP: settle debt with realized profit
         if(realized_pnl > 0.0)
         {
            double debt_target = 0.0;
            if(pos_count == 1) debt_target = debt_before * 0.50;
            else if(pos_count == 2) debt_target = debt_before * 0.50;
            else debt_target = debt_before;

            double debt_reduction = MathMin(debt_target, realized_pnl);
            debt_reduction = MathMin(debt_reduction, debt_before);

            double normal_profit = realized_pnl - debt_reduction;
            double debt_after = debt_before - debt_reduction;
            
            PrintFormat("\n[RECOVERY CHAIN CLOSED]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nRealizedProfit=%.2f\nDebtBefore=%.2f\nDebtReduction=%.2f\nNormalProfit=%.2f\nDebtAfter=%.2f\nRecoveryComplete=%s\nDCA_SEQUENCE=%d",
                        sym, strat, chain_id, realized_pnl, debt_before, debt_reduction, normal_profit, debt_after, (debt_after <= 0.00001 ? "true" : "false"), current_dca_seq);

            if(debt_after <= 0.00001)
            {
               // Full Recovery Complete!
               SetSystemDebt(idx, 0.0);
               SetSystemRecLvl(idx, 0);
               SetSystemDCASeq(idx, 0);
            }
            else
            {
               // Partial Recovery
               SetSystemDebt(idx, debt_after);
            }
         }
         else
         {
            // TP/RUNNER closed with loss (e.g. extreme slippage)
            double net_loss = MathAbs(realized_pnl);
            double debt_after = debt_before + net_loss;
            rec_lvl++;
            SetSystemDebt(idx, debt_after);
            SetSystemRecLvl(idx, rec_lvl);
            
            PrintFormat("[DEBT-ADD]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nDCA_FROM=%d\nDCA_TO=%d\nCHAIN_RESULT=%.2f\nDEBT_BEFORE=%.2f\nDEBT_ADDED=%.2f\nDEBT_AFTER=%.2f\nDCA_SEQUENCE=%d\nMODE=RECOVERY",
                        sym, strat, chain_id, dca_from, dca_to, realized_pnl, debt_before, net_loss, debt_after, current_dca_seq);
         }
      }
   }
   else
   {
      // Other closure reason (e.g. broker close / manual close)
      if(realized_pnl < 0.0)
      {
         double net_loss = MathAbs(realized_pnl);
         double debt_after = debt_before + net_loss;
         rec_lvl++;
         SetSystemDebt(idx, debt_after);
         SetSystemRecLvl(idx, rec_lvl);
         PrintFormat("[DEBT-ADD]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nDCA_FROM=%d\nDCA_TO=%d\nCHAIN_RESULT=%.2f\nDEBT_BEFORE=%.2f\nDEBT_ADDED=%.2f\nDEBT_AFTER=%.2f\nDCA_SEQUENCE=%d\nMODE=RECOVERY",
                     sym, strat, chain_id, dca_from, dca_to, realized_pnl, debt_before, net_loss, debt_after, current_dca_seq);
      }
      else if(realized_pnl > 0.0 && debt_before > 0.001)
      {
         // Other closure with positive profit during recovery: settle debt
         double debt_target = 0.0;
         if(pos_count == 1) debt_target = debt_before * 0.50;
         else if(pos_count == 2) debt_target = debt_before * 0.50;
         else debt_target = debt_before;

         double debt_reduction = MathMin(debt_target, realized_pnl);
         debt_reduction = MathMin(debt_reduction, debt_before);

         double normal_profit = realized_pnl - debt_reduction;
         double debt_after = debt_before - debt_reduction;
         
         PrintFormat("\n[RECOVERY CHAIN CLOSED]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nRealizedProfit=%.2f\nDebtBefore=%.2f\nDebtReduction=%.2f\nNormalProfit=%.2f\nDebtAfter=%.2f\nRecoveryComplete=%s\nDCA_SEQUENCE=%d",
                     sym, strat, chain_id, realized_pnl, debt_before, debt_reduction, normal_profit, debt_after, (debt_after <= 0.00001 ? "true" : "false"), current_dca_seq);

         if(debt_after <= 0.00001)
         {
            // Full Recovery Complete!
            SetSystemDebt(idx, 0.0);
            SetSystemRecLvl(idx, 0);
            SetSystemDCASeq(idx, 0);
         }
         else
         {
            // Partial Recovery
            SetSystemDebt(idx, debt_after);
         }
      }
      else
      {
         // Other closure with no profit or no debt
         string mode_str = (debt_before > 0.001) ? "RECOVERY" : "NORMAL";
         PrintFormat("[CHAIN-CLOSE-PROFIT]\nSYMBOL=%s\nSTRATEGY=%s\nCHAIN_ID=%I64u\nCHAIN_RESULT=%.2f\nDEBT_BEFORE=%.2f\nDEBT_AFTER=%.2f\nMODE=%s",
                     sym, strat, chain_id, realized_pnl, debt_before, debt_before, mode_str);
      }
   }

   // Mark this chain ID as resolved
   GlobalVariableSet(resolved_gv, 1.0);
   if(max_ticket_found > 0)
   {
      GlobalVariableSet("Yoogi_LastDeal_" + sym, (double)max_ticket_found);
   }

   // Reset chain state & persist
   ResetTradeProfile(idx);
   ClearChainState_Multi(idx);
   SavePersistentState(idx);
   
   return true;
}

void CloseAndResolveChain(int idx, string reason)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;
   
   if(id == 0) return;

   // Save pending close reason to ensure attribution survives deferral/restart
   string pending_reason_gv = "Yoogi_PendingReason_" + sym + "_" + IntegerToString(id);
   double pr_val = 0.0;
   if(reason == "MAX_DCA") pr_val = 1.0;
   else if(reason == "TP") pr_val = 2.0;
   else if(reason == "RUNNER") pr_val = 3.0;
   GlobalVariableSet(pending_reason_gv, pr_val);

   // 1. Request closing of all positions belonging to this chain
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

   // 2. Wait until positions are closed
   int wait_ms = 0;
   while(CountOrdersInChain(sym, id) > 0 && wait_ms < 3000)
   {
      Sleep(50);
      wait_ms += 50;
   }

   if(CountOrdersInChain(sym, id) > 0)
   {
      PrintFormat("[%s] WARNING: Chain %I64u still has %d open positions after close request. Deferring resolution.",
                  sym, id, CountOrdersInChain(sym, id));
      return;
   }

   // 3. Wait briefly for history deals to be available in terminal cache
   int hist_wait_ms = 0;
   bool deals_ready = false;
   while(hist_wait_ms < 2000)
   {
      datetime from_date = TimeCurrent() - 90 * 24 * 60 * 60;
      if(HistorySelect(from_date, TimeCurrent() + 86400))
      {
         int deals = HistoryDealsTotal();
         for(int d = deals - 1; d >= 0; d--)
         {
            ulong ticket = HistoryDealGetTicket(d);
            if(ticket > 0 && HistoryDealGetString(ticket, DEAL_SYMBOL) == sym && 
               (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) == id)
            {
               long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
               if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY)
               {
                  deals_ready = true;
                  break;
               }
            }
         }
      }
      if(deals_ready) break;
      Sleep(50);
      hist_wait_ms += 50;
   }

   // 4. Resolve the closed chain from account history as the authoritative source
   ResolveClosedChainFromHistory(idx, id, reason);
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

   ulong new_chain_id = GenerateUniqueChainID(idx);
   trade.SetExpertMagicNumber(new_chain_id);

   // --- DYNAMICAL STRATEGY STATE SELECTION ---
   G_Pairs[idx].active_chain_strategy = entry_mode;
   G_Pairs[idx].active_chain_id = new_chain_id;

   // Immediately persist strategy and active chain ID
   int strat_val = (entry_mode == "FT") ? 2 : ((entry_mode == "DUAL") ? 3 : 1);
   GlobalVariableSet("Yoogi_Strat_" + sym + "_" + IntegerToString(new_chain_id), (double)strat_val);
   GlobalVariableSet("Yoogi_ActiveChainID_" + sym, (double)new_chain_id);
   
   // USE SYSTEM-LEVEL state (AUTHORITATIVE) - strategy-independent recovery
   double current_debt = GetSystemDebt(idx);
   bool is_recovery    = (current_debt > 0.001);
   int current_dca_seq = GetSystemDCASeq(idx);

   int next_dca_seq = 1;
   if(is_recovery)
   {
      next_dca_seq = current_dca_seq + 1;
   }
   else
   {
      next_dca_seq = 1;
   }

   // --- COMMENT VỚI DCA SEQUENCE (BỎ HOÀN TOÀN ENTRY) ---
   string comment = entry_mode + " | DCA " + IntegerToString(next_dca_seq);
   
   bool   res     = false;
   double sl=0.0, tp=0.0;

   // --- [LOGIC REAL TIME] TÍNH LOT THEO BALANCE THỰC TẾ HOẶC THỦ CÔNG ---
   double current_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot_calculation_bal = current_bal;

   if(InpSetBalance > 0.0)
   {
      lot_calculation_bal = InpSetBalance;
   }

   // Tính lot theo Global DCA Sequence (DCA 1 = BaseLot, DCA N = Previous DCA Lot * 1.3)
   double initial_lot = CalculateDCALot(idx, next_dca_seq, lot_calculation_bal);

   // --- [QUAN TRỌNG] NẾU LOT = 0 (DO RISK = 0%), DỮNG NGAY ---
   if(initial_lot <= 0.0) return;

   // --- DETERMINE STRATEGY TYPE ---
   int strategy_type = GetStrategyType(entry_mode);

   // --- XAC DINH TP VA SL THEO CHE DO ---
   int sl_pips = 0;
   
   double entry_price = (signal == 1) ? SymbolInfoDouble(sym, SYMBOL_ASK)
                                      : SymbolInfoDouble(sym, SYMBOL_BID);

   // --- CALCULATE TP ---
   double tp_pips_d = 0.0;
   if(InpEnableDynamicTP)
   {
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
      G_Pairs[idx].chain_position_count = 1;
      G_Pairs[idx].chain_start_dca_seq = next_dca_seq;
      G_Pairs[idx].chain_end_dca_seq = next_dca_seq;
      G_Pairs[idx].chain_step_pips = dyn_step;
      G_Pairs[idx].locked_balance = lot_calculation_bal;

      // Cập nhật System DCA sequence (AUTHORITATIVE)
      SetSystemDCASeq(idx, next_dca_seq);

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

      // --- LOG BẮT BUỘC THEO SPEC ---
      string mode_str = is_recovery ? "RECOVERY" : "NORMAL";
      PrintFormat("[DCA-OPEN]\nSYMBOL=%s\nSTRATEGY=%s\nDCA_SEQUENCE=%d\nCHAIN_POSITION=%d\nMAX_CHAIN_POSITIONS=%d\nLOT=%.2f\nMODE=%s\nDEBT=%.2f",
                  sym, entry_mode, next_dca_seq, 1, InpMaxDCAPerChain, initial_lot, mode_str, current_debt);

      PrintFormat("[%s] >>> OPEN CHAIN [%s]: %.2f lots (Actual Bal: $%.2f, Ref Bal: $%.2f). ID: %I64u",
                  sym, entry_mode, initial_lot, current_bal, lot_calculation_bal, new_chain_id);
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

   // 1. Logic Khoảng cách
   int step_pips = G_Pairs[idx].chain_step_pips;
   if(step_pips <= 0) step_pips = InpDCA_MinStepPips; // Fallback an toàn
   double step = step_pips * G_Pairs[idx].pip_value;
   double current_price = (master_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);

   bool enough=false;
   if(master_type==POSITION_TYPE_BUY  && (current_price <= last_price - step)) enough=true;
   if(master_type==POSITION_TYPE_SELL && (current_price >= last_price + step)) enough=true;

   if(enough)
   {
      string strat = G_Pairs[idx].active_chain_strategy;
      if(strat == "") strat = "CT";
      
      // USE SYSTEM-LEVEL DCA sequence (AUTHORITATIVE)
      int current_dca_seq = GetSystemDCASeq(idx);
      int next_dca_seq    = current_dca_seq + 1;
      int cur_pos_count   = G_Pairs[idx].chain_position_count;

      // 2. CHECK CHAIN LIMIT: Không mở DCA vượt quá InpMaxDCAPerChain
      if(cur_pos_count >= InpMaxDCAPerChain)
      {
         PrintFormat("[CHAIN-LIMIT]\nDCA_SEQUENCE=%d\nCHAIN_POSITION=%d\nMAX_CHAIN_POSITIONS=%d\nNEXT_DCA_SEQUENCE=%d\nACTION=CLOSE_CHAIN",
                     current_dca_seq, cur_pos_count, InpMaxDCAPerChain, next_dca_seq);
         CloseAndResolveChain(idx, "MAX_DCA");
         return;
      }

      int next_chain_pos = cur_pos_count + 1;

      // 3. Tính Lot (Dùng Previous DCA Lot * InpHeSoLot hoặc CalculateDCALot)
      double working_balance = (G_Pairs[idx].locked_balance > 0) ? G_Pairs[idx].locked_balance : AccountInfoDouble(ACCOUNT_BALANCE);
      if(InpSetBalance > 0.0) working_balance = InpSetBalance;

      double new_lot = 0.0;
      if(last_lot > 0.0)
         new_lot = NormalizeLot(sym, last_lot * InpHeSoLot);
      else
         new_lot = CalculateDCALot(idx, next_dca_seq, working_balance);

      // 4. Mở lệnh
      string cmt = strat + " | DCA " + IntegerToString(next_dca_seq);
      bool res = OpenChildOrder_Multi(idx, master_type, new_lot, cmt);

      if(res)
      {
         G_Pairs[idx].chain_position_count = next_chain_pos;
         G_Pairs[idx].chain_end_dca_seq = next_dca_seq;
         // Update System DCA sequence (AUTHORITATIVE)
         SetSystemDCASeq(idx, next_dca_seq);
         
         SaveChainState_Multi(idx);

         double current_debt = GetSystemDebt(idx);
         string mode_str = IsSystemInRecovery(idx) ? "RECOVERY" : "NORMAL";

         // LOG BẮT BUỘC THEO SPEC
         PrintFormat("[DCA-OPEN]\nSYMBOL=%s\nSTRATEGY=%s\nDCA_SEQUENCE=%d\nCHAIN_POSITION=%d\nMAX_CHAIN_POSITIONS=%d\nLOT=%.2f\nMODE=%s\nDEBT=%.2f",
                     sym, strat, next_dca_seq, next_chain_pos, InpMaxDCAPerChain, new_lot, mode_str, current_debt);
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
               if(IsPairChainMagic(i, pos_magic) || (pos_magic == 0 && G_Pairs[i].active_chain_id != 0))
               {
                   count++;
                   pnl += ProfitOf(t);
                   if(found_chain_id == 0 && pos_magic > 0) found_chain_id = pos_magic;
                   
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

         ulong act_id = G_Pairs[i].active_chain_id;
         if(act_id == 0 && found_chain_id != 0) act_id = found_chain_id;
         if(act_id == 0 && GlobalVariableCheck("Yoogi_ActiveChainID_" + sym))
            act_id = (ulong)GlobalVariableGet("Yoogi_ActiveChainID_" + sym);
         if(act_id == 0) act_id = (ulong)(EA_MAGIC_NUMBER * 1000 + i);
         G_Pairs[i].active_chain_id = act_id;

         if(G_Pairs[i].chain_position_count == 0 || G_Pairs[i].active_chain_strategy == "")
         {
            LoadChainState_Multi(i, act_id);
         }
         else if(InpEnableDynamicTP && !G_TradeProfile[i].is_valid)
         {
            LoadTradeProfile(i, act_id);
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

            // USE SYSTEM-LEVEL debt (AUTHORITATIVE)
            double current_debt = GetSystemDebt(i);

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
             ResolveClosedChainFromHistory(i, G_Pairs[i].active_chain_id, "BROKER_CLOSE");
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
