//+------------------------------------------------------------------+
//|                                              InfoDisplay.mqh     |
//|                                                  Yoogi Trading   |
//|         Trading Control Dashboard — "Yoogi One For All"          |
//+------------------------------------------------------------------+
#property strict

#include "ReversalDisplayData.mqh"

// ==================================================================
// 1. CONFIGURATION & LAYOUT TOKENS
// ==================================================================
#define INFO_PREFIX "YDG_Mother_"
#define BG_PREFIX   "YDG_BG_"

// --- CORNER & ANCHOR (FIXED, NO SHIFTING) ---
const ENUM_BASE_CORNER DASH_CORNER = CORNER_LEFT_LOWER;
const int    DASH_X          = 20;   // X Base Offset
const int    DASH_Y          = 485;  // Y Base Offset (Top anchor in LEFT_LOWER)
const int    DASH_LINE_H     = 16;   // Standard Line Height
const int    TABLE_ROW_H     = 16;   // Table Row Height
const int    FONT_SIZE       = 10;   // Data Font Size
const int    FONT_TITLE_SIZE = 12;   // Main Title Font Size
const int    FONT_SEC_SIZE   = 10;   // Section Title Font Size
const string FONT_NAME       = "Consolas";

// --- BACKGROUND PANEL ---
const bool   USE_BACK        = true;
const color  C_BACK          = C'15,22,28';  // Deep Slate Charcoal
const int    BACK_W          = 625;
const int    BACK_H          = 495;
const int    BACK_OFF_X      = -10;
const int    BACK_OFF_Y      = 12;

// --- COLOR PALETTE (CONSISTENT VISUAL LANGUAGE) ---
const color  C_HEADER        = clrGold;
const color  C_SECTION       = clrGold;
const color  C_TEXT          = clrWhite;
const color  C_SUB           = clrLightGray;
const color  C_VALUE         = clrLime;
const color  C_WARN          = clrIndianRed;
const color  C_LIMIT         = clrOrange;
const color  C_SEP           = C'65,75,85';

// Table Row Colors
const color  R_PROFIT        = clrLime;
const color  R_LOSS          = clrIndianRed;
const color  R_DEBT          = clrOrange;

// --- TEXT LABELS ---
const string TXT_HEADER      = "=== YOOGI ONE FOR ALL ===";
const string TXT_FOOTER      = "YOOGI 1FA — TRADE FOR LIVING";
const string TXT_SEP_SYM     = "|";

// Table Columns X Offsets
const int P_PAIR = 0;
const int P_SEP1 = 52;
const int P_MODE = 60;
const int P_SEP2 = 96;
const int P_DIR  = 104;
const int P_SEP3 = 140;
const int P_SCOR = 148;
const int P_SEP4 = 208;
const int P_STAT = 216;
const int P_SEP5 = 328;
const int P_NEXT = 336;
const int P_SEP6 = 448;
const int P_CHN  = 456;
const int P_SEP7 = 514;
const int P_PNL  = 522;

// ==================================================================
// 2. FORWARD DECLARATIONS
// ==================================================================
void CreateDisplay();
void UpdateDisplay();
void DeleteDisplay();

void CreateLabel(string name, string text, int x, int y, int corner, int font_size, color clr, bool bold = false);
void CreatePanel(string name, int x, int y, int w, int h, int corner, color bg_clr);
void SetLabelText(string name, string text, color clr);

//+------------------------------------------------------------------+
//| CREATE DASHBOARD DISPLAY (CREATE ONCE)                           |
//+------------------------------------------------------------------+
void CreateDisplay()
{
   DeleteDisplay();

   // 0. BACKGROUND PANEL
   if(USE_BACK)
   {
      int bg_x = DASH_X + BACK_OFF_X;
      int bg_y = DASH_Y + BACK_OFF_Y;
      CreatePanel(BG_PREFIX + "Main", bg_x, bg_y, BACK_W, BACK_H, DASH_CORNER, C_BACK);
   }

   int y = DASH_Y;
   int x = DASH_X;

   // 1. MAIN TITLE
   CreateLabel(INFO_PREFIX + "Header", TXT_HEADER, x + 160, y, DASH_CORNER, FONT_TITLE_SIZE, C_HEADER, true);
   y -= 22;

   // ===============================================================
   // SECTION A — SYSTEM SUMMARY
   // ===============================================================
   CreateLabel(INFO_PREFIX + "SecA_Title", "=== SYSTEM SUMMARY ===", x, y, DASH_CORNER, FONT_SEC_SIZE, C_SECTION, true);
   y -= 17;

   int col1_lbl = x;
   int col1_val = x + 115;
   int col2_lbl = x + 310;
   int col2_val = x + 420;

   // Row A1: Balance & DXY
   CreateLabel(INFO_PREFIX + "Sys_Bal_Lbl",  "Balance     :", col1_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_Bal_Val",  "$0.00",        col1_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   CreateLabel(INFO_PREFIX + "Sys_DXY_Lbl",  "DXY         :", col2_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_DXY_Val",  "--",           col2_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // Row A2: Virtual Balance & CT
   CreateLabel(INFO_PREFIX + "Sys_VBal_Lbl", "Virtual Bal :", col1_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_VBal_Val", "$0.00",        col1_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   CreateLabel(INFO_PREFIX + "Sys_CT_Lbl",   "CT Engine   :", col2_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_CT_Val",   "ACTIVE",       col2_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // Row A3: Debt & FT
   CreateLabel(INFO_PREFIX + "Sys_Debt_Lbl", "Total Debt  :", col1_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_Debt_Val", "$0.00",        col1_val, y, DASH_CORNER, FONT_SIZE, C_LIMIT);
   CreateLabel(INFO_PREFIX + "Sys_FT_Lbl",   "FT Engine   :", col2_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_FT_Val",   "ACTIVE",       col2_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // Row A4: Active Chains & DCA
   CreateLabel(INFO_PREFIX + "Sys_Chain_Lbl","Active Chns :", col1_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_Chain_Val","0",            col1_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   CreateLabel(INFO_PREFIX + "Sys_DCA_Lbl",  "DCA Mode    :", col2_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_DCA_Val",  "ALWAYS ON",    col2_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // Row A5: Risk & Dynamic TP
   CreateLabel(INFO_PREFIX + "Sys_Risk_Lbl", "Risk / Pair :", col1_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_Risk_Val", "0.5%",         col1_val, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   CreateLabel(INFO_PREFIX + "Sys_DynTP_Lbl","Dynamic TP  :", col2_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_DynTP_Val","ACTIVE",       col2_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= (DASH_LINE_H + 5);

   // ===============================================================
   // SECTION B — PAIR MONITOR
   // ===============================================================
   CreateLabel(INFO_PREFIX + "SecB_Title", "=== PAIR MONITOR ===", x, y, DASH_CORNER, FONT_SEC_SIZE, C_SECTION, true);
   y -= 17;

   // Table Column Headers
   CreateLabel(INFO_PREFIX + "H_Pair",  "PAIR",      x + P_PAIR, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep1",  TXT_SEP_SYM, x + P_SEP1, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Mode",  "MODE",      x + P_MODE, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep2",  TXT_SEP_SYM, x + P_SEP2, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Dir",   "DIR",       x + P_DIR,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep3",  TXT_SEP_SYM, x + P_SEP3, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Score", "SCORE",     x + P_SCOR, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep4",  TXT_SEP_SYM, x + P_SEP4, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Stat",  "STATE",     x + P_STAT, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep5",  TXT_SEP_SYM, x + P_SEP5, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Next",  "NEXT GATE", x + P_NEXT, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep6",  TXT_SEP_SYM, x + P_SEP6, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Chain", "CHAIN",     x + P_CHN,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep7",  TXT_SEP_SYM, x + P_SEP7, y, DASH_CORNER, FONT_SIZE, C_SEP);
   CreateLabel(INFO_PREFIX + "H_Pnl",   "P/L",       x + P_PNL,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= TABLE_ROW_H;

   // Table Data Rows
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string r = IntegerToString(i);
      CreateLabel(INFO_PREFIX + "R"+r+"_Pair",  "-",         x + P_PAIR, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep1",  TXT_SEP_SYM, x + P_SEP1, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Mode",  "-",         x + P_MODE, y, DASH_CORNER, FONT_SIZE, C_SUB);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep2",  TXT_SEP_SYM, x + P_SEP2, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Dir",   "-",         x + P_DIR,  y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep3",  TXT_SEP_SYM, x + P_SEP3, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Score", "-",         x + P_SCOR, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep4",  TXT_SEP_SYM, x + P_SEP4, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_State", "-",         x + P_STAT, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep5",  TXT_SEP_SYM, x + P_SEP5, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Next",  "-",         x + P_NEXT, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep6",  TXT_SEP_SYM, x + P_SEP6, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Chain", "--",        x + P_CHN,  y, DASH_CORNER, FONT_SIZE, C_SUB);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep7",  TXT_SEP_SYM, x + P_SEP7, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Pnl",   "--",        x + P_PNL,  y, DASH_CORNER, FONT_SIZE, C_SUB);
      y -= TABLE_ROW_H;
   }
   y -= 5;

   // ===============================================================
   // SECTION C — ACTIVE CHAIN PANEL
   // ===============================================================
   CreateLabel(INFO_PREFIX + "SecC_Title", "=== ACTIVE CHAIN ===", x, y, DASH_CORNER, FONT_SEC_SIZE, C_SECTION, true);
   y -= 17;

   CreateLabel(INFO_PREFIX + "Chain_L1", "No active chain", x, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= DASH_LINE_H;
   CreateLabel(INFO_PREFIX + "Chain_L2", " ",               x, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= DASH_LINE_H;
   CreateLabel(INFO_PREFIX + "Chain_L3", " ",               x, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= (DASH_LINE_H + 5);

   // ===============================================================
   // SECTION D — ENTRY / DEBUG DETAIL
   // ===============================================================
   CreateLabel(INFO_PREFIX + "SecD_Title", "=== ENTRY ANALYSIS ===", x, y, DASH_CORNER, FONT_SEC_SIZE, C_SECTION, true);
   y -= 17;

   CreateLabel(INFO_PREFIX + "Entry_L1", "Strategy : --   | Direction : --   | Score : --/100 | Mode : --", x, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   y -= DASH_LINE_H;
   CreateLabel(INFO_PREFIX + "Entry_L2", "State    : --   | Readiness : --   | Next Gate : --",             x, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   y -= DASH_LINE_H;
   CreateLabel(INFO_PREFIX + "Entry_L3", "Block Reason : NONE",                                             x, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;
   CreateLabel(INFO_PREFIX + "Entry_L4", "Score Breakdown: --",                                             x, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= (DASH_LINE_H + 6);

   // ===============================================================
   // FOOTER
   // ===============================================================
   CreateLabel(INFO_PREFIX + "Sep_Foot", "--------------------------------------------------------------------------------", x, y, DASH_CORNER, FONT_SIZE, C_SEP);
   y -= 15;
   CreateLabel(INFO_PREFIX + "Footer", TXT_FOOTER, x + 175, y, DASH_CORNER, FONT_SIZE + 1, C_HEADER, true);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD DISPLAY (UPDATE PROPERTIES ONLY - NO LAG)       |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   if(ObjectFind(0, INFO_PREFIX + "Header") < 0)
   {
      CreateDisplay();
      return;
   }

   // 1. ACCOUNT BALANCES & SYSTEM STATS
   double real_bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double total_debt = GetTotalSystemDebt();
   double virt_bal   = real_bal + total_debt;

   SetLabelText(INFO_PREFIX + "Sys_Bal_Val",  StringFormat("$%.2f", real_bal), C_VALUE);
   SetLabelText(INFO_PREFIX + "Sys_VBal_Val", StringFormat("$%.2f", virt_bal), C_VALUE);
   SetLabelText(INFO_PREFIX + "Sys_Debt_Val", StringFormat("$%.2f", total_debt), (total_debt > 0.01 ? C_LIMIT : C_VALUE));
   SetLabelText(INFO_PREFIX + "Sys_Risk_Val", StringFormat("%.1f%%", G_Pairs[0].risk_percent), C_TEXT);

   bool ct_on = (InpEnableCounterTrend && InpUseReversalEngine);
   bool ft_on = InpEnableTrendFollowing;
   SetLabelText(INFO_PREFIX + "Sys_CT_Val",    (ct_on ? "ACTIVE" : "OFF"), (ct_on ? C_VALUE : C_WARN));
   SetLabelText(INFO_PREFIX + "Sys_FT_Val",    (ft_on ? "ACTIVE" : "OFF"), (ft_on ? C_VALUE : C_WARN));
   SetLabelText(INFO_PREFIX + "Sys_DCA_Val",   "ALWAYS ON", C_VALUE);
   SetLabelText(INFO_PREFIX + "Sys_DynTP_Val", (InpEnableDynamicTP ? "ACTIVE" : "OFF"), (InpEnableDynamicTP ? C_VALUE : C_WARN));

   // DXY Status/Price
   if(!InpUseDXYReference)
   {
      SetLabelText(INFO_PREFIX + "Sys_DXY_Val", "DISABLED", C_WARN);
   }
   else if(g_dxy_available)
   {
      double dxy_bid = SymbolInfoDouble(DXY_SYMBOL, SYMBOL_BID);
      if(dxy_bid > 0.0)
      {
         int dxy_dig = (int)SymbolInfoInteger(DXY_SYMBOL, SYMBOL_DIGITS);
         string dxy_str = DoubleToString(dxy_bid, (dxy_dig > 0 ? dxy_dig : 2));
         SetLabelText(INFO_PREFIX + "Sys_DXY_Val", dxy_str, C_VALUE);
      }
      else
      {
         SetLabelText(INFO_PREFIX + "Sys_DXY_Val", "CONNECTED", C_VALUE);
      }
   }
   else
   {
      SetLabelText(INFO_PREFIX + "Sys_DXY_Val", "NOT FOUND", C_WARN);
   }

   // 2. SCAN CHAINS & UPDATE PAIR MONITOR ROWS
   int total_active_chains = 0;
   int primary_active_pair = -1;
   int focus_pair = -1;
   double highest_score = -1.0;
   int highest_progress = -1;

   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string sym = G_Pairs[i].symbol;
      ulong expected_magic = EA_MAGIC_NUMBER * 1000 + i;

      // Scan open positions
      int pair_orders = 0;
      double pair_pnl = 0.0;
      for(int k = PositionsTotal() - 1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym)
            {
               ulong pos_magic = (ulong)PositionGetInteger(POSITION_MAGIC);
               if(pos_magic == expected_magic || pos_magic == G_Pairs[i].active_chain_id || (pos_magic == 0 && G_Pairs[i].active_chain_id != 0))
               {
                  pair_orders++;
                  pair_pnl += ProfitOf(t);
               }
            }
         }
      }

      bool pair_has_chain = (pair_orders > 0);
      if(pair_has_chain)
      {
         total_active_chains++;
         if(primary_active_pair < 0)
         {
            primary_active_pair = i;
         }
         else if(StringFind(sym, _Symbol) >= 0 || StringFind(_Symbol, G_Pairs[i].base_name) >= 0)
         {
            primary_active_pair = i;
         }
      }

      // Build data presentation
      ReversalDisplayData data;
      BuildReversalDisplayData(i, data);

      string r = IntegerToString(i);
      string sym_short = G_Pairs[i].base_name;

      string s_pair  = StringFormat("%-6s", sym_short);
      string s_mode  = StringFormat("%-4s", data.displayMode);
      string s_dir   = StringFormat("%-4s", data.displayDir);
      string s_score = StringFormat("%7s", data.displayScoreStr);
      string s_state = StringFormat("%-14s", StringSubstr(data.displayState, 0, 14));
      string s_next  = StringFormat("%-14s", StringSubstr(data.displayNextGate, 0, 14));

      string s_chain = "--";
      string s_pnl   = "--";
      if(pair_has_chain)
      {
         ulong cid = (G_Pairs[i].active_chain_id > 0) ? G_Pairs[i].active_chain_id : expected_magic;
         s_chain = StringFormat("#%I64u", cid);
         s_pnl = StringFormat("%s$%.2f", (pair_pnl >= 0 ? "+" : ""), pair_pnl);
      }

      // Row colors
      color clr_pair = C_TEXT;
      color clr_mode = C_SUB;
      color clr_dir  = (data.displayDir == "BUY" ? C_VALUE : (data.displayDir == "SELL" ? C_WARN : C_SUB));
      color clr_score = (data.displayScore >= 100.0 ? C_VALUE : (data.displayScore >= 70.0 ? C_LIMIT : C_SUB));
      color clr_state = (data.displayState == "READY" ? C_VALUE : (data.displayState == "BLOCKED" ? C_WARN : C_TEXT));
      color clr_next  = (data.displayNextGate == "ENTRY" ? C_VALUE : (data.displayState == "BLOCKED" ? C_WARN : C_SUB));
      color clr_chain = (pair_has_chain ? C_SECTION : C_SUB);
      color clr_pnl   = (pair_has_chain ? (pair_pnl >= 0 ? R_PROFIT : R_LOSS) : C_SUB);

      SetLabelText(INFO_PREFIX + "R"+r+"_Pair",  s_pair,  clr_pair);
      SetLabelText(INFO_PREFIX + "R"+r+"_Mode",  s_mode,  clr_mode);
      SetLabelText(INFO_PREFIX + "R"+r+"_Dir",   s_dir,   clr_dir);
      SetLabelText(INFO_PREFIX + "R"+r+"_Score", s_score, clr_score);
      SetLabelText(INFO_PREFIX + "R"+r+"_State", s_state, clr_state);
      SetLabelText(INFO_PREFIX + "R"+r+"_Next",  s_next,  clr_next);
      SetLabelText(INFO_PREFIX + "R"+r+"_Chain", s_chain, clr_chain);
      SetLabelText(INFO_PREFIX + "R"+r+"_Pnl",   s_pnl,   clr_pnl);

      // Candidate tracking for Section D (Entry Analysis)
      if(!pair_has_chain)
      {
         // Priority 1: Score >= 100
         if(data.displayScore >= 100.0 && (focus_pair < 0 || highest_score < 100.0))
         {
            focus_pair = i;
            highest_score = data.displayScore;
         }
         // Priority 2: Highest score > 0
         else if(highest_score < 100.0 && data.displayScore > highest_score && data.displayScore > 0.0)
         {
            focus_pair = i;
            highest_score = data.displayScore;
         }
         // Priority 3: Highest progress
         else if(highest_score <= 0.0 && data.progressCompleted > highest_progress && data.progressCompleted > 0)
         {
            focus_pair = i;
            highest_progress = data.progressCompleted;
         }
      }
   }

   SetLabelText(INFO_PREFIX + "Sys_Chain_Val", IntegerToString(total_active_chains), (total_active_chains > 0 ? C_VALUE : C_SUB));

   // 3. SECTION C — ACTIVE CHAIN PANEL
   if(total_active_chains == 0 || primary_active_pair < 0)
   {
      SetLabelText(INFO_PREFIX + "SecC_Title", "=== ACTIVE CHAIN ===", C_SECTION);
      SetLabelText(INFO_PREFIX + "Chain_L1", "No active chain", C_SUB);
      SetLabelText(INFO_PREFIX + "Chain_L2", " ", C_SUB);
      SetLabelText(INFO_PREFIX + "Chain_L3", " ", C_SUB);
   }
   else
   {
      int ac = primary_active_pair;
      string base = G_Pairs[ac].base_name;
      SetLabelText(INFO_PREFIX + "SecC_Title", StringFormat("=== ACTIVE CHAIN — %s ===", base), C_SECTION);

      string strat = G_Pairs[ac].active_chain_strategy;
      if(strat == "") strat = "CT";

      int dir_val = G_TradeProfile[ac].direction;
      if(dir_val == 0) dir_val = G_Pairs[ac].setup_direction;
      string dir_str = (dir_val == 1 ? "BUY" : (dir_val == -1 ? "SELL" : "--"));

      ulong cid = (G_Pairs[ac].active_chain_id > 0) ? G_Pairs[ac].active_chain_id : (EA_MAGIC_NUMBER * 1000 + ac);

      int orders = 0;
      for(int k = PositionsTotal() - 1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == G_Pairs[ac].symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == cid)
               orders++;
         }
      }

      int pos_count = G_Pairs[ac].chain_position_count;
      int dca_step  = G_Pairs[ac].chain_step_pips;
      if(dca_step <= 0) dca_step = InpDCA_MinStepPips;

      double debt = GetStrategyDebt(ac, strat);
      int rec_lvl = GetStrategyRecLvl(ac, strat);
      int dca_seq = GetStrategyDCASeq(ac, strat);

      bool is_runner = (InpEnableDynamicTP && G_TradeProfile[ac].runner_active);
      string exit_mode_str = is_runner ? "RUNNER" : "NORMAL";
      if(InpEnableDynamicTP && G_TradeProfile[ac].compression_active)
      {
         exit_mode_str += " (Compression ACTIVE)";
      }

      string l1 = StringFormat("Strategy : %-4s   | Direction : %-4s   | Chain ID : #%I64u", strat, dir_str, cid);
      string l2 = StringFormat("Orders   : %-2d     | Chain Pos : %d/%d (DCA %d) | Debt : $%.2f", orders, pos_count, InpMaxDCAPerChain, dca_seq, debt);
      string l3 = StringFormat("Exit Mode: %s      | Mode : %s", exit_mode_str, (debt > 0.001 ? "RECOVERY" : "NORMAL"));

      SetLabelText(INFO_PREFIX + "Chain_L1", l1, C_TEXT);
      SetLabelText(INFO_PREFIX + "Chain_L2", l2, (debt > 0.01 ? C_LIMIT : C_TEXT));
      SetLabelText(INFO_PREFIX + "Chain_L3", l3, (is_runner ? C_VALUE : C_TEXT));
   }

   // 4. SECTION D — ENTRY / DEBUG DETAIL
   if(focus_pair < 0)
   {
      for(int i = 0; i < TOTAL_PAIRS; i++)
      {
         if(StringFind(G_Pairs[i].symbol, _Symbol) >= 0 || StringFind(_Symbol, G_Pairs[i].base_name) >= 0)
         {
            focus_pair = i;
            break;
         }
      }
      if(focus_pair < 0) focus_pair = 0;
   }

   ReversalDisplayData fData;
   BuildReversalDisplayData(focus_pair, fData);

   string f_base = G_Pairs[focus_pair].base_name;
   SetLabelText(INFO_PREFIX + "SecD_Title", StringFormat("=== ENTRY ANALYSIS — %s ===", f_base), C_SECTION);

   string e1 = StringFormat("Strategy : %-4s   | Direction : %-4s   | Score : %-7s | Mode : %s",
                            fData.displayMode, fData.displayDir, fData.displayScoreStr, fData.entryMode);
   string e2 = StringFormat("State    : %-10s | Readiness : %-10s | Next Gate : %s",
                            fData.displayState, fData.displayReadinessStr, fData.displayNextGate);
   string e3 = StringFormat("Block Reason : %s", fData.displayBlockReason);
   string e4 = StringFormat("Score Breakdown: %s", (fData.displayBreakdown != "" ? fData.displayBreakdown : "N/A"));

   color clr_e1 = (fData.displayScore >= 100.0 ? C_VALUE : C_TEXT);
   color clr_e2 = (fData.displayState == "READY" ? C_VALUE : (fData.displayState == "BLOCKED" ? C_WARN : C_TEXT));
   color clr_e3 = (fData.displayBlockReason != "NONE" && fData.displayBlockReason != "ACTIVE CHAIN" ? C_WARN : C_VALUE);
   color clr_e4 = C_SUB;

   SetLabelText(INFO_PREFIX + "Entry_L1", e1, clr_e1);
   SetLabelText(INFO_PREFIX + "Entry_L2", e2, clr_e2);
   SetLabelText(INFO_PREFIX + "Entry_L3", e3, clr_e3);
   SetLabelText(INFO_PREFIX + "Entry_L4", e4, clr_e4);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| DELETE DASHBOARD DISPLAY                                         |
//+------------------------------------------------------------------+
void DeleteDisplay()
{
   ObjectsDeleteAll(0, INFO_PREFIX);
   ObjectsDeleteAll(0, BG_PREFIX);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| CREATE LABEL (TEXT) - ALWAYS ON TOP                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int corner, int font_size, color clr, bool bold = false)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, FONT_NAME);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
}

//+------------------------------------------------------------------+
//| CREATE BACKGROUND (PANEL) - ALWAYS ON TOP                        |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int w, int h, int corner, color bg_clr)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_SEP);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
}

//+------------------------------------------------------------------+
//| SET LABEL TEXT AND COLOR (UPDATE WITHOUT RECREATING)             |
//+------------------------------------------------------------------+
void SetLabelText(string name, string text, color clr)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
