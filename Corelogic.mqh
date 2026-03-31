//+------------------------------------------------------------------+
//|                                                  CoreLogic.mqh   |
//|                                                  Yoogi Trading   |
//|   Logic giao dịch cốt lõi (v12.2 - Hardcoded Version)            |
//|   (Mode: Real Time + 10k Limit + 7 Pairs Support)                |
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
   if(ptype == POSITION_TYPE_BUY)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_ASK);
      res = trade.Buy(lot, sym, price, 0, 0, comment);
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      res = trade.Sell(lot, sym, price, 0, 0, comment);
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

   // --- [LOGIC REAL TIME] TÍNH LOT THEO BALANCE THỰC TẾ ---
   double current_bal = AccountInfoDouble(ACCOUNT_BALANCE);

   // Gọi hàm tính Lot từ Globals (Đã gán cứng Risk%)
   double initial_lot = CalculateAutoLot(idx, current_bal);

   // --- [QUAN TRỌNG] NẾU LOT = 0 (DO RISK = 0%), DỪNG NGAY ---
   if(initial_lot <= 0.0) return;

   // --- XAC DINH TP THEO CHE DO ---
   int tp_pips = InpMasterTPPips;  // Mac dinh Auto
   if(InpStrategyMode == STRATEGY_MANUAL)
   {
      tp_pips = InpManual_TP_Pips;
   }

   if(signal == 1)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(tp_pips > 0) tp = price + tp_pips * G_Pairs[idx].pip_value;
      res = trade.Buy(initial_lot, sym, price, sl, tp, comment);
   }
   else if(signal == -1)
   {
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      if(tp_pips > 0) tp = price - tp_pips * G_Pairs[idx].pip_value;
      res = trade.Sell(initial_lot, sym, price, sl, tp, comment);
   }

   if(res)
   {
      lastOpenTime = TimeCurrent();

      // Cập nhật trạng thái Global cho cặp này
      G_Pairs[idx].active_chain_id = new_chain_id;
      G_Pairs[idx].virtual_step    = 0;
      G_Pairs[idx].realized_bleed_loss = 0.0;

      // Lưu Balance thực tế làm mốc để DCA sau này
      G_Pairs[idx].locked_balance = current_bal;

      SaveChainState_Multi(idx);

      PrintFormat("[%s] >>> OPEN MASTER: %.2f lots (Actual Bal: $%.2f). ID: %I64u",
                  sym, initial_lot, current_bal, new_chain_id);
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
      if(InpManual_StepPips <= 0) return; // Manual + Step=0 -> TAT DCA
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

      // 3. Tính Lot (Dùng Locked Balance hoặc Fallback về Actual Balance)
      double working_balance = (G_Pairs[idx].locked_balance > 0) ? G_Pairs[idx].locked_balance : AccountInfoDouble(ACCOUNT_BALANCE);

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
// KIEM TRA HOP LUU DXY (CONVERGENCE CHECK)
// ==================================================================
int CheckDXYConvergence(int idx)
{
   int di = G_Pairs[idx].dxy_map_index;
   if(di < 0) return 0;

   int mainTrap = G_Pairs[idx].trapSignal;
   int dxyTrap  = G_DXY_TrapSignal[di];

   // Neu 1 trong 2 bay chua co tin hieu -> Cho tiep (vo han)
   if(mainTrap == 0 || dxyTrap == 0)
      return 0;

   // Ca 2 bay deu da co tin hieu -> Kiem tra
   bool converges = false;

   if(G_Pairs[idx].isUSDSecond)
   {
      // xxxUSD: Hop luu khi NGUOC CHIEU
      converges = (mainTrap != dxyTrap);
   }
   else if(G_Pairs[idx].isUSDFirst)
   {
      // USDxxx: Hop luu khi CUNG CHIEU
      converges = (mainTrap == dxyTrap);
   }

   if(converges)
   {
      int finalSignal = mainTrap;
      G_Pairs[idx].trapSignal = 0;
      G_DXY_TrapSignal[di] = 0;

      PrintFormat("DXY Filter: HOP LUU! %s Trap=%s, DXY Trap=%s -> Vao lenh %s",
                  G_Pairs[idx].symbol,
                  (mainTrap == 1 ? "BUY" : "SELL"),
                  (dxyTrap  == 1 ? "BUY" : "SELL"),
                  (finalSignal == 1 ? "BUY" : "SELL"));
      return finalSignal;
   }
   else
   {
      PrintFormat("DXY Filter: XUNG DOT! %s Trap=%s, DXY Trap=%s -> RESET!",
                  G_Pairs[idx].symbol,
                  (mainTrap == 1 ? "BUY" : "SELL"),
                  (dxyTrap  == 1 ? "BUY" : "SELL"));
      G_Pairs[idx].trapSignal = 0;
      G_DXY_TrapSignal[di] = 0;
      return 0;
   }
}

// ==================================================================
// HAM QUET VA DIEU PHOI (MAIN LOOP)
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

   // --- [FIX BUG 1] GOI DXY SIGNAL TRUOC VONG LAP CHINH ---
   // Goi 1 lan duy nhat cho moi DXY context, tranh bi "an mat" boi cap dau tien
   if(g_dxy_available && InpUseDXYReference)
   {
      for(int d = 0; d < DXY_CONTEXTS; d++)
      {
         int dxySignal = CheckEntrySignal_DXY(d);
         if(dxySignal != 0)
         {
            G_DXY_TrapSignal[d] = dxySignal;
            PrintFormat("DXY Filter: DXY(%s) dat bay %s",
                        EnumToString(G_DXY[d].tf), (dxySignal == 1 ? "BUY" : "SELL"));
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

         // --- TIM TIN HIEU MOI ---
         if(InpAutoSignalTrading && allow_new_entry && G_Pairs[i].enabled)
         {
            int mainSignal = CheckEntrySignal(i);
            int signal = 0;

            if(G_Pairs[i].isUSDPair && g_dxy_available && InpUseDXYReference)
            {
               // === DXY TRAP (CHI CAP USD) ===
               int di = G_Pairs[i].dxy_map_index;

               if(mainSignal != 0)
               {
                  G_Pairs[i].trapSignal = mainSignal;
                  PrintFormat("DXY Filter: %s dat bay %s",
                              G_Pairs[i].symbol, (mainSignal == 1 ? "BUY" : "SELL"));
               }

               // DXY da duoc check truoc vong lap, chi can check convergence
               signal = CheckDXYConvergence(i);
            }
            else
            {
               // === KHONG USD (EURGBP) -> Binh thuong ===
               signal = mainSignal;
            }

            if(signal != 0)
            {
               if(signal == 1  && !InpAllowBuy) continue;
               if(signal == -1 && !InpAllowSell) continue;

               PrintFormat("[%s] >>> Entry signal = %s. Opening trade...",
                           sym, (signal == 1 ? "BUY" : "SELL"));
               OpenMasterTrade_Multi(i, signal);
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
