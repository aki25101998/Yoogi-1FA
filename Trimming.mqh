//+------------------------------------------------------------------+
//|                                                   Trimming.mqh   |
//|                                                    Yoogi Trading |
//|          Logic Smart Trimming (Multi-Currency Support) (v10.0)   |
//+------------------------------------------------------------------+
#property strict

// ==================================================================
// HÀM PHỤ TRỢ: ĐẾM SỐ LỆNH THỰC TẾ TRONG CHUỖI CỦA 1 CẶP
// ==================================================================
int CountOrdersInChain(string sym, ulong chain_id)
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      // Kiểm tra Ticket hợp lệ, đúng Symbol, đúng Magic
      if(t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym)
         {
            if((ulong)PositionGetInteger(POSITION_MAGIC) == chain_id)
               count++;
         }
      }
   }
   return count;
}

// ==================================================================
// HÀM PHỤ TRỢ: TÌM LỆNH CŨ NHẤT (MỤC TIÊU ĐỂ TỈA)
// ==================================================================
ulong GetOldestTicketInChain(string sym, ulong chain_id)
{
   long oldest_time = LONG_MAX;
   ulong target_ticket = 0;

   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym)
         {
            if((ulong)PositionGetInteger(POSITION_MAGIC) == chain_id)
            {
               long time = (long)PositionGetInteger(POSITION_TIME);
               if(time < oldest_time)
               {
                  oldest_time = time;
                  target_ticket = t;
               }
            }
         }
      }
   }
   return target_ticket;
}

// ==================================================================
// LOGIC CỐT LÕI: TỈA LỆNH & GHI SỔ NỢ (THEO INDEX CẶP TIỀN)
// ==================================================================
void ApplySmartTrimming(int idx)
{
   // 1. Kiểm tra điều kiện kích hoạt
   if(!InpUseSmartTrim) return;
   
   // Lấy thông tin từ Global Context của cặp này
   string sym     = G_Pairs[idx].symbol;
   ulong chain_id = G_Pairs[idx].active_chain_id;
   
   if(chain_id == 0) return; // Không có chuỗi thì không tỉa

   // Vòng lặp an toàn: Cắt cho đến khi số lượng lệnh quay về mức cho phép
   while(CountOrdersInChain(sym, chain_id) > InpTrimTriggerOrders)
   {
      // A. Tìm mục tiêu (Lệnh cũ nhất của cặp này)
      ulong target_t = GetOldestTicketInChain(sym, chain_id);
      if(target_t == 0) break; 

      if(!SelectPosByTicket(target_t)) break;

      // B. Lấy thông tin trước khi cắt
      double current_vol    = PositionGetDouble(POSITION_VOLUME);
      double current_profit = ProfitOf(target_t); 

      // C. Tính khối lượng cần cắt (Normalize theo Symbol cụ thể)
      double trim_vol = NormalizeLot(sym, current_vol * (InpTrimPercentage / 100.0));
      double min_lot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);

      if(trim_vol < min_lot || InpTrimPercentage >= 99.9)
      {
         trim_vol = current_vol;
      }

      // D. Tính toán lỗ thực tế (Realized Loss)
      double ratio = trim_vol / current_vol;
      double realized_loss_now = current_profit * ratio;

      // E. Thực hiện hành động CẮT
      bool res = false;
      if(trim_vol >= current_vol)
      {
         res = trade.PositionClose(target_t);
         PrintFormat("[%s] >>> TRIM FULL: Đóng lệnh cũ nhất %d (%.2f lot).", sym, target_t, current_vol);
      }
      else
      {
         res = trade.PositionClosePartial(target_t, trim_vol);
         PrintFormat("[%s] >>> TRIM PARTIAL: Cắt %.2f lot của lệnh %d.", sym, trim_vol, target_t);
      }

      // F. Ghi sổ nợ & Lưu trữ (Persistence vào đúng struct của cặp)
      if(res)
      {
         // Nếu PnL < 0, cộng lỗ vào realized_bleed_loss theo strategy của chain này
         if(realized_loss_now < 0)
         {
            double loss_positive = -realized_loss_now;
            string strat = G_Pairs[idx].active_chain_strategy;
            double current_debt = 0.0;

            if(strat == "FT")
            {
               G_Pairs[idx].ft_realized_bleed_loss += loss_positive;
               current_debt = G_Pairs[idx].ft_realized_bleed_loss;
               GlobalVariableSet("Yoogi_FT_Debt_" + sym, current_debt);
            }
            else if(strat == "DUAL")
            {
               G_Pairs[idx].dual_realized_bleed_loss += loss_positive;
               current_debt = G_Pairs[idx].dual_realized_bleed_loss;
               GlobalVariableSet("Yoogi_DUAL_Debt_" + sym, current_debt);
            }
            else // Default or "CT"
            {
               G_Pairs[idx].ct_realized_bleed_loss += loss_positive;
               current_debt = G_Pairs[idx].ct_realized_bleed_loss;
               GlobalVariableSet("Yoogi_CT_Debt_" + sym, current_debt);
            }

            PrintFormat("[%s] > Ghi nợ (%s): +$%.2f. Tổng nợ %s cặp này: $%.2f", sym, strat, loss_positive, strat, current_debt);

            // LƯU NGAY VÀO Ổ CỨNG (Dùng tên biến persistent)
            GlobalVariableSet(GetVarName_Step(sym, chain_id),  (double)G_Pairs[idx].chain_dca_count);
         }

         Sleep(200);
      }
      else
      {
         PrintFormat("[%s] Lỗi: Không thể thực hiện lệnh Trim.", sym);
         break;
      }
   }
}
//+------------------------------------------------------------------+

