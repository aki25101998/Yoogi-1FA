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
   int sl_pips = (InpStrategyMode == STRATEGY_MANUAL) ? InpManual_SL_Pips : 0;

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

   GlobalVariableSet(GetVarName_Bleed(sym, id), G_Pairs[idx].realized_bleed_loss);
   GlobalVariableSet(GetVarName_Step(sym, id),  (double)G_Pairs[idx].virtual_step);
   GlobalVariableSet(GetVarName_LockedBal(sym, id), G_Pairs[idx].locked_balance);
}

void LoadChainState_Multi(int idx, ulong chain_id)
{
   string sym = G_Pairs[idx].symbol;
   string n_bleed = GetVarName_Bleed(sym, chain_id);
   string n_step  = GetVarName_Step(sym, chain_id);
   string n_bal   = GetVarName_LockedBal(sym, chain_id);

   if(GlobalVariableCheck(n_bleed)) G_Pairs[idx].realized_bleed_loss = GlobalVariableGet(n_bleed);
   else                             G_Pairs[idx].realized_bleed_loss = 0.0;

   if(GlobalVariableCheck(n_step))  G_Pairs[idx].virtual_step = (int)GlobalVariableGet(n_step);
   else                             G_Pairs[idx].virtual_step = 0;

   if(GlobalVariableCheck(n_bal))   G_Pairs[idx].locked_balance = GlobalVariableGet(n_bal);
   else                             G_Pairs[idx].locked_balance = 0.0;
}

void ClearChainState_Multi(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

   if(id == 0) return;

   GlobalVariableDel(GetVarName_Bleed(sym, id));
   GlobalVariableDel(GetVarName_Step(sym, id));
   GlobalVariableDel(GetVarName_LockedBal(sym, id));

   // Reset memory
   G_Pairs[idx].realized_bleed_loss = 0.0;
   G_Pairs[idx].virtual_step = 0;
   G_Pairs[idx].locked_balance = 0.0;
   G_Pairs[idx].active_chain_id = 0;
}

void CloseAllInChain_Multi(int idx)
{
   string sym = G_Pairs[idx].symbol;
   ulong  id  = G_Pairs[idx].active_chain_id;

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
   ClearChainState_Multi(idx);
}

// ==================================================================
// MỞ LỆNH MASTER (TẠO CHUỖI MỚI)
// ==================================================================
void OpenMasterTrade_Multi(int idx, int signal)
{
   string sym = G_Pairs[idx].symbol;

   // Kiểm tra thời gian (tránh spam lệnh)
   static ulong lastOpenTime = 0;
   if(TimeCurrent() - lastOpenTime < 2) return;

   if(!IsTradable(sym)) return;

   ulong new_chain_id = (ulong)TimeCurrent(); // Tạo ID mới dựa trên thời gian
   trade.SetExpertMagicNumber(new_chain_id);

   // --- CẬP NHẬT COMMENT TẠI ĐÂY ---
   string comment = " Yoogi One For All ";
   bool   res     = false;
   double sl=0.0, tp=0.0;

   // --- [LOGIC REAL TIME] TÍNH LOT THEO BALANCE THỰC TẾ HOẶC THỦ CÔNG ---
   double current_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot_calculation_bal = current_bal;

   if(InpStrategyMode == STRATEGY_MANUAL && InpManual_Balance > 0.0)
   {
      lot_calculation_bal = InpManual_Balance;
   }

   // Gọi hàm tính Lot từ Globals (Đã gán cứng Risk%)
   double initial_lot = CalculateAutoLot(idx, lot_calculation_bal);

   // --- [QUAN TRỌNG] NẾU LOT = 0 (DO RISK = 0%), DỪNG NGAY ---
   if(initial_lot <= 0.0) return;

   // --- XAC DINH TP VA SL THEO CHE DO ---
   int tp_pips = InpMasterTPPips;  // Mac dinh Auto
   int sl_pips = 0;
   if(InpStrategyMode == STRATEGY_MANUAL)
   {
      tp_pips = InpManual_TP_Pips;
      sl_pips = InpManual_SL_Pips;
   }

   if(signal == 1)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(tp_pips > 0) tp = price + tp_pips * G_Pairs[idx].pip_value;
      if(sl_pips > 0) sl = price - sl_pips * G_Pairs[idx].pip_value;
      res = trade.Buy(initial_lot, sym, price, sl, tp, comment);
   }
   else if(signal == -1)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      if(tp_pips > 0) tp = price - tp_pips * G_Pairs[idx].pip_value;
      if(sl_pips > 0) sl = price + sl_pips * G_Pairs[idx].pip_value;
      res = trade.Sell(initial_lot, sym, price, sl, tp, comment);
   }

   if(res)
   {
      lastOpenTime = TimeCurrent();

      // Cập nhật trạng thái Global cho cặp này
      G_Pairs[idx].active_chain_id = new_chain_id;
      G_Pairs[idx].virtual_step    = 0;
      G_Pairs[idx].realized_bleed_loss = 0.0;

      // Lưu Balance lấy tính Lot làm mốc để DCA sau này
      G_Pairs[idx].locked_balance = lot_calculation_bal;

      // Reset HTF trap sau khi vào lệnh thành công
      G_Pairs[idx].htf_trap_signal = 0;

      SaveChainState_Multi(idx);

      PrintFormat("[%s] >>> OPEN MASTER: %.2f lots (Actual Bal: $%.2f, Ref Bal: $%.2f). ID: %I64u",
                  sym, initial_lot, current_bal, lot_calculation_bal, new_chain_id);
   }
}

// ==================================================================
// DCA TREND (MULTI-SYMBOL)
// ==================================================================
void ManageTrendDCA_Multi(int idx, int current_orders, ENUM_POSITION_TYPE master_type)
{
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

   // 2. Logic Khoảng cách (Manual cho phep tuy chinh, Auto dung mac dinh)
   int step_pips = InpKhoangMoPip; // Mac dinh Auto = 30
   if(InpStrategyMode == STRATEGY_MANUAL)
   {
      if(!InpManual_DCA) return;          // Manual tắt DCA -> Tắt tính năng nhồi
      if(InpManual_StepPips <= 0) return; // Manual + Step=0 -> Tắt DCA
      step_pips = InpManual_StepPips;
   }
   double step = step_pips * G_Pairs[idx].pip_value;
   double current_price = (master_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);

   bool enough=false;
   if(master_type==POSITION_TYPE_BUY  && (current_price <= last_price - step)) enough=true;
   if(master_type==POSITION_TYPE_SELL && (current_price >= last_price + step)) enough=true;

   if(enough)
   {
      int next_step_index = G_Pairs[idx].virtual_step + 1;

      // KIỂM TRA GIỚI HẠN SỐ LỆNH VÀ CẮT LỖ CHUỖI NẾU VƯỢT QUÁ (CHẾ ĐỘ THỦ CÔNG)
      if(InpStrategyMode == STRATEGY_MANUAL && InpManual_MaxOrders > 0)
      {
         if(next_step_index >= InpManual_MaxOrders)
         {
             PrintFormat("[%s] >>> Gia tiep tuc di nguoc. Dat muc mo lenh thu %d nhung MaxOrders chi la %d. Tien hanh cat lo chuoi!", sym, next_step_index + 1, InpManual_MaxOrders);
             CloseAllInChain_Multi(idx);
             return;
         }
      }

      // 3. Tính Lot (Dùng Locked Balance hoặc Fallback về Actual Balance)
      double working_balance = (G_Pairs[idx].locked_balance > 0) ? G_Pairs[idx].locked_balance : AccountInfoDouble(ACCOUNT_BALANCE);

      if(InpStrategyMode == STRATEGY_MANUAL && InpManual_Balance > 0.0)
      {
         working_balance = InpManual_Balance;
      }

      double base_lot = CalculateAutoLot(idx, working_balance);

      double calculated_lot = base_lot * MathPow(InpHeSoLot, next_step_index);
      double new_lot = NormalizeLot(sym, calculated_lot);

      // 4. Mở lệnh
      string cmt = "DCA Step " + IntegerToString(next_step_index);
      bool res = OpenChildOrder_Multi(idx, master_type, new_lot, cmt);

      if(res)
      {
         G_Pairs[idx].virtual_step = next_step_index;
         SaveChainState_Multi(idx);

         PrintFormat("[%s] >>> DCA Step %d: %.2f lots. Ref Bal: $%.2f", sym, next_step_index, new_lot, working_balance);

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
         if(dxyHTF != 0)
         {
            G_DXY_TrapSignal_HTF[d] = dxyHTF;
            PrintFormat("DXY Filter: DXY HTF(%s) dat bay %s",
                        EnumToString(G_DXY_HTF[d].ltf), (dxyHTF == 1 ? "BUY" : "SELL"));
         }

         // DXY LTF Signal
         int dxyLTF = CheckEntrySignal_DXY_LTF(d);
         if(dxyLTF != 0)
         {
            G_DXY_TrapSignal_LTF[d] = dxyLTF;
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

      for(int k = PositionsTotal()-1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym)
            {
               count++;
               pnl += ProfitOf(t);
               ulong pos_magic = (ulong)PositionGetInteger(POSITION_MAGIC);
               if(pos_magic != 0)
                  found_chain_id = pos_magic;

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

      // B. XU LY LOGIC
      if(count > 0)
      {
         activeChainsCount++;

         // Neu chi co lenh tay (magic=0), tao chain_id gia de EA quan ly
         if(found_chain_id == 0)
            found_chain_id = (ulong)TimeCurrent();

         if(G_Pairs[i].active_chain_id == 0)
         {
            G_Pairs[i].active_chain_id = found_chain_id;
            LoadChainState_Multi(i, found_chain_id);
         }

         double working_balance = (G_Pairs[i].locked_balance > 0) ? G_Pairs[i].locked_balance : real_balance;
         double base_tp_usd = CalculateAutoTP(sym, working_balance);
         double total_target = base_tp_usd + G_Pairs[i].realized_bleed_loss;

         if(pnl >= total_target)
         {
            PrintFormat("[%s] >>> TAKE PROFIT: $%.2f (Target $%.2f). Closing...", sym, pnl, total_target);
            CloseAllInChain_Multi(i);
            continue;
         }

         ApplySmartTrimming(i);
         ManageTrendDCA_Multi(i, count, m_type);
      }
      else
      {
         if(G_Pairs[i].active_chain_id != 0) ClearChainState_Multi(i);

         // --- TIM TIN HIEU MOI (MTF DUAL SIGNAL HOAC REVERSAL ENGINE) ---
         if(InpAutoSignalTrading && allow_new_entry && G_Pairs[i].enabled)
         {
            if(InpUseReversalEngine)
            {
               // =============================================
               // REVERSAL ENGINE V1 (NEW LOGIC)
               // =============================================
               int revSignal = CheckReversalSignal(i);
               
               if(revSignal != 0)
               {
                  int signal = 0;
                  if(G_Pairs[i].isUSDPair && g_dxy_available && InpUseDXYReference)
                  {
                     // === DXY TRAP (CHI CAP USD) ===
                     G_Pairs[i].trapSignal = revSignal;
                     signal = CheckDXYConvergence_Dual(i);
                  }
                  else
                  {
                     // === KHONG USD (EURGBP) -> Binh thuong ===
                     signal = revSignal;
                  }
                  
                  if(signal != 0)
                  {
                     if(signal == 1  && !InpAllowBuy) continue;
                     if(signal == -1 && !InpAllowSell) continue;

                     PrintFormat("[%s] >>> REVERSAL ENGINE CONFIRMED: Opening %s trade...",
                                 sym, (signal == 1 ? "BUY" : "SELL"));
                     OpenMasterTrade_Multi(i, signal);
                  }
               }
            }
            else
            {
               // =============================================
               // BUOC 1: CHECK HTF SIGNAL (Xu huong) - OLD LOGIC
               // =============================================
               int htfSignal = CheckEntrySignal_HTF(i);
               if(htfSignal != 0)
               {
                  // Neu HTF phat tin hieu moi
                  if(G_Pairs[i].htf_trap_signal != 0 && G_Pairs[i].htf_trap_signal != htfSignal)
                  {
                     // HTF dao chieu -> Reset bay cu
                     PrintFormat("[%s] HTF dao chieu %s -> %s. Reset bay.",
                                 sym,
                                 (G_Pairs[i].htf_trap_signal == 1 ? "BUY" : "SELL"),
                                 (htfSignal == 1 ? "BUY" : "SELL"));
                  }
                  G_Pairs[i].htf_trap_signal = htfSignal;
                  PrintFormat("[%s] >>> HTF Signal: %s (Bay dat thanh cong)",
                              sym, (htfSignal == 1 ? "BUY" : "SELL"));
               }
   
               // =============================================
               // BUOC 2: CHECK LTF SIGNAL (Entry) - Chi khi HTF da co bay
               // =============================================
               if(G_Pairs[i].htf_trap_signal != 0)
               {
                  int ltfSignal = CheckEntrySignal(i);
   
                  if(ltfSignal != 0 && ltfSignal == G_Pairs[i].htf_trap_signal)
                  {
                     // LTF xac nhan cung huong voi HTF!
                     int confirmed_signal = ltfSignal;
   
                     PrintFormat("[%s] >>> LTF xac nhan %s (Cung huong HTF). Tim DXY...",
                                 sym, (confirmed_signal == 1 ? "BUY" : "SELL"));
   
                     // =============================================
                     // BUOC 3: DXY CONVERGENCE (Dual TF)
                     // =============================================
                     int signal = 0;
   
                     if(G_Pairs[i].isUSDPair && g_dxy_available && InpUseDXYReference)
                     {
                        // === DXY TRAP (CHI CAP USD) ===
                        G_Pairs[i].trapSignal = confirmed_signal;
   
                        // DXY da duoc pre-scan, chi can check convergence
                        signal = CheckDXYConvergence_Dual(i);
                     }
                     else
                     {
                        // === KHONG USD (EURGBP) -> Binh thuong ===
                        signal = confirmed_signal;
                     }
   
                     if(signal != 0)
                     {
                        if(signal == 1  && !InpAllowBuy) continue;
                        if(signal == -1 && !InpAllowSell) continue;
   
                        PrintFormat("[%s] >>> MTF CONFIRMED: HTF=%s + LTF=%s. Opening trade...",
                                    sym,
                                    (G_Pairs[i].htf_trap_signal == 1 ? "BUY" : "SELL"),
                                    (ltfSignal == 1 ? "BUY" : "SELL"));
                        OpenMasterTrade_Multi(i, signal);
                     }
                  }
                  else if(ltfSignal != 0 && ltfSignal != G_Pairs[i].htf_trap_signal)
                  {
                     // LTF phat tin hieu NGUOC huong HTF -> Bo qua
                     PrintFormat("[%s] LTF Signal %s nguoc HTF %s -> Bo qua.",
                                 sym,
                                 (ltfSignal == 1 ? "BUY" : "SELL"),
                                 (G_Pairs[i].htf_trap_signal == 1 ? "BUY" : "SELL"));
                  }
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
