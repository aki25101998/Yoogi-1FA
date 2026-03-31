import io, re

def replace_in_file(file_path):
    with io.open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Pattern 1
    p1 = """      G_Pairs[i].tf = GetFixedTimeframe(G_Pairs[i].base_name);

      // --- GAN CUNG RISK % ---
      if(G_Pairs[i].base_name == "EURUSD")      G_Pairs[i].risk_percent = 0.4;
      else if(G_Pairs[i].base_name == "AUDUSD") G_Pairs[i].risk_percent = 0.6;
      else if(G_Pairs[i].base_name == "EURGBP") G_Pairs[i].risk_percent = 0.5;
      else if(G_Pairs[i].base_name == "USDCAD") G_Pairs[i].risk_percent = 0.4;
      else if(G_Pairs[i].base_name == "USDCHF") G_Pairs[i].risk_percent = 0.3;
      else G_Pairs[i].risk_percent = 0.0;"""
      
    r1 = """      if(InpStrategyMode == STRATEGY_MANUAL)
      {
         // --- CHE DO THU CONG ---
         if(G_Pairs[i].base_name == "EURUSD")      { G_Pairs[i].risk_percent = InpEURUSD_Risk; G_Pairs[i].tf = InpEURUSD_TF; }
         else if(G_Pairs[i].base_name == "AUDUSD") { G_Pairs[i].risk_percent = InpAUDUSD_Risk; G_Pairs[i].tf = InpAUDUSD_TF; }
         else if(G_Pairs[i].base_name == "USDCAD") { G_Pairs[i].risk_percent = InpUSDCAD_Risk; G_Pairs[i].tf = InpUSDCAD_TF; }
         else if(G_Pairs[i].base_name == "EURGBP") { G_Pairs[i].risk_percent = InpEURGBP_Risk; G_Pairs[i].tf = InpEURGBP_TF; }
         else if(G_Pairs[i].base_name == "USDCHF") { G_Pairs[i].risk_percent = InpUSDCHF_Risk; G_Pairs[i].tf = InpUSDCHF_TF; }
         else { G_Pairs[i].risk_percent = 0.0; G_Pairs[i].tf = PERIOD_H4; }
      }
      else
      {
         // --- CHE DO TU DONG ---
         G_Pairs[i].tf = GetFixedTimeframe(G_Pairs[i].base_name);
         if(G_Pairs[i].base_name == "EURUSD")      G_Pairs[i].risk_percent = 0.4;
         else if(G_Pairs[i].base_name == "AUDUSD") G_Pairs[i].risk_percent = 0.6;
         else if(G_Pairs[i].base_name == "EURGBP") G_Pairs[i].risk_percent = 0.5;
         else if(G_Pairs[i].base_name == "USDCAD") G_Pairs[i].risk_percent = 0.4;
         else if(G_Pairs[i].base_name == "USDCHF") G_Pairs[i].risk_percent = 0.3;
         else G_Pairs[i].risk_percent = 0.0;
      }"""
      
    # Pattern 2
    p2 = """      // Map DXY context theo TF: H4 -> index 0, H2 -> index 1
      if(G_Pairs[i].isUSDPair)
      {
         if(G_Pairs[i].tf == PERIOD_H4)      G_Pairs[i].dxy_map_index = 0;
         else if(G_Pairs[i].tf == PERIOD_H2) G_Pairs[i].dxy_map_index = 1;
      }"""
      
    r2 = """      // Map DXY context 1:1 theo index cua cap tien
      if(G_Pairs[i].isUSDPair)
      {
         G_Pairs[i].dxy_map_index = i;
      }"""
      
    # Pattern 3
    p3 = r'(?sm)^[ \t]*// DXY Context 0: H4.*?DXY_TrapSignal\[1\] = 0;'
    r3 = """      for (int k = 0; k < DXY_CONTEXTS; k++)
      {
         // Neu index k trung hop do la ma USD thi moi co the init
         if(k < TOTAL_PAIRS && !G_Pairs[k].isUSDPair) continue;
         
         G_DXY[k].symbol = dxy_broker;
         G_DXY[k].base_name = DXY_SYMBOL;
         
         // Dong bo Timeframe cua DXY giong voi Timeframe cua cap tien luon
         G_DXY[k].tf = G_Pairs[k].tf; 

         G_DXY[k].handle_cci = INVALID_HANDLE;
         G_DXY[k].isReadyForBuy = false;
         G_DXY[k].isReadyForSell = false;
         G_DXY[k].g_inited_filt = false;
         G_DXY[k].last_bar_time = 0;
         G_DXY_TrapSignal[k] = 0;
      }"""

    # Fix line endings just in case
    content = content.replace("\r\n", "\n")
    p1 = p1.replace("\r\n", "\n")
    r1 = r1.replace("\r\n", "\n")
    p2 = p2.replace("\r\n", "\n")
    r2 = r2.replace("\r\n", "\n")
    
    # Simple replace
    new_content = content.replace(p1, r1)
    new_content = new_content.replace(p2, r2)
    # Regex replace for p3
    new_content = re.sub(p3, r3, new_content, count=1)
    
    # Also replace Contexts log
    new_content = new_content.replace("Print(\"DXY Filter: Symbol = \", dxy_broker, \" | Contexts: H4 (idx 0), H2 (idx 1)\");", "Print(\"DXY Filter: Symbol = \", dxy_broker, \" | Contexts: 5 (Dynamic Timeframes)\");")

    with io.open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
        
    print(f"Modifications applied: lengths (old={len(content)}, new={len(new_content)})")

replace_in_file(r"d:\Project\yoogi 1fa\Globals.mqh")
