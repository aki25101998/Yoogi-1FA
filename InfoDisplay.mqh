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
const int    DASH_Y          = 250;  // Y Base Offset (Top anchor in LEFT_LOWER)
const int    DASH_LINE_H     = 16;   // Standard Line Height
const int    TABLE_ROW_H     = 16;   // Table Row Height
const int    FONT_SIZE       = 10;   // Data Font Size
const int    FONT_TITLE_SIZE = 12;   // Main Title Font Size
const int    FONT_SEC_SIZE   = 10;   // Section Title Font Size
const string FONT_NAME       = "Consolas";

// --- BACKGROUND PANEL ---
const bool   USE_BACK        = true;
const color  C_BACK          = C'15,22,28';  // Deep Slate Charcoal
const int    BACK_W          = 410;
const int    BACK_H          = 260;
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

// --- TEXT LABELS ---
const string TXT_HEADER      = "=== YOOGI ONE FOR ALL ===";
const string TXT_FOOTER      = "YOOGI 1FA — TRADE FOR LIVING";

// Table Columns X Offsets (Relative to DASH_X)
const int P_PAIR = 0;
const int P_TYPE = 65;
const int P_SCOR = 145;
const int P_STAT = 220;
const int P_DEBT = 315;

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
   CreateLabel(INFO_PREFIX + "Header", TXT_HEADER, x + 95, y, DASH_CORNER, FONT_TITLE_SIZE, C_HEADER, true);
   y -= 22;

   // ===============================================================
   // SECTION A — SYSTEM SUMMARY
   // ===============================================================
   CreateLabel(INFO_PREFIX + "SecA_Title", "=== SYSTEM SUMMARY ===", x, y, DASH_CORNER, FONT_SEC_SIZE, C_SECTION, true);
   y -= 17;

   int col_lbl = x;
   int col_val = x + 135;

   // Row A1: Balance
   CreateLabel(INFO_PREFIX + "Sys_Bal_Lbl",  "Balance       :", col_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_Bal_Val",  "$0.00",          col_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // Row A2: Virtual Balance
   CreateLabel(INFO_PREFIX + "Sys_VBal_Lbl", "Virtual Bal   :", col_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_VBal_Val", "$0.00",          col_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // Row A3: Total Debt
   CreateLabel(INFO_PREFIX + "Sys_Debt_Lbl", "Total Debt    :", col_lbl, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Sys_Debt_Val", "$0.00",          col_val, y, DASH_CORNER, FONT_SIZE, C_LIMIT);
   y -= (DASH_LINE_H + 6);

   // ===============================================================
   // SECTION B — PAIR MONITOR
   // ===============================================================
   CreateLabel(INFO_PREFIX + "SecB_Title", "=== PAIR MONITOR ===", x, y, DASH_CORNER, FONT_SEC_SIZE, C_SECTION, true);
   y -= 17;

   // Table Column Headers
   CreateLabel(INFO_PREFIX + "H_Pair",  "PAIR",   x + P_PAIR, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Type",  "TYPE",   x + P_TYPE, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Score", "SCORE",  x + P_SCOR, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Stat",  "STATUS", x + P_STAT, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Debt",  "DEBT",   x + P_DEBT, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= TABLE_ROW_H;

   // Table Data Rows
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string r = IntegerToString(i);
      CreateLabel(INFO_PREFIX + "R"+r+"_Pair",  "-", x + P_PAIR, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Type",  "-", x + P_TYPE, y, DASH_CORNER, FONT_SIZE, C_SUB);
      CreateLabel(INFO_PREFIX + "R"+r+"_Score", "-", x + P_SCOR, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Stat",  "-", x + P_STAT, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Debt",  "-", x + P_DEBT, y, DASH_CORNER, FONT_SIZE, C_SUB);
      y -= TABLE_ROW_H;
   }
   y -= 6;

   // ===============================================================
   // FOOTER
   // ===============================================================
   CreateLabel(INFO_PREFIX + "Sep_Foot", "--------------------------------------------------", x, y, DASH_CORNER, FONT_SIZE, C_SEP);
   y -= 15;
   CreateLabel(INFO_PREFIX + "Footer", TXT_FOOTER, x + 95, y, DASH_CORNER, FONT_SIZE, C_HEADER, true);

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
   SetLabelText(INFO_PREFIX + "Sys_Debt_Val", StringFormat("$%.2f", total_debt), (total_debt > 0.001 ? C_LIMIT : C_VALUE));

   // 2. SCAN CHAINS & UPDATE PAIR MONITOR ROWS
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string sym = G_Pairs[i].symbol;

      // Scan open positions for this pair
      int pair_orders = 0;
      for(int k = PositionsTotal() - 1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym)
            {
               ulong pos_magic = (ulong)PositionGetInteger(POSITION_MAGIC);
               if(IsPairChainMagic(i, pos_magic) || (pos_magic == 0 && G_Pairs[i].active_chain_id != 0))
               {
                  pair_orders++;
               }
            }
         }
      }

      // Build data presentation from existing engine (pure read-only)
      ReversalDisplayData data;
      BuildReversalDisplayData(i, data);

      string r = IntegerToString(i);
      string sym_short = G_Pairs[i].base_name;
      double pair_debt = GetSystemDebt(i);
      bool is_recovery = (pair_debt > 0.001 || G_Pairs[i].system_recovery_active);

      // COLUMN 1: PAIR
      string s_pair = StringFormat("%-6s", sym_short);

      // COLUMN 2: TYPE (Merge displayMode + displayDir)
      string s_type = "--";
      if(data.displayMode != "--" && data.displayDir != "--")
         s_type = data.displayMode + " " + data.displayDir;
      else if(data.displayMode != "--")
         s_type = data.displayMode;
      else if(data.displayDir != "--")
         s_type = data.displayDir;

      // COLUMN 3: SCORE
      string s_score = StringFormat("%7s", data.displayScoreStr);

      // COLUMN 4: STATUS (Authoritative mapping based on required priority)
      string s_status = "WAIT";
      color clr_status = C_SUB;

      // Priority A: Recovery
      if(is_recovery)
      {
         s_status = "RECOVERY";
         clr_status = C_LIMIT; // clrOrange
      }
      // Priority B: DCA (more than 1 position)
      else if(pair_orders > 1 || G_Pairs[i].chain_position_count > 1)
      {
         s_status = "DCA";
         clr_status = clrGold;
      }
      // Priority C: Normal Trading (1 open position)
      else if(pair_orders == 1)
      {
         s_status = "TRADING";
         clr_status = clrDeepSkyBlue;
      }
      // Priority D: No orders
      else
      {
         if(data.displayState == "READY" || data.displayNextGate == "ENTRY")
         {
            s_status = "READY";
            clr_status = C_VALUE; // clrLime
         }
         else if(data.displayState == "BLOCKED")
         {
            s_status = "LOCKED";
            clr_status = C_WARN; // clrIndianRed
         }
         else if(data.displayState == "NO SETUP")
         {
            s_status = "NO SETUP";
            clr_status = C_SUB; // clrLightGray
         }
         else
         {
            s_status = "WAIT";
            clr_status = C_SUB; // clrLightGray
         }
      }

      // COLUMN 5: DEBT
      string s_debt = StringFormat("$%.2f", pair_debt);
      color clr_debt = (pair_debt > 0.001 ? C_LIMIT : C_SUB);

      // Colors for Type and Score
      color clr_type = C_TEXT;
      if(data.displayDir == "BUY") clr_type = C_VALUE;
      else if(data.displayDir == "SELL") clr_type = C_WARN;

      color clr_score = (data.displayScore >= 100.0 ? C_VALUE : (data.displayScore >= 70.0 ? C_LIMIT : C_SUB));

      // Update row labels
      SetLabelText(INFO_PREFIX + "R"+r+"_Pair",  s_pair,   C_TEXT);
      SetLabelText(INFO_PREFIX + "R"+r+"_Type",  s_type,   clr_type);
      SetLabelText(INFO_PREFIX + "R"+r+"_Score", s_score,  clr_score);
      SetLabelText(INFO_PREFIX + "R"+r+"_Stat",  s_status, clr_status);
      SetLabelText(INFO_PREFIX + "R"+r+"_Debt",  s_debt,   clr_debt);
   }

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
