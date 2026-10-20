//+------------------------------------------------------------------+
//|                                       ReversalDiagnostics.mqh    |
//|                                                Yoogi Trading     |
//|       Counter-Trend Rejection Funnel & Candidate Statistics      |
//|       PURE OBSERVABILITY / DIAGNOSTICS MODULE (NO LOGIC CHANGE)  |
//+------------------------------------------------------------------+
#property strict

#ifndef __REVERSAL_DIAGNOSTICS_MQH__
#define __REVERSAL_DIAGNOSTICS_MQH__

// Funnel Step Enums for Counter-Trend
enum ENUM_CT_FUNNEL_STEP
{
   CT_FUNNEL_HTF_EVAL = 0,
   CT_FUNNEL_HTF_VALID,
   CT_FUNNEL_EXHAUSTION_FOUND,
   CT_FUNNEL_SWEEP_FOUND,
   CT_FUNNEL_DISPLACEMENT_FOUND,
   CT_FUNNEL_MSS_FOUND,
   CT_FUNNEL_SCORE_PASS,
   CT_FUNNEL_COHERENCE_PASS,
   CT_FUNNEL_DISTANCE_PASS,
   CT_FUNNEL_DXY_PASS,
   CT_FUNNEL_FINAL_ENTRY,
   CT_FUNNEL_STEPS_TOTAL
};

// Funnel and rejection counters struct
struct CTFunnelCounters
{
   int htf_evaluated;
   int htf_zone_valid;
   int htf_zone_reject;
   
   int exhaustion_found;
   int exh_div_count;
   int exh_rej_count;
   int exh_fail_cont_count;
   
   int sweep_found;
   int sweep_reject;
   
   int displacement_found;
   int displacement_reject;
   
   int mss_found;
   int mss_reject;
   
   int score_evaluated;
   int score_pass;
   int score_reject;
   
   int coherence_pass;
   int coherence_reject;
   
   int entry_dist_pass;
   int entry_dist_reject;
   
   int dxy_pass;
   int dxy_conflict;
   int dxy_waiting;
   
   int final_entry;
   
   int setups_started;
   int setups_invalidated;
   int setups_timeout;
   
   void Init()
   {
      htf_evaluated = 0;
      htf_zone_valid = 0;
      htf_zone_reject = 0;
      exhaustion_found = 0;
      exh_div_count = 0;
      exh_rej_count = 0;
      exh_fail_cont_count = 0;
      sweep_found = 0;
      sweep_reject = 0;
      displacement_found = 0;
      displacement_reject = 0;
      mss_found = 0;
      mss_reject = 0;
      score_evaluated = 0;
      score_pass = 0;
      score_reject = 0;
      coherence_pass = 0;
      coherence_reject = 0;
      entry_dist_pass = 0;
      entry_dist_reject = 0;
      dxy_pass = 0;
      dxy_conflict = 0;
      dxy_waiting = 0;
      final_entry = 0;
      setups_started = 0;
      setups_invalidated = 0;
      setups_timeout = 0;
   }
};

CTFunnelCounters G_CT_Counters[TOTAL_PAIRS];

// ------------------------------------------------------------------
// Initialization
// ------------------------------------------------------------------
void CTDiag_Init()
{
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      G_CT_Counters[i].Init();
   }
}

// ------------------------------------------------------------------
// Structured Funnel Log Output
// ------------------------------------------------------------------
void CTDiag_LogFunnel(int idx, int dir, string stage, string status, string details = "")
{
   if(!InpReversalDebug) return;
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   
   string sym = G_Pairs[idx].symbol;
   string dir_str = (dir == 1) ? "BUY" : (dir == -1 ? "SELL" : "NONE");
   if(details != "")
      PrintFormat("[CT_FUNNEL][%s][%s][%s] STATUS=%s | %s", sym, dir_str, stage, status, details);
   else
      PrintFormat("[CT_FUNNEL][%s][%s][%s] STATUS=%s", sym, dir_str, stage, status);
}

// ------------------------------------------------------------------
// Recording Functions
// ------------------------------------------------------------------
void CTDiag_RecordHTFEval(int idx, bool valid)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   G_CT_Counters[idx].htf_evaluated++;
   if(valid)
   {
      G_CT_Counters[idx].htf_zone_valid++;
      G_CT_Counters[idx].setups_started++;
   }
   else
   {
      G_CT_Counters[idx].htf_zone_reject++;
   }
}

void CTDiag_RecordExhaustion(int idx, bool div, bool rej, bool fail_cont)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(div || rej || fail_cont) G_CT_Counters[idx].exhaustion_found++;
   if(div) G_CT_Counters[idx].exh_div_count++;
   if(rej) G_CT_Counters[idx].exh_rej_count++;
   if(fail_cont) G_CT_Counters[idx].exh_fail_cont_count++;
}

void CTDiag_RecordSweep(int idx, bool pass)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(pass) G_CT_Counters[idx].sweep_found++;
   else G_CT_Counters[idx].sweep_reject++;
}

void CTDiag_RecordDisplacement(int idx, bool pass)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(pass) G_CT_Counters[idx].displacement_found++;
   else G_CT_Counters[idx].displacement_reject++;
}

void CTDiag_RecordMSS(int idx, bool pass)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(pass) G_CT_Counters[idx].mss_found++;
   else G_CT_Counters[idx].mss_reject++;
}

void CTDiag_RecordScore(int idx, double score, double req_score)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   G_CT_Counters[idx].score_evaluated++;
   if(score >= req_score) G_CT_Counters[idx].score_pass++;
   else G_CT_Counters[idx].score_reject++;
}

void CTDiag_RecordCoherence(int idx, bool pass)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(pass) G_CT_Counters[idx].coherence_pass++;
   else G_CT_Counters[idx].coherence_reject++;
}

void CTDiag_RecordEntryDistance(int idx, bool pass)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(pass) G_CT_Counters[idx].entry_dist_pass++;
   else G_CT_Counters[idx].entry_dist_reject++;
}

void CTDiag_RecordDXY(int idx, int status)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(status == 1) G_CT_Counters[idx].dxy_pass++;
   else if(status == -1) G_CT_Counters[idx].dxy_conflict++;
   else G_CT_Counters[idx].dxy_waiting++;
}

void CTDiag_RecordFinalEntry(int idx, int dir)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   G_CT_Counters[idx].final_entry++;
}

void CTDiag_RecordReset(int idx, string reason)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(reason == "SETUP_TIMEOUT" || reason == "RETEST_TIMEOUT")
      G_CT_Counters[idx].setups_timeout++;
   else if(reason == "SETUP_INVALIDATED")
      G_CT_Counters[idx].setups_invalidated++;
}

// ------------------------------------------------------------------
// Summary Report
// ------------------------------------------------------------------
void PrintCTFunnelBlock(string title, const CTFunnelCounters &c)
{
   PrintFormat("%s:", title);
   PrintFormat("HTF Zone evaluated : %d", c.htf_evaluated);
   PrintFormat("HTF Zone valid     : %d", c.htf_zone_valid);
   PrintFormat("Exhaustion found   : %d (Div=%d, Rej=%d, FailCont=%d)", c.exhaustion_found, c.exh_div_count, c.exh_rej_count, c.exh_fail_cont_count);
   PrintFormat("Sweep found        : %d", c.sweep_found);
   PrintFormat("Displacement found : %d", c.displacement_found);
   PrintFormat("MSS confirmed      : %d", c.mss_found);
   PrintFormat("%-19s: %d", "Score Pass (Pair Targets)", c.score_pass);
   PrintFormat("Coherence pass     : %d", c.coherence_pass);
   PrintFormat("Distance pass      : %d", c.entry_dist_pass);
   PrintFormat("DXY pass           : %d (Conflict=%d, Waiting=%d)", c.dxy_pass, c.dxy_conflict, c.dxy_waiting);
   PrintFormat("FINAL ENTRY        : %d", c.final_entry);
   Print("");
   Print("REJECTIONS / RESETS:");
   PrintFormat("HTF Zone Reject    : %d", c.htf_zone_reject);
   PrintFormat("Score Reject       : %d", c.score_reject);
   PrintFormat("Coherence Reject   : %d", c.coherence_reject);
   PrintFormat("Distance Reject    : %d", c.entry_dist_reject);
   PrintFormat("Setups Invalidated : %d", c.setups_invalidated);
   PrintFormat("Setups Timeout     : %d", c.setups_timeout);
}

void CTDiag_PrintFunnelSummary()
{
   Print("\n==================================================");
   Print("       COUNTER-TREND REJECTION FUNNEL REPORT      ");
   Print("==================================================");

   CTFunnelCounters total;
   total.Init();

   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      total.htf_evaluated        += G_CT_Counters[i].htf_evaluated;
      total.htf_zone_valid       += G_CT_Counters[i].htf_zone_valid;
      total.htf_zone_reject      += G_CT_Counters[i].htf_zone_reject;
      total.exhaustion_found     += G_CT_Counters[i].exhaustion_found;
      total.exh_div_count        += G_CT_Counters[i].exh_div_count;
      total.exh_rej_count        += G_CT_Counters[i].exh_rej_count;
      total.exh_fail_cont_count  += G_CT_Counters[i].exh_fail_cont_count;
      total.sweep_found          += G_CT_Counters[i].sweep_found;
      total.sweep_reject         += G_CT_Counters[i].sweep_reject;
      total.displacement_found   += G_CT_Counters[i].displacement_found;
      total.displacement_reject  += G_CT_Counters[i].displacement_reject;
      total.mss_found            += G_CT_Counters[i].mss_found;
      total.mss_reject           += G_CT_Counters[i].mss_reject;
      total.score_evaluated      += G_CT_Counters[i].score_evaluated;
      total.score_pass           += G_CT_Counters[i].score_pass;
      total.score_reject         += G_CT_Counters[i].score_reject;
      total.coherence_pass       += G_CT_Counters[i].coherence_pass;
      total.coherence_reject     += G_CT_Counters[i].coherence_reject;
      total.entry_dist_pass      += G_CT_Counters[i].entry_dist_pass;
      total.entry_dist_reject    += G_CT_Counters[i].entry_dist_reject;
      total.dxy_pass             += G_CT_Counters[i].dxy_pass;
      total.dxy_conflict         += G_CT_Counters[i].dxy_conflict;
      total.dxy_waiting          += G_CT_Counters[i].dxy_waiting;
      total.final_entry          += G_CT_Counters[i].final_entry;
      total.setups_started       += G_CT_Counters[i].setups_started;
      total.setups_invalidated   += G_CT_Counters[i].setups_invalidated;
      total.setups_timeout       += G_CT_Counters[i].setups_timeout;
   }

   PrintCTFunnelBlock("ALL PAIRS COMBINED", total);

   Print("\n--- PER-PAIR BREAKDOWN ---");
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string sym = G_Pairs[i].symbol;
      PrintFormat("\n[%s] Valid=%d | Exh=%d | Swp=%d | Disp=%d | MSS=%d | ScorePass=%d | FinalEntry=%d",
                  sym,
                  G_CT_Counters[i].htf_zone_valid,
                  G_CT_Counters[i].exhaustion_found,
                  G_CT_Counters[i].sweep_found,
                  G_CT_Counters[i].displacement_found,
                  G_CT_Counters[i].mss_found,
                  G_CT_Counters[i].score_pass,
                  G_CT_Counters[i].final_entry);
   }

   Print("==================================================\n");
}

#endif // __REVERSAL_DIAGNOSTICS_MQH__
