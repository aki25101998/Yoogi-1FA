//+------------------------------------------------------------------+
//|                                              InfoDisplay.mqh     |
//|                                                  Yoogi Trading   |
//|      (Final Version: Hardcoded Settings - "Yoogi One For All")   |
//+------------------------------------------------------------------+
#property strict

//--- Prefix tên đối tượng
#define INFO_PREFIX "YDG_Mother_"
#define BG_PREFIX   "YDG_BG_"

// ==================================================================
// 1. CẤU HÌNH CỐ ĐỊNH (HARDCODED SETTINGS)
// ==================================================================

// --- LAYOUT & POSITIONS ---
const ENUM_BASE_CORNER DASH_CORNER = CORNER_LEFT_LOWER;
const int    DASH_X          = 40;   // Tọa độ X Gốc
const int    DASH_Y          = 310;  // Tọa độ Y Gốc
const int    DASH_LINE_H     = 20;   // Dòng thông tin chung
const int    TABLE_ROW_H     = 18;   // Dòng bảng
const int    FONT_SIZE       = 11;
const string FONT_NAME       = "Consolas";
const int    VAL_OFFSET      = 100;  // Khoảng cách số liệu

// --- HEADER & FOOTER OFFSETS ---
const int    HEAD_OFF_X      = 42;
const int    FOOT_OFF_X      = 30;

#include "ReversalDisplayData.mqh"

// --- HEADER POSITIONS (X) ---
const int    H_PAIR_X        = 0;
const int    H_TREND_X       = 60;
const int    H_BIAS_X        = 140;
const int    H_SCORE_X       = 200;
const int    H_PROG_X        = 250;
const int    H_STAT_X        = 300;
const int    H_WAIT_X        = 420;
const int    H_ENTRY_X       = 560;

// --- SEPARATOR POSITIONS (X) ---
const int    SEP_TREND_X     = 50;
const int    SEP_BIAS_X      = 130;
const int    SEP_SCORE_X     = 190;
const int    SEP_PROG_X      = 240;
const int    SEP_STAT_X      = 290;
const int    SEP_WAIT_X      = 410;
const int    SEP_ENTRY_X     = 550;

// --- DATA POSITIONS (X) ---
const int    D_PAIR_X        = 0;
const int    D_TREND_X       = 60;
const int    D_BIAS_X        = 140;
const int    D_SCORE_X       = 200;
const int    D_PROG_X        = 250;
const int    D_STAT_X        = 300;
const int    D_WAIT_X        = 420;
const int    D_ENTRY_X       = 560;

// --- BACKGROUND ---
const bool   USE_BACK        = true;
const color  C_BACK          = clrDarkSlateGray;
const int    BACK_W          = 650;
const int    BACK_H          = 340;
const int    BACK_OFF_X      = -20;
const int    BACK_OFF_Y      = 40;

// --- FOOTER ---
const int    FOOT_SIZE       = 12;
const int    FOOT_GAP        = 28;
const color  C_FOOTER        = clrGold;

// --- COLORS ---
const color  C_HEADER        = clrGold;
const color  C_TEXT          = clrWhite;
const color  C_VALUE         = clrLime;
const color  C_WARN          = clrRed;
const color  C_LIMIT         = clrOrange;
const color  C_SUB           = clrWhite;
const color  C_SEP           = clrWhite;

// --- TABLE ROW COLORS ---
const color  R_PROFIT        = clrLime;
const color  R_LOSS          = clrIndianRed;
const color  R_DEBT          = clrOrange;
const color  R_OFF           = clrWhite;
const color  R_SLEEP         = clrWhite;

// --- TEXT CONTENTS ---
const string TXT_HEADER      = "=== YOOGI ONE FOR ALL ===";
const string TXT_STAT_LBL    = "Status :";
const string TXT_REAL_BAL    = "Balance :";
const string TXT_VIRT_BAL    = "Balance ảo :";
const string TXT_DEBT_PRE    = "( Nợ :";
const string TXT_SEP_LINE    = "------------------------------------";
const string TXT_SEP_SYM     = "|";
const string TXT_FOOTER      = "YOOGI 1FA - TRADE FOR LIVING";

const string TXT_H_PAIR      = "PAIR";
const string TXT_H_TREND     = "TREND";
const string TXT_H_BIAS      = "BIAS";
const string TXT_H_SCORE     = "SCORE";
const string TXT_H_PROG      = "PROG";
const string TXT_H_STAT      = "STATE";
const string TXT_H_WAIT      = "WAITING FOR";
const string TXT_H_ENTRY     = "ENTRY";

const string TXT_STAT_RUN    = "Running";
const string TXT_STAT_LOW    = "Balance cần > 10k";
const string TXT_STAT_LIMIT  = "Balance cần < 500k";
const string TXT_WAIT        = "Waiting...";
const string TXT_OFF         = "OFF";


// ==================================================================
// 2. LOGIC XỬ LÝ GIAO DIỆN
// ==================================================================

//--- Khai báo hàm
void CreateDisplay();
void UpdateDisplay();
void DeleteDisplay();
//--- Hàm nội bộ
void CreateLabel(string name, string text, int x, int y, int corner, int font_size, color clr);
void CreatePanel(string name, int x, int y, int w, int h, int corner, color bg_clr);

//+------------------------------------------------------------------+
//| TẠO GIAO DIỆN BẢNG THÔNG TIN                                     |
//+------------------------------------------------------------------+
void CreateDisplay()
{
   DeleteDisplay(); 

   // 0. VẼ BACKGROUND
   if(USE_BACK)
   {
      int bg_x = DASH_X + BACK_OFF_X;
      int bg_y = DASH_Y + BACK_OFF_Y; 
      CreatePanel(BG_PREFIX + "Main", bg_x, bg_y, BACK_W, BACK_H, DASH_CORNER, C_BACK);
   }

   // --- BẮT ĐẦU VẼ CÁC THÀNH PHẦN ---
   int y      = DASH_Y;
   int x_base = DASH_X; 
   int x_val  = DASH_X + VAL_OFFSET; 

   // 1. HEADER CHÍNH
   CreateLabel(INFO_PREFIX + "Header", TXT_HEADER, x_base + HEAD_OFF_X, y, DASH_CORNER, FONT_SIZE + 2, C_HEADER);
   y -= (DASH_LINE_H + 5);

   // 2. SYSTEM STATUS
   CreateLabel(INFO_PREFIX + "Status_Lbl", TXT_STAT_LBL, x_base, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   CreateLabel(INFO_PREFIX + "Status_Val", TXT_WAIT, x_val, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   // 2b. DXY STATUS
   CreateLabel(INFO_PREFIX + "DXY_Lbl", "DXY :", x_base, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   CreateLabel(INFO_PREFIX + "DXY_Val", "Detecting...", x_val, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= DASH_LINE_H;

   // 2c. REVERSAL ENGINE
   CreateLabel(INFO_PREFIX + "Rev_Lbl", "Reversal :", x_base, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   CreateLabel(INFO_PREFIX + "Rev_Val", "Init...", x_val, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= DASH_LINE_H;


   // 3. ACCOUNT INFO
   CreateLabel(INFO_PREFIX + "Acc_Bal", TXT_REAL_BAL, x_base, y, DASH_CORNER, FONT_SIZE, C_TEXT);
   CreateLabel(INFO_PREFIX + "Acc_Bal_Val", "0.00", x_val + 20, y, DASH_CORNER, FONT_SIZE, C_VALUE);
   y -= DASH_LINE_H;

   CreateLabel(INFO_PREFIX + "Virt_Bal", TXT_VIRT_BAL, x_base, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "Virt_Bal_Val", "0.00", x_val + 20, y, DASH_CORNER, FONT_SIZE, C_SUB);
   y -= (DASH_LINE_H + 5);

   CreateLabel(INFO_PREFIX + "Sep1", TXT_SEP_LINE, x_base, y, DASH_CORNER, FONT_SIZE, C_SEP);
   y -= DASH_LINE_H;

   // 4. TABLE HEADER (TIÊU ĐỀ BẢNG)
   CreateLabel(INFO_PREFIX + "H_Pair", TXT_H_PAIR, x_base + H_PAIR_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Trend", TXT_H_TREND, x_base + H_TREND_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Bias",  TXT_H_BIAS,  x_base + H_BIAS_X,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Score", TXT_H_SCORE, x_base + H_SCORE_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Prog",  TXT_H_PROG,  x_base + H_PROG_X,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Stat",  TXT_H_STAT,  x_base + H_STAT_X,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Wait",  TXT_H_WAIT,  x_base + H_WAIT_X,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Entry", TXT_H_ENTRY, x_base + H_ENTRY_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   
   // Dấu phân cách Header
   CreateLabel(INFO_PREFIX + "H_Sep1", TXT_SEP_SYM, x_base + SEP_TREND_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep2", TXT_SEP_SYM, x_base + SEP_BIAS_X,  y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep3", TXT_SEP_SYM, x_base + SEP_SCORE_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep4", TXT_SEP_SYM, x_base + SEP_PROG_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep5", TXT_SEP_SYM, x_base + SEP_STAT_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep6", TXT_SEP_SYM, x_base + SEP_WAIT_X, y, DASH_CORNER, FONT_SIZE, C_SUB);
   CreateLabel(INFO_PREFIX + "H_Sep7", TXT_SEP_SYM, x_base + SEP_ENTRY_X, y, DASH_CORNER, FONT_SIZE, C_SUB);

   y -= (DASH_LINE_H + 2);

   // 5. ROWS (DỮ LIỆU BẢNG)
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string r = IntegerToString(i);
      
      // -- DATA COLUMNS --
      CreateLabel(INFO_PREFIX + "R"+r+"_Pair", TXT_WAIT, x_base + D_PAIR_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Trend", "-",     x_base + D_TREND_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Bias",  "-",     x_base + D_BIAS_X,  y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Score", "-",     x_base + D_SCORE_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Prog",  "-",     x_base + D_PROG_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Stat",  "-",     x_base + D_STAT_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Wait",  "-",     x_base + D_WAIT_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      CreateLabel(INFO_PREFIX + "R"+r+"_Entry", "-",     x_base + D_ENTRY_X, y, DASH_CORNER, FONT_SIZE, C_TEXT);
      
      // -- SEPARATORS --
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep1", TXT_SEP_SYM, x_base + SEP_TREND_X, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep2", TXT_SEP_SYM, x_base + SEP_BIAS_X,  y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep3", TXT_SEP_SYM, x_base + SEP_SCORE_X, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep4", TXT_SEP_SYM, x_base + SEP_PROG_X, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep5", TXT_SEP_SYM, x_base + SEP_STAT_X, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep6", TXT_SEP_SYM, x_base + SEP_WAIT_X, y, DASH_CORNER, FONT_SIZE, C_SEP);
      CreateLabel(INFO_PREFIX + "R"+r+"_Sep7", TXT_SEP_SYM, x_base + SEP_ENTRY_X, y, DASH_CORNER, FONT_SIZE, C_SEP);

      y -= TABLE_ROW_H;
   }

   // 6. FOOTER
   y = y + TABLE_ROW_H - FOOT_GAP; 
   CreateLabel(INFO_PREFIX + "Footer", TXT_FOOTER, x_base + FOOT_OFF_X, y, DASH_CORNER, FOOT_SIZE, C_FOOTER);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| CẬP NHẬT DỮ LIỆU ĐỘNG                                            |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   if(ObjectFind(0, INFO_PREFIX + "Header") < 0)
   {
      CreateDisplay();
      return;
   }

   // --- TÍNH TOÁN ---
   double real_bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double total_debt = 0.0;
   for(int i=0; i<TOTAL_PAIRS; i++) total_debt += G_Pairs[i].realized_bleed_loss;
   double virt_bal = real_bal + total_debt;

   // --- STATUS ---
   string status_msg = TXT_STAT_RUN;
   color  status_clr = C_VALUE; 
   if(InpEnableBalanceLimit)
   {
      if(virt_bal < LIMIT_MIN_VIRTUAL) { status_msg = TXT_STAT_LOW; status_clr = C_WARN; }
      else if(virt_bal > LIMIT_MAX_VIRTUAL) { status_msg = TXT_STAT_LIMIT; status_clr = C_LIMIT; }
   }

   ObjectSetString(0, INFO_PREFIX + "Status_Val", OBJPROP_TEXT, status_msg);
   ObjectSetInteger(0, INFO_PREFIX + "Status_Val", OBJPROP_COLOR, status_clr);

   // --- DXY STATUS ---
   if(!InpUseDXYReference)
   {
      ObjectSetString(0, INFO_PREFIX + "DXY_Val", OBJPROP_TEXT, "Disabled by User");
      ObjectSetInteger(0, INFO_PREFIX + "DXY_Val", OBJPROP_COLOR, C_WARN);
   }
   else if(g_dxy_available)
   {
      ObjectSetString(0, INFO_PREFIX + "DXY_Val", OBJPROP_TEXT, StringFormat("Connected (%s)", DXY_SYMBOL));
      ObjectSetInteger(0, INFO_PREFIX + "DXY_Val", OBJPROP_COLOR, C_VALUE);
   }
   else
   {
      ObjectSetString(0, INFO_PREFIX + "DXY_Val", OBJPROP_TEXT, "Not Available");
      ObjectSetInteger(0, INFO_PREFIX + "DXY_Val", OBJPROP_COLOR, C_WARN);
   }

   // --- REVERSAL ENGINE STATUS ---
   if(!InpUseReversalEngine)
   {
      ObjectSetString(0, INFO_PREFIX + "Rev_Val", OBJPROP_TEXT, "Disabled");
      ObjectSetInteger(0, INFO_PREFIX + "Rev_Val", OBJPROP_COLOR, C_WARN);
   }
   else
   {
      // Display the Reversal Score of the EURUSD pair as representative, or an aggregate status.
      // Since it's a global label, we'll show "Active" and we can add score to the individual pair rows later if needed.
      ObjectSetString(0, INFO_PREFIX + "Rev_Val", OBJPROP_TEXT, "Active (MTF+Scoring)");
      ObjectSetInteger(0, INFO_PREFIX + "Rev_Val", OBJPROP_COLOR, C_VALUE);
   }


   // --- BAL ---
   ObjectSetString(0, INFO_PREFIX + "Acc_Bal_Val", OBJPROP_TEXT, StringFormat("$%.2f", real_bal));
   
   // [CHỈNH SỬA TẠI ĐÂY] Thêm khoảng trắng để tạo định dạng: ( Nợ : $0 )
   string debt_str = StringFormat("$%.0f %s $%.0f )", virt_bal, TXT_DEBT_PRE, total_debt);
   ObjectSetString(0, INFO_PREFIX + "Virt_Bal_Val", OBJPROP_TEXT, debt_str);

   // --- CẬP NHẬT TỪNG MẢNH GHÉP CỦA BẢNG ---
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string sym = G_Pairs[i].symbol;
      string short_name = StringSubstr(sym, 0, 6);
      if(short_name == "") short_name = "ERROR";

      int    count = 0;
      double pnl   = 0.0;

      for(int k = PositionsTotal()-1; k >= 0; --k)
      {
         ulong t = PositionGetTicket(k);
         if(t > 0 && PositionSelectByTicket(t))
         {
            if(PositionGetString(POSITION_SYMBOL) == sym && (ulong)PositionGetInteger(POSITION_MAGIC) != 0)
            {
               count++;
               pnl += ProfitOf(t);
            }
         }
      }

      double debt = G_Pairs[i].realized_bleed_loss;
      double risk = G_Pairs[i].risk_percent;

      // Color Logic
      color row_color = C_TEXT; 
      if(risk <= 0.001)                     row_color = R_OFF;
      else if(count > 0 && pnl >= 0)        row_color = R_PROFIT;
      else if(count > 0 && pnl < 0)         row_color = R_LOSS;
      else if(count == 0 && debt > 0)       row_color = R_DEBT;
      else if(count == 0 && debt == 0)      row_color = R_SLEEP;

      // Chuẩn bị Text
      string s_pair = StringFormat("%-6s", short_name);
      string s_trend = "-", s_bias = "-", s_score = "-", s_prog = "-", s_stat = "-", s_wait = "-", s_entry = "-";

      if(InpUseReversalEngine)
      {
         ReversalDisplayData data;
         if(BuildReversalDisplayData(i, data))
         {
            s_trend = data.htfTrend;
            s_bias  = data.reversalBias;
            s_score = StringFormat("%.0f%%", data.reversalScore);
            s_prog  = StringFormat("%d/%d", data.progressCompleted, data.progressTotal);
            s_stat  = data.state;
            
            // Block reason overrides wait state if blocked
            if(data.blockReason != "NONE") s_wait = "BLK: " + data.blockReason;
            else s_wait = data.waitingFor;
            
            s_entry = data.masterEntry;
         }
      }

      string r = IntegerToString(i);

      // Cập nhật từng ô dữ liệu
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Pair", OBJPROP_TEXT, s_pair);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Pair", OBJPROP_COLOR, row_color);
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Trend", OBJPROP_TEXT, s_trend);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Trend", OBJPROP_COLOR, row_color);
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Bias",  OBJPROP_TEXT, s_bias);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Bias",  OBJPROP_COLOR, (s_bias == "CONFLICT") ? C_WARN : row_color);
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Score", OBJPROP_TEXT, s_score);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Score", OBJPROP_COLOR, row_color);
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Prog", OBJPROP_TEXT, s_prog);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Prog", OBJPROP_COLOR, row_color);
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Stat",  OBJPROP_TEXT, s_stat);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Stat",  OBJPROP_COLOR, row_color);
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Wait",   OBJPROP_TEXT, s_wait);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Wait",   OBJPROP_COLOR, (s_wait == "NONE") ? C_VALUE : (StringFind(s_wait, "BLK:") >= 0 ? C_WARN : row_color));
      
      ObjectSetString(0, INFO_PREFIX + "R"+r+"_Entry",   OBJPROP_TEXT, s_entry);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Entry",   OBJPROP_COLOR, (s_entry == "BUY READY" || s_entry == "SELL READY") ? C_VALUE : (s_entry == "BLOCKED" ? C_WARN : row_color));

      // Cập nhật màu dấu phân cách
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep1", OBJPROP_COLOR, row_color); 
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep2", OBJPROP_COLOR, row_color);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep3", OBJPROP_COLOR, row_color);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep4", OBJPROP_COLOR, row_color);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep5", OBJPROP_COLOR, row_color);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep6", OBJPROP_COLOR, row_color);
      ObjectSetInteger(0, INFO_PREFIX + "R"+r+"_Sep7", OBJPROP_COLOR, row_color);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| XÓA GIAO DIỆN                                                    |
//+------------------------------------------------------------------+
void DeleteDisplay()
{
   ObjectsDeleteAll(0, INFO_PREFIX);
   ObjectsDeleteAll(0, BG_PREFIX);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| VẼ LABEL (TEXT) - ALWAYS ON TOP                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int corner, int font_size, color clr)
{
   if(ObjectFind(0, name) != 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, FONT_NAME);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false); // Nằm trên nến và nền
}

//+------------------------------------------------------------------+
//| VẼ BACKGROUND (PANEL) - ALWAYS ON TOP                            |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int w, int h, int corner, color bg_clr)
{
   if(ObjectFind(0, name) != 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER); 
   ObjectSetInteger(0, name, OBJPROP_BACK, false); // Đè lên nến
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
}
//+------------------------------------------------------------------+
