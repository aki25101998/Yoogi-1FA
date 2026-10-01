//+------------------------------------------------------------------+
//|                                  TrendFollowingDiagnostics.mqh   |
//|                                                  Yoogi Trading   |
//|       Trend Following Rejection Funnel & Candidate Statistics    |
//|       PURE OBSERVABILITY / DIAGNOSTICS MODULE (NO LOGIC CHANGE)  |
//+------------------------------------------------------------------+
#property strict

#ifndef __TREND_FOLLOWING_DIAGNOSTICS_MQH__
#define __TREND_FOLLOWING_DIAGNOSTICS_MQH__

// Funnel Step Enums (Candidate progression stages)
enum ENUM_TF_FUNNEL_STEP
{
   TF_FUNNEL_H1_EVAL = 0,
   TF_FUNNEL_H1_VALID,
   TF_FUNNEL_M15_VALID,
   TF_FUNNEL_SWEEP_FOUND,
   TF_FUNNEL_DISPLACEMENT_FOUND,
   TF_FUNNEL_MSS_FOUND,
   TF_FUNNEL_MOMENTUM_PASS,
   TF_FUNNEL_SCORE_PASS,
   TF_FUNNEL_PHASE2_PASS,
   TF_FUNNEL_PHASE3_PASS,
   TF_FUNNEL_FINAL_ENTRY,
   TF_FUNNEL_STEPS_TOTAL
};

// Metric distribution tracker struct
struct TFMetricDist
{
   int    count;
   double sum;
   double min_val;
   double max_val;
   
   void Init()
   {
      count = 0;
      sum = 0.0;
      min_val = 9999999.0;
      max_val = -9999999.0;
   }
   
   void Add(double val)
   {
      count++;
      sum += val;
      if(val < min_val) min_val = val;
      if(val > max_val) max_val = val;
   }
   
   double Avg() const
   {
      return (count > 0) ? (sum / count) : 0.0;
   }
   
   double Min() const
   {
      return (count > 0) ? min_val : 0.0;
   }
   
   double Max() const
   {
      return (count > 0) ? max_val : 0.0;
   }
};

// Funnel and rejection counters struct
struct TFFunnelCounters
{
   // Funnel Unique Candidates Passed
   int funnel_h1_valid;
   int funnel_m15_valid;
   int funnel_sweep_found;
   int funnel_disp_found;
   int funnel_mss_found;
   int funnel_mom_pass;
   int funnel_score_pass;
   int funnel_p2_pass;
   int funnel_p3_pass;
   int funnel_final_entry;

   // 2. H1 Statistics
   int h1_evaluated;
   int h1_valid;
   int h1_reject;
   int h1_strong;
   int h1_base;
   
   // 3. M15 Statistics
   int m15_evaluated;
   int m15_valid;
   int m15_reject;
   int m15_rej_protected;
   int m15_rej_depth;
   int m15_rej_ema;
   int m15_rej_stale;
   int m15_rej_impulse;
   int m15_rej_h1_trend;
   int m15_rej_other;
   int m15_invalidation;
   
   // 4. M5 Sweep Statistics
   int sweep_evaluated;
   int sweep_found;
   int sweep_reject;
   int sweep_raw_total;
   int sweep_qualified_total;
   int sweep_rej_consumed;
   int sweep_rej_broken;
   int sweep_rej_range;
   int sweep_rej_nosweep;
   
   // 5. M5 Displacement Statistics
   int disp_evaluated;
   int disp_found;
   int disp_reject;
   int disp_weak;
   int disp_timeout;
   
   // 6. M5 MSS Statistics
   int mss_evaluated;
   int mss_found;
   int mss_reject;
   int mss_weak;
   int mss_timeout;
   
   // 7. Event Coherence Statistics
   int coherence_evaluated;
   int coherence_pass;
   int coherence_reject;
   int coherence_timeout;
   
   // 8. Momentum Statistics
   int mom_evaluated;
   int mom_pass;
   int mom_fail;
   int mom_timeout;
   int mom_cci_pass;
   int mom_rf_pass;
   int mom_pc_pass;
   int mom_combo_cci_rf;
   int mom_combo_cci_pc;
   int mom_combo_rf_pc;
   int mom_combo_all;
   int mom_fail_cci_stale;
   int mom_fail_rf_stale;
   int mom_fail_pc_missing;
   int mom_fail_opposite;
   
   // 9. Score Distribution Statistics
   int score_evaluated;
   int score_ge_100;
   int score_95_99;
   int score_90_94;
   int score_80_89;
   int score_lt_80;
   int score_hist[101]; // integer distribution 0..100
   
   // 10. Phase 2 Hard Gate Failures
   int p2_evaluated;
   int p2_pass;
   int p2_rej_h1;
   int p2_rej_m15;
   int p2_rej_protected;
   int p2_rej_sweep;
   int p2_rej_displacement;
   int p2_rej_mss;
   int p2_rej_coherence;
   int p2_rej_momentum;
   int p2_rej_entry_dist;
   int p2_rej_entry_ext;
   int p2_rej_dxy;
   int p2_rej_score;
   
   // Phase 2 First Reject Reasons
   int p2_first_h1;
   int p2_first_m15;
   int p2_first_protected;
   int p2_first_sweep;
   int p2_first_displacement;
   int p2_first_mss;
   int p2_first_coherence;
   int p2_first_momentum;
   int p2_first_entry_dist;
   int p2_first_entry_ext;
   int p2_first_dxy;
   int p2_first_score;
   int p2_first_other;
   
   // 11. Phase 3 Context Gate Failures
   int p3_evaluated;
   int p3_pass;
   int p3_rej_volatility;
   int p3_rej_entry_candle;
   int p3_rej_spread;
   int p3_rej_disp_ext;
   int p3_rej_adverse_retrace;
   int p3_rej_no_post_mss;
   
   // Final Entry Counter
   int final_entry;
   
   // Phase 3 Metric Distributions
   TFMetricDist dist_atr_ratio;
   TFMetricDist dist_body_ratio;
   TFMetricDist dist_close_loc;
   TFMetricDist dist_spread_pts;
   TFMetricDist dist_spread_atr;
   TFMetricDist dist_rel_ext;
   TFMetricDist dist_adverse_atr;
   
   void Init()
   {
      funnel_h1_valid = 0;
      funnel_m15_valid = 0;
      funnel_sweep_found = 0;
      funnel_disp_found = 0;
      funnel_mss_found = 0;
      funnel_mom_pass = 0;
      funnel_score_pass = 0;
      funnel_p2_pass = 0;
      funnel_p3_pass = 0;
      funnel_final_entry = 0;

      h1_evaluated = 0; h1_valid = 0; h1_reject = 0; h1_strong = 0; h1_base = 0;
      m15_evaluated = 0; m15_valid = 0; m15_reject = 0;
      m15_rej_protected = 0; m15_rej_depth = 0; m15_rej_ema = 0;
      m15_rej_stale = 0; m15_rej_impulse = 0; m15_rej_h1_trend = 0;
      m15_rej_other = 0; m15_invalidation = 0;
      
      sweep_evaluated = 0; sweep_found = 0; sweep_reject = 0;
      sweep_raw_total = 0; sweep_qualified_total = 0;
      sweep_rej_consumed = 0; sweep_rej_broken = 0;
      sweep_rej_range = 0; sweep_rej_nosweep = 0;
      
      disp_evaluated = 0; disp_found = 0; disp_reject = 0; disp_weak = 0; disp_timeout = 0;
      mss_evaluated = 0; mss_found = 0; mss_reject = 0; mss_weak = 0; mss_timeout = 0;
      
      coherence_evaluated = 0; coherence_pass = 0; coherence_reject = 0; coherence_timeout = 0;
      
      mom_evaluated = 0; mom_pass = 0; mom_fail = 0; mom_timeout = 0;
      mom_cci_pass = 0; mom_rf_pass = 0; mom_pc_pass = 0;
      mom_combo_cci_rf = 0; mom_combo_cci_pc = 0; mom_combo_rf_pc = 0; mom_combo_all = 0;
      mom_fail_cci_stale = 0; mom_fail_rf_stale = 0; mom_fail_pc_missing = 0; mom_fail_opposite = 0;
      
      score_evaluated = 0; score_ge_100 = 0; score_95_99 = 0; score_90_94 = 0;
      score_80_89 = 0; score_lt_80 = 0;
      ArrayInitialize(score_hist, 0);
      
      p2_evaluated = 0; p2_pass = 0;
      p2_rej_h1 = 0; p2_rej_m15 = 0; p2_rej_protected = 0; p2_rej_sweep = 0;
      p2_rej_displacement = 0; p2_rej_mss = 0; p2_rej_coherence = 0; p2_rej_momentum = 0;
      p2_rej_entry_dist = 0; p2_rej_entry_ext = 0; p2_rej_dxy = 0; p2_rej_score = 0;
      
      p2_first_h1 = 0; p2_first_m15 = 0; p2_first_protected = 0; p2_first_sweep = 0;
      p2_first_displacement = 0; p2_first_mss = 0; p2_first_coherence = 0; p2_first_momentum = 0;
      p2_first_entry_dist = 0; p2_first_entry_ext = 0; p2_first_dxy = 0; p2_first_score = 0;
      p2_first_other = 0;
      
      p3_evaluated = 0; p3_pass = 0;
      p3_rej_volatility = 0; p3_rej_entry_candle = 0; p3_rej_spread = 0;
      p3_rej_disp_ext = 0; p3_rej_adverse_retrace = 0; p3_rej_no_post_mss = 0;
      
      final_entry = 0;
      
      dist_atr_ratio.Init();
      dist_body_ratio.Init();
      dist_close_loc.Init();
      dist_spread_pts.Init();
      dist_spread_atr.Init();
      dist_rel_ext.Init();
      dist_adverse_atr.Init();
   }
   
   void Add(const TFFunnelCounters &other)
   {
      funnel_h1_valid += other.funnel_h1_valid;
      funnel_m15_valid += other.funnel_m15_valid;
      funnel_sweep_found += other.funnel_sweep_found;
      funnel_disp_found += other.funnel_disp_found;
      funnel_mss_found += other.funnel_mss_found;
      funnel_mom_pass += other.funnel_mom_pass;
      funnel_score_pass += other.funnel_score_pass;
      funnel_p2_pass += other.funnel_p2_pass;
      funnel_p3_pass += other.funnel_p3_pass;
      funnel_final_entry += other.funnel_final_entry;

      h1_evaluated += other.h1_evaluated;
      h1_valid += other.h1_valid;
      h1_reject += other.h1_reject;
      h1_strong += other.h1_strong;
      h1_base += other.h1_base;
      
      m15_evaluated += other.m15_evaluated;
      m15_valid += other.m15_valid;
      m15_reject += other.m15_reject;
      m15_rej_protected += other.m15_rej_protected;
      m15_rej_depth += other.m15_rej_depth;
      m15_rej_ema += other.m15_rej_ema;
      m15_rej_stale += other.m15_rej_stale;
      m15_rej_impulse += other.m15_rej_impulse;
      m15_rej_h1_trend += other.m15_rej_h1_trend;
      m15_rej_other += other.m15_rej_other;
      m15_invalidation += other.m15_invalidation;
      
      sweep_evaluated += other.sweep_evaluated;
      sweep_found += other.sweep_found;
      sweep_reject += other.sweep_reject;
      sweep_raw_total += other.sweep_raw_total;
      sweep_qualified_total += other.sweep_qualified_total;
      sweep_rej_consumed += other.sweep_rej_consumed;
      sweep_rej_broken += other.sweep_rej_broken;
      sweep_rej_range += other.sweep_rej_range;
      sweep_rej_nosweep += other.sweep_rej_nosweep;
      
      disp_evaluated += other.disp_evaluated;
      disp_found += other.disp_found;
      disp_reject += other.disp_reject;
      disp_weak += other.disp_weak;
      disp_timeout += other.disp_timeout;
      
      mss_evaluated += other.mss_evaluated;
      mss_found += other.mss_found;
      mss_reject += other.mss_reject;
      mss_weak += other.mss_weak;
      mss_timeout += other.mss_timeout;
      
      coherence_evaluated += other.coherence_evaluated;
      coherence_pass += other.coherence_pass;
      coherence_reject += other.coherence_reject;
      coherence_timeout += other.coherence_timeout;
      
      mom_evaluated += other.mom_evaluated;
      mom_pass += other.mom_pass;
      mom_fail += other.mom_fail;
      mom_timeout += other.mom_timeout;
      mom_cci_pass += other.mom_cci_pass;
      mom_rf_pass += other.mom_rf_pass;
      mom_pc_pass += other.mom_pc_pass;
      mom_combo_cci_rf += other.mom_combo_cci_rf;
      mom_combo_cci_pc += other.mom_combo_cci_pc;
      mom_combo_rf_pc += other.mom_combo_rf_pc;
      mom_combo_all += other.mom_combo_all;
      mom_fail_cci_stale += other.mom_fail_cci_stale;
      mom_fail_rf_stale += other.mom_fail_rf_stale;
      mom_fail_pc_missing += other.mom_fail_pc_missing;
      mom_fail_opposite += other.mom_fail_opposite;
      
      score_evaluated += other.score_evaluated;
      score_ge_100 += other.score_ge_100;
      score_95_99 += other.score_95_99;
      score_90_94 += other.score_90_94;
      score_80_89 += other.score_80_89;
      score_lt_80 += other.score_lt_80;
      for(int s = 0; s <= 100; s++) score_hist[s] += other.score_hist[s];
      
      p2_evaluated += other.p2_evaluated;
      p2_pass += other.p2_pass;
      p2_rej_h1 += other.p2_rej_h1;
      p2_rej_m15 += other.p2_rej_m15;
      p2_rej_protected += other.p2_rej_protected;
      p2_rej_sweep += other.p2_rej_sweep;
      p2_rej_displacement += other.p2_rej_displacement;
      p2_rej_mss += other.p2_rej_mss;
      p2_rej_coherence += other.p2_rej_coherence;
      p2_rej_momentum += other.p2_rej_momentum;
      p2_rej_entry_dist += other.p2_rej_entry_dist;
      p2_rej_entry_ext += other.p2_rej_entry_ext;
      p2_rej_dxy += other.p2_rej_dxy;
      p2_rej_score += other.p2_rej_score;
      
      p2_first_h1 += other.p2_first_h1;
      p2_first_m15 += other.p2_first_m15;
      p2_first_protected += other.p2_first_protected;
      p2_first_sweep += other.p2_first_sweep;
      p2_first_displacement += other.p2_first_displacement;
      p2_first_mss += other.p2_first_mss;
      p2_first_coherence += other.p2_first_coherence;
      p2_first_momentum += other.p2_first_momentum;
      p2_first_entry_dist += other.p2_first_entry_dist;
      p2_first_entry_ext += other.p2_first_entry_ext;
      p2_first_dxy += other.p2_first_dxy;
      p2_first_score += other.p2_first_score;
      p2_first_other += other.p2_first_other;
      
      p3_evaluated += other.p3_evaluated;
      p3_pass += other.p3_pass;
      p3_rej_volatility += other.p3_rej_volatility;
      p3_rej_entry_candle += other.p3_rej_entry_candle;
      p3_rej_spread += other.p3_rej_spread;
      p3_rej_disp_ext += other.p3_rej_disp_ext;
      p3_rej_adverse_retrace += other.p3_rej_adverse_retrace;
      p3_rej_no_post_mss += other.p3_rej_no_post_mss;
      
      final_entry += other.final_entry;
      
      if(other.dist_atr_ratio.count > 0)
      {
         dist_atr_ratio.count += other.dist_atr_ratio.count;
         dist_atr_ratio.sum += other.dist_atr_ratio.sum;
         if(other.dist_atr_ratio.min_val < dist_atr_ratio.min_val) dist_atr_ratio.min_val = other.dist_atr_ratio.min_val;
         if(other.dist_atr_ratio.max_val > dist_atr_ratio.max_val) dist_atr_ratio.max_val = other.dist_atr_ratio.max_val;
      }
      if(other.dist_body_ratio.count > 0)
      {
         dist_body_ratio.count += other.dist_body_ratio.count;
         dist_body_ratio.sum += other.dist_body_ratio.sum;
         if(other.dist_body_ratio.min_val < dist_body_ratio.min_val) dist_body_ratio.min_val = other.dist_body_ratio.min_val;
         if(other.dist_body_ratio.max_val > dist_body_ratio.max_val) dist_body_ratio.max_val = other.dist_body_ratio.max_val;
      }
      if(other.dist_close_loc.count > 0)
      {
         dist_close_loc.count += other.dist_close_loc.count;
         dist_close_loc.sum += other.dist_close_loc.sum;
         if(other.dist_close_loc.min_val < dist_close_loc.min_val) dist_close_loc.min_val = other.dist_close_loc.min_val;
         if(other.dist_close_loc.max_val > dist_close_loc.max_val) dist_close_loc.max_val = other.dist_close_loc.max_val;
      }
      if(other.dist_spread_pts.count > 0)
      {
         dist_spread_pts.count += other.dist_spread_pts.count;
         dist_spread_pts.sum += other.dist_spread_pts.sum;
         if(other.dist_spread_pts.min_val < dist_spread_pts.min_val) dist_spread_pts.min_val = other.dist_spread_pts.min_val;
         if(other.dist_spread_pts.max_val > dist_spread_pts.max_val) dist_spread_pts.max_val = other.dist_spread_pts.max_val;
      }
      if(other.dist_spread_atr.count > 0)
      {
         dist_spread_atr.count += other.dist_spread_atr.count;
         dist_spread_atr.sum += other.dist_spread_atr.sum;
         if(other.dist_spread_atr.min_val < dist_spread_atr.min_val) dist_spread_atr.min_val = other.dist_spread_atr.min_val;
         if(other.dist_spread_atr.max_val > dist_spread_atr.max_val) dist_spread_atr.max_val = other.dist_spread_atr.max_val;
      }
      if(other.dist_rel_ext.count > 0)
      {
         dist_rel_ext.count += other.dist_rel_ext.count;
         dist_rel_ext.sum += other.dist_rel_ext.sum;
         if(other.dist_rel_ext.min_val < dist_rel_ext.min_val) dist_rel_ext.min_val = other.dist_rel_ext.min_val;
         if(other.dist_rel_ext.max_val > dist_rel_ext.max_val) dist_rel_ext.max_val = other.dist_rel_ext.max_val;
      }
      if(other.dist_adverse_atr.count > 0)
      {
         dist_adverse_atr.count += other.dist_adverse_atr.count;
         dist_adverse_atr.sum += other.dist_adverse_atr.sum;
         if(other.dist_adverse_atr.min_val < dist_adverse_atr.min_val) dist_adverse_atr.min_val = other.dist_adverse_atr.min_val;
         if(other.dist_adverse_atr.max_val > dist_adverse_atr.max_val) dist_adverse_atr.max_val = other.dist_adverse_atr.max_val;
      }
   }
};

// Per-symbol diagnostics context
#define TF_DIR_BUY  0
#define TF_DIR_SELL 1
#define TF_DIR_TOT  2

inline int TFDiag_DirToIdx(int dir)
{
   if(dir == 1) return TF_DIR_BUY;
   if(dir == -1) return TF_DIR_SELL;
   return TF_DIR_TOT;
}

#define TF_INC(idx, d, field) do { g_tf_diag[idx].stats[d].field++; if(d != TF_DIR_TOT) g_tf_diag[idx].stats[TF_DIR_TOT].field++; } while(false)
#define TF_ADD(idx, d, field, val) do { g_tf_diag[idx].stats[d].field += (val); if(d != TF_DIR_TOT) g_tf_diag[idx].stats[TF_DIR_TOT].field += (val); } while(false)
#define TF_DIST_ADD(idx, d, field, val) do { g_tf_diag[idx].stats[d].field.Add(val); if(d != TF_DIR_TOT) g_tf_diag[idx].stats[TF_DIR_TOT].field.Add(val); } while(false)

struct TFSymbolDiagnostics
{
   TFFunnelCounters stats[3];
   
   // Timestamp guards to ensure at most 1 count per candle per stage
   datetime last_h1_time;
   datetime last_m15_time;
   datetime last_sweep_time;
   datetime last_disp_time;
   datetime last_mss_time;
   datetime last_coherence_time;
   datetime last_mom_time;
   datetime last_score_time;
   datetime last_p2_time;
   datetime last_p3_time;
   
   // Setup lifecycle state flags (to ensure unique setup counting in funnel)
   int  current_setup_id;
   int  current_setup_dir;
   bool funnel_reached[TF_FUNNEL_STEPS_TOTAL];
   
   void Init()
   {
      stats[TF_DIR_BUY].Init();
      stats[TF_DIR_SELL].Init();
      stats[TF_DIR_TOT].Init();
      
      last_h1_time = 0;
      last_m15_time = 0;
      last_sweep_time = 0;
      last_disp_time = 0;
      last_mss_time = 0;
      last_coherence_time = 0;
      last_mom_time = 0;
      last_score_time = 0;
      last_p2_time = 0;
      last_p3_time = 0;
      
      current_setup_id = 0;
      current_setup_dir = 0;
      ArrayInitialize(funnel_reached, false);
   }
};

// Global Diagnostic Storage
static TFSymbolDiagnostics g_tf_diag[TOTAL_PAIRS];
static int                 g_tf_global_setup_counter = 0;
static bool                g_tf_diag_initialized = false;

// Forward declarations
void TFDiag_Init();
int  TFDiag_StartSetup(int idx, int dir);
void TFDiag_EndSetup(int idx, string reason);
void TFDiag_RecordFunnelStep(int idx, int dir, ENUM_TF_FUNNEL_STEP step);
void TFDiag_LogFunnel(int idx, int dir, string stage, string result, string detail = "");
void TFDiag_PrintFunnelSummary();
string TFDiag_GetChartDisplaySummary();

// Initialize all diagnostic storage
void TFDiag_Init()
{
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      g_tf_diag[i].Init();
   }
   g_tf_global_setup_counter = 0;
   g_tf_diag_initialized = true;
}

// Generate new monotonic Setup ID
int TFDiag_StartSetup(int idx, int dir)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return 0;
   
   g_tf_global_setup_counter++;
   g_tf_diag[idx].current_setup_id = g_tf_global_setup_counter;
   g_tf_diag[idx].current_setup_dir = dir;
   ArrayInitialize(g_tf_diag[idx].funnel_reached, false);
   
   return g_tf_diag[idx].current_setup_id;
}

// Reset setup ID on cancellation / timeout
void TFDiag_EndSetup(int idx, string reason)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   g_tf_diag[idx].current_setup_id = 0;
   g_tf_diag[idx].current_setup_dir = 0;
   ArrayInitialize(g_tf_diag[idx].funnel_reached, false);
}

// Record funnel stage (guaranteed at most once per setup)
void TFDiag_RecordFunnelStep(int idx, int dir, ENUM_TF_FUNNEL_STEP step)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(step < 0 || step >= TF_FUNNEL_STEPS_TOTAL) return;
   
   if(g_tf_diag[idx].funnel_reached[step])
      return; // Already recorded for this setup lifecycle
      
   g_tf_diag[idx].funnel_reached[step] = true;
   int d = TFDiag_DirToIdx(dir);
   
   switch(step)
   {
      case TF_FUNNEL_H1_VALID:          TF_INC(idx, d, funnel_h1_valid); break;
      case TF_FUNNEL_M15_VALID:         TF_INC(idx, d, funnel_m15_valid); break;
      case TF_FUNNEL_SWEEP_FOUND:       TF_INC(idx, d, funnel_sweep_found); break;
      case TF_FUNNEL_DISPLACEMENT_FOUND: TF_INC(idx, d, funnel_disp_found); break;
      case TF_FUNNEL_MSS_FOUND:         TF_INC(idx, d, funnel_mss_found); break;
      case TF_FUNNEL_MOMENTUM_PASS:     TF_INC(idx, d, funnel_mom_pass); break;
      case TF_FUNNEL_SCORE_PASS:        TF_INC(idx, d, funnel_score_pass); break;
      case TF_FUNNEL_PHASE2_PASS:       TF_INC(idx, d, funnel_p2_pass); break;
      case TF_FUNNEL_PHASE3_PASS:       TF_INC(idx, d, funnel_p3_pass); break;
      case TF_FUNNEL_FINAL_ENTRY:       TF_INC(idx, d, funnel_final_entry); break;
   }
}

// Log funnel transitions with strict formatting (Section 13 & 14)
void TFDiag_LogFunnel(int idx, int dir, string stage, string result, string detail = "")
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   
   string sym = G_Pairs[idx].symbol;
   string dir_str = (dir == 1 ? "BUY" : (dir == -1 ? "SELL" : "NONE"));
   int setup_id = G_TF[idx].tf_setup_id;
   
   if(detail != "")
   {
      PrintFormat("[TF_FUNNEL] SETUP_ID=%d SYMBOL=%s DIRECTION=%s STAGE=%s RESULT=%s DETAIL=%s",
                  setup_id, sym, dir_str, stage, result, detail);
   }
   else
   {
      PrintFormat("[TF_FUNNEL] SETUP_ID=%d SYMBOL=%s DIRECTION=%s STAGE=%s RESULT=%s",
                  setup_id, sym, dir_str, stage, result);
   }
}

// ------------------------------------------------------------------
// 2. H1 Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordH1(int idx, int dir, double quality, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_h1_time) return; // Guard against multiple calls on same candle
   g_tf_diag[idx].last_h1_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, h1_evaluated);
   
   if(dir == 1 || dir == -1)
   {
      TF_INC(idx, d, h1_valid);
      if(quality >= TF_H1_QUALITY_STRONG)
         TF_INC(idx, d, h1_strong);
      else
         TF_INC(idx, d, h1_base);
   }
   else
   {
      g_tf_diag[idx].stats[TF_DIR_TOT].h1_reject++;
   }
}

// ------------------------------------------------------------------
// 3. M15 Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordM15(int idx, int dir, bool pass, string reject_reason, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_m15_time) return;
   g_tf_diag[idx].last_m15_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, m15_evaluated);
   
   if(pass)
   {
      TF_INC(idx, d, m15_valid);
   }
   else
   {
      TF_INC(idx, d, m15_reject);
      
      if(reject_reason == "PROTECTED_HL_BROKEN" || reject_reason == "PROTECTED_LH_BROKEN" ||
         reject_reason == "ORIGIN_LOW_INVALIDATED" || reject_reason == "ORIGIN_HIGH_INVALIDATED")
      {
         TF_INC(idx, d, m15_rej_protected);
      }
      else if(reject_reason == "PULLBACK_DEPTH_OUT_OF_BOUNDS")
      {
         TF_INC(idx, d, m15_rej_depth);
      }
      else if(reject_reason == "EMA_DISTANCE_TOO_FAR")
      {
         TF_INC(idx, d, m15_rej_ema);
      }
      else if(reject_reason == "IMPULSE_STALE")
      {
         TF_INC(idx, d, m15_rej_stale);
      }
      else if(reject_reason == "M15_IMPULSE_NOT_BULLISH" || reject_reason == "M15_IMPULSE_NOT_BEARISH" ||
              reject_reason == "PRICE_ABOVE_IMPULSE_HIGH" || reject_reason == "PRICE_BELOW_IMPULSE_LOW" ||
              reject_reason == "NO_VALID_IMPULSE")
      {
         TF_INC(idx, d, m15_rej_impulse);
      }
      else if(reject_reason == "H1_TREND_NOT_BUY" || reject_reason == "H1_TREND_NOT_SELL")
      {
         TF_INC(idx, d, m15_rej_h1_trend);
      }
      else
      {
         TF_INC(idx, d, m15_rej_other);
      }
   }
}

void TFDiag_RecordM15Invalidation(int idx, int dir, datetime tm = 0)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, m15_invalidation);
}

// ------------------------------------------------------------------
// 4. M5 Sweep Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordSweep(int idx, int dir, bool found, datetime tm,
                        int candidates, int raw, int qual, int rej_consumed, int rej_broken, int rej_range, int rej_nosweep)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_sweep_time) return;
   g_tf_diag[idx].last_sweep_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, sweep_evaluated);
   
   TF_ADD(idx, d, sweep_raw_total, raw);
   TF_ADD(idx, d, sweep_qualified_total, qual);
   TF_ADD(idx, d, sweep_rej_consumed, rej_consumed);
   TF_ADD(idx, d, sweep_rej_broken, rej_broken);
   TF_ADD(idx, d, sweep_rej_range, rej_range);
   TF_ADD(idx, d, sweep_rej_nosweep, rej_nosweep);
   
   if(found)
   {
      TF_INC(idx, d, sweep_found);
   }
   else
   {
      TF_INC(idx, d, sweep_reject);
   }
}

// ------------------------------------------------------------------
// 5. M5 Displacement Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordDisplacement(int idx, int dir, bool pass, double range_atr, double min_atr, datetime tm, string note = "")
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_disp_time) return;
   g_tf_diag[idx].last_disp_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, disp_evaluated);
   
   if(pass)
   {
      TF_INC(idx, d, disp_found);
   }
   else
   {
      TF_INC(idx, d, disp_reject);
      if(range_atr > 0.0 && range_atr < min_atr)
      {
         TF_INC(idx, d, disp_weak);
      }
   }
}

// ------------------------------------------------------------------
// 6. M5 MSS Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordMSS(int idx, int dir, bool pass, double break_atr, double min_atr, datetime tm, string note = "")
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_mss_time) return;
   g_tf_diag[idx].last_mss_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, mss_evaluated);
   
   if(pass)
   {
      TF_INC(idx, d, mss_found);
   }
   else
   {
      TF_INC(idx, d, mss_reject);
      if(break_atr > 0.0 && break_atr < min_atr)
      {
         TF_INC(idx, d, mss_weak);
      }
   }
}

// ------------------------------------------------------------------
// 7. Event Coherence Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordCoherence(int idx, int dir, bool pass, int seq_bars, int max_bars, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_coherence_time) return;
   g_tf_diag[idx].last_coherence_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, coherence_evaluated);
   
   if(pass)
   {
      TF_INC(idx, d, coherence_pass);
   }
   else
   {
      TF_INC(idx, d, coherence_reject);
      if(seq_bars > max_bars)
      {
         TF_INC(idx, d, coherence_timeout);
      }
   }
}

void TFDiag_RecordCoherenceTimeout(int idx, int dir, int seq_bars, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, coherence_timeout);
}

// ------------------------------------------------------------------
// 8. Momentum Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordMomentumEval(int idx, int dir, int bars_elapsed,
                               bool cci, bool rf, bool pc, double score,
                               int cci_status, int rf_status, datetime cci_time, datetime rf_time, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_mom_time) return;
   g_tf_diag[idx].last_mom_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, mom_evaluated);
   
   if(cci) TF_INC(idx, d, mom_cci_pass);
   if(rf)  TF_INC(idx, d, mom_rf_pass);
   if(pc)  TF_INC(idx, d, mom_pc_pass);
   
   // Combinations
   if(cci && rf && pc)
   {
      TF_INC(idx, d, mom_combo_all);
   }
   else if(cci && rf && !pc)
   {
      TF_INC(idx, d, mom_combo_cci_rf);
   }
   else if(cci && !rf && pc)
   {
      TF_INC(idx, d, mom_combo_cci_pc);
   }
   else if(!cci && rf && pc)
   {
      TF_INC(idx, d, mom_combo_rf_pc);
   }
   
   // Distinctions
   if(!cci && cci_time > 0 && (tm - cci_time) > 3600)
   {
      TF_INC(idx, d, mom_fail_cci_stale);
   }
   if(!rf && rf_time > 0 && (tm - rf_time) > 3600)
   {
      TF_INC(idx, d, mom_fail_rf_stale);
   }
   if(!pc)
   {
      TF_INC(idx, d, mom_fail_pc_missing);
   }
   if((dir == 1 && (cci_status == -1 || rf_status == -1)) ||
      (dir == -1 && (cci_status == 1 || rf_status == 1)))
   {
      TF_INC(idx, d, mom_fail_opposite);
   }
   
   if(score >= 10.0)
   {
      TF_INC(idx, d, mom_pass);
   }
   else
   {
      TF_INC(idx, d, mom_fail);
   }
}

void TFDiag_RecordMomentumTimeout(int idx, int dir, int bars_elapsed, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, mom_timeout);
}

// ------------------------------------------------------------------
// 9. Score Distribution Statistics Recording
// ------------------------------------------------------------------
void TFDiag_RecordScore(int idx, int dir, double score, double req_score, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_score_time) return;
   g_tf_diag[idx].last_score_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, score_evaluated);
   
   int int_score = (int)MathRound(score);
   if(int_score < 0) int_score = 0;
   if(int_score > 100) int_score = 100;
   g_tf_diag[idx].stats[d].score_hist[int_score]++;
   if(d != TF_DIR_TOT)
      g_tf_diag[idx].stats[TF_DIR_TOT].score_hist[int_score]++;
   
   if(score >= 100.0)
   {
      TF_INC(idx, d, score_ge_100);
   }
   else if(score >= 95.0)
   {
      TF_INC(idx, d, score_95_99);
   }
   else if(score >= 90.0)
   {
      TF_INC(idx, d, score_90_94);
   }
   else if(score >= 80.0)
   {
      TF_INC(idx, d, score_80_89);
   }
   else
   {
      TF_INC(idx, d, score_lt_80);
   }
}

// ------------------------------------------------------------------
// 10. Phase 2 Statistics Recording (All Failed Gates + First Reject)
// ------------------------------------------------------------------
void TFDiag_RecordPhase2(int idx, int dir, bool pass, string first_reject,
                         bool rej_h1, bool rej_m15, bool rej_prot, bool rej_sweep,
                         bool rej_disp, bool rej_mss, bool rej_coh, bool rej_mom,
                         bool rej_dist, bool rej_ext, bool rej_dxy, bool rej_score,
                         datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_p2_time) return;
   g_tf_diag[idx].last_p2_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, p2_evaluated);
   
   if(pass)
   {
      TF_INC(idx, d, p2_pass);
   }
   else
   {
      // Record ALL failed gates
      if(rej_h1)    TF_INC(idx, d, p2_rej_h1);
      if(rej_m15)   TF_INC(idx, d, p2_rej_m15);
      if(rej_prot)  TF_INC(idx, d, p2_rej_protected);
      if(rej_sweep) TF_INC(idx, d, p2_rej_sweep);
      if(rej_disp)  TF_INC(idx, d, p2_rej_displacement);
      if(rej_mss)   TF_INC(idx, d, p2_rej_mss);
      if(rej_coh)   TF_INC(idx, d, p2_rej_coherence);
      if(rej_mom)   TF_INC(idx, d, p2_rej_momentum);
      if(rej_dist)  TF_INC(idx, d, p2_rej_entry_dist);
      if(rej_ext)   TF_INC(idx, d, p2_rej_entry_ext);
      if(rej_dxy)   TF_INC(idx, d, p2_rej_dxy);
      if(rej_score) TF_INC(idx, d, p2_rej_score);
      
      // Record FIRST reject reason
      if(first_reject == "TF_P2_H1_REJECT") TF_INC(idx, d, p2_first_h1);
      else if(first_reject == "TF_P2_M15_REJECT") TF_INC(idx, d, p2_first_m15);
      else if(first_reject == "TF_P2_SWEEP_REJECT") TF_INC(idx, d, p2_first_sweep);
      else if(first_reject == "TF_P2_DISPLACEMENT_REJECT") TF_INC(idx, d, p2_first_displacement);
      else if(first_reject == "TF_P2_MSS_REJECT") TF_INC(idx, d, p2_first_mss);
      else if(first_reject == "EVENT_NOT_COHERENT") TF_INC(idx, d, p2_first_coherence);
      else if(first_reject == "TF_P2_MOMENTUM_REJECT") TF_INC(idx, d, p2_first_momentum);
      else if(first_reject == "TF_P2_ENTRY_LOCATION_REJECT") TF_INC(idx, d, p2_first_entry_dist);
      else if(StringFind(first_reject, "DXY_") == 0 || first_reject == "TF_P2_DXY_REJECT") TF_INC(idx, d, p2_first_dxy);
      else if(first_reject == "TF_P2_SCORE_REJECT") TF_INC(idx, d, p2_first_score);
      else TF_INC(idx, d, p2_first_other);
   }
}

// ------------------------------------------------------------------
// 11. Phase 3 Statistics Recording (All Failed Gates + Metrics)
// ------------------------------------------------------------------
void TFDiag_RecordPhase3(int idx, int dir, bool pass, string first_reject,
                         bool vol_pass, bool candle_pass, bool spread_pass, bool ext_pass, bool retrace_pass, string retrace_reason,
                         double atr_ratio, double c_range, double c_body, double c_body_ratio, double c_close_loc,
                         double spread_pts, double spread_atr, double rel_ext, double adverse_atr, datetime tm)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   if(tm > 0 && tm == g_tf_diag[idx].last_p3_time) return;
   g_tf_diag[idx].last_p3_time = tm;
   
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, p3_evaluated);
   
   // Add distribution metrics
   TF_DIST_ADD(idx, d, dist_atr_ratio, atr_ratio);
   TF_DIST_ADD(idx, d, dist_body_ratio, c_body_ratio);
   TF_DIST_ADD(idx, d, dist_close_loc, c_close_loc);
   TF_DIST_ADD(idx, d, dist_spread_pts, spread_pts);
   TF_DIST_ADD(idx, d, dist_spread_atr, spread_atr);
   TF_DIST_ADD(idx, d, dist_rel_ext, rel_ext);
   TF_DIST_ADD(idx, d, dist_adverse_atr, adverse_atr);
   
   if(pass)
   {
      TF_INC(idx, d, p3_pass);
   }
   else
   {
      if(!vol_pass)     TF_INC(idx, d, p3_rej_volatility);
      if(!candle_pass)  TF_INC(idx, d, p3_rej_entry_candle);
      if(!spread_pass)  TF_INC(idx, d, p3_rej_spread);
      if(!ext_pass)     TF_INC(idx, d, p3_rej_disp_ext);
      if(!retrace_pass)
      {
         if(retrace_reason == "NO_POST_MSS_CANDLES")
         {
            TF_INC(idx, d, p3_rej_no_post_mss);
         }
         else
         {
            TF_INC(idx, d, p3_rej_adverse_retrace);
         }
      }
   }
}

// ------------------------------------------------------------------
// 12. Final Entry Recording
// ------------------------------------------------------------------
void TFDiag_RecordFinalEntry(int idx, int dir)
{
   if(idx < 0 || idx >= TOTAL_PAIRS) return;
   int d = TFDiag_DirToIdx(dir);
   TF_INC(idx, d, final_entry);
}

// ------------------------------------------------------------------
// Top Rejection Ranking Helper
// ------------------------------------------------------------------
struct TFRejectionRankItem
{
   string name;
   int    count;
};

void PrintFunnelBlock(string title, const TFFunnelCounters &c)
{
   PrintFormat("%s:", title);
   PrintFormat("H1 evaluated       : %d", c.h1_evaluated);
   PrintFormat("H1 valid           : %d", c.funnel_h1_valid);
   PrintFormat("M15 valid          : %d", c.funnel_m15_valid);
   PrintFormat("Sweep found        : %d", c.funnel_sweep_found);
   PrintFormat("Displacement found : %d", c.funnel_disp_found);
   PrintFormat("MSS found          : %d", c.funnel_mss_found);
   PrintFormat("Momentum pass      : %d", c.funnel_mom_pass);
   PrintFormat("Score >=95         : %d", c.funnel_score_pass);
   PrintFormat("Phase2 pass        : %d", c.funnel_p2_pass);
   PrintFormat("Phase3 pass        : %d", c.funnel_p3_pass);
   PrintFormat("FINAL ENTRY        : %d", c.funnel_final_entry);
   Print("");
   Print("REJECTIONS:");
   PrintFormat("H1                    : %d", c.h1_reject);
   PrintFormat("M15                   : %d", c.m15_reject);
   PrintFormat("Sweep                 : %d", c.sweep_reject);
   PrintFormat("Displacement          : %d", c.disp_reject);
   PrintFormat("MSS                   : %d", c.mss_reject);
   PrintFormat("Coherence             : %d", c.coherence_reject);
   PrintFormat("Momentum              : %d", c.mom_fail + c.mom_timeout);
   PrintFormat("Score                 : %d", (c.score_evaluated - c.score_ge_100 - c.score_95_99));
   PrintFormat("Phase2                : %d", (c.p2_evaluated - c.p2_pass));
   PrintFormat("Phase3 Volatility     : %d", c.p3_rej_volatility);
   PrintFormat("Phase3 Candle         : %d", c.p3_rej_entry_candle);
   PrintFormat("Phase3 Spread         : %d", c.p3_rej_spread);
   PrintFormat("Phase3 Extension      : %d", c.p3_rej_disp_ext);
   PrintFormat("Phase3 Retracement    : %d", c.p3_rej_adverse_retrace + c.p3_rej_no_post_mss);
}

void PrintDetailedMetricsBlock(string sym, const TFFunnelCounters &c)
{
   PrintFormat("\n--- DETAILED DIAGNOSTICS: %s ---", sym);
   PrintFormat("M15 Rejections: Total=%d | Protected=%d | Depth=%d | EMA=%d | Stale=%d | Impulse=%d | Trend=%d | Invalidations=%d",
               c.m15_reject, c.m15_rej_protected, c.m15_rej_depth, c.m15_rej_ema, c.m15_rej_stale, c.m15_rej_impulse, c.m15_rej_h1_trend, c.m15_invalidation);
   PrintFormat("M5 Sweep: Evaluated=%d | Found=%d | RejRaw=%d | RejNosweep=%d | RejBroken=%d | RejConsumed=%d | RejRange=%d",
               c.sweep_evaluated, c.sweep_found, c.sweep_raw_total, c.sweep_rej_nosweep, c.sweep_rej_broken, c.sweep_rej_consumed, c.sweep_rej_range);
   PrintFormat("M5 Displacement: Evaluated=%d | Found=%d | RejTotal=%d | Weak(<0.60 ATR)=%d",
               c.disp_evaluated, c.disp_found, c.disp_reject, c.disp_weak);
   PrintFormat("M5 MSS: Evaluated=%d | Found=%d | RejTotal=%d | Weak(<0.20 ATR)=%d",
               c.mss_evaluated, c.mss_found, c.mss_reject, c.mss_weak);
   PrintFormat("Event Coherence: Evaluated=%d | Pass=%d | RejTotal=%d | Timeout(>5 bars)=%d",
               c.coherence_evaluated, c.coherence_pass, c.coherence_reject, c.coherence_timeout);
   PrintFormat("Momentum: Evaluated=%d | Pass=%d | Fail=%d | Timeout(>10 bars)=%d",
               c.mom_evaluated, c.mom_pass, c.mom_fail, c.mom_timeout);
   PrintFormat("  Components: CCI=%d | RF=%d | PC=%d", c.mom_cci_pass, c.mom_rf_pass, c.mom_pc_pass);
   PrintFormat("  Combos: CCI+RF=%d | CCI+PC=%d | RF+PC=%d | ALL_THREE=%d",
               c.mom_combo_cci_rf, c.mom_combo_cci_pc, c.mom_combo_rf_pc, c.mom_combo_all);
   PrintFormat("  Fail Distinctions: CCI_Stale=%d | RF_Stale=%d | PC_Missing=%d | Opposite_Signal=%d",
               c.mom_fail_cci_stale, c.mom_fail_rf_stale, c.mom_fail_pc_missing, c.mom_fail_opposite);
   PrintFormat("Score Distribution: Total=%d | >=100=%d | 95-99=%d | 90-94=%d | 80-89=%d | <80=%d",
               c.score_evaluated, c.score_ge_100, c.score_95_99, c.score_90_94, c.score_80_89, c.score_lt_80);
   
   string hist_str = "";
   for(int s = 0; s <= 100; s++)
   {
      if(c.score_hist[s] > 0)
      {
         hist_str += StringFormat("[%d]=%d ", s, c.score_hist[s]);
      }
   }
   if(hist_str != "") PrintFormat("  Score Histogram: %s", hist_str);
   
   PrintFormat("Phase 2 All Failed Gates: Evaluated=%d | Pass=%d", c.p2_evaluated, c.p2_pass);
   PrintFormat("  H1=%d | M15=%d | Protected=%d | Sweep=%d | Disp=%d | MSS=%d | Coh=%d | Mom=%d | Dist=%d | Ext=%d | DXY=%d | Score=%d",
               c.p2_rej_h1, c.p2_rej_m15, c.p2_rej_protected, c.p2_rej_sweep, c.p2_rej_displacement, c.p2_rej_mss,
               c.p2_rej_coherence, c.p2_rej_momentum, c.p2_rej_entry_dist, c.p2_rej_entry_ext, c.p2_rej_dxy, c.p2_rej_score);
   PrintFormat("Phase 2 First Rejects: H1=%d | M15=%d | Prot=%d | Sweep=%d | Disp=%d | MSS=%d | Coh=%d | Mom=%d | Dist=%d | Ext=%d | DXY=%d | Score=%d | Other=%d",
               c.p2_first_h1, c.p2_first_m15, c.p2_first_protected, c.p2_first_sweep, c.p2_first_displacement, c.p2_first_mss,
               c.p2_first_coherence, c.p2_first_momentum, c.p2_first_entry_dist, c.p2_first_entry_ext, c.p2_first_dxy, c.p2_first_score, c.p2_first_other);
   
   PrintFormat("Phase 3 All Failed Filters: Evaluated=%d | Pass=%d", c.p3_evaluated, c.p3_pass);
   PrintFormat("  Volatility=%d | Candle=%d | Spread=%d | DispExt=%d | AdverseRetrace=%d | NoPostMSS=%d",
               c.p3_rej_volatility, c.p3_rej_entry_candle, c.p3_rej_spread, c.p3_rej_disp_ext, c.p3_rej_adverse_retrace, c.p3_rej_no_post_mss);
   
   if(c.dist_atr_ratio.count > 0)
   {
      PrintFormat("Phase 3 Metric Distributions (N=%d):", c.dist_atr_ratio.count);
      PrintFormat("  ATR Ratio      : Min=%.2f, Max=%.2f, Avg=%.2f (Allowed: 0.80..1.50)", c.dist_atr_ratio.Min(), c.dist_atr_ratio.Max(), c.dist_atr_ratio.Avg());
      PrintFormat("  Body Ratio     : Min=%.2f, Max=%.2f, Avg=%.2f (Allowed: >=0.35)", c.dist_body_ratio.Min(), c.dist_body_ratio.Max(), c.dist_body_ratio.Avg());
      PrintFormat("  Close Location : Min=%.2f, Max=%.2f, Avg=%.2f (Allowed: >=0.55)", c.dist_close_loc.Min(), c.dist_close_loc.Max(), c.dist_close_loc.Avg());
      PrintFormat("  Spread Points  : Min=%.0f, Max=%.0f, Avg=%.1f (Allowed: <=30)", c.dist_spread_pts.Min(), c.dist_spread_pts.Max(), c.dist_spread_pts.Avg());
      PrintFormat("  Spread ATR     : Min=%.2f, Max=%.2f, Avg=%.2f (Allowed: <=0.40)", c.dist_spread_atr.Min(), c.dist_spread_atr.Max(), c.dist_spread_atr.Avg());
      PrintFormat("  Disp Extension : Min=%.2f, Max=%.2f, Avg=%.2f (Allowed: <=1.80)", c.dist_rel_ext.Min(), c.dist_rel_ext.Max(), c.dist_rel_ext.Avg());
      PrintFormat("  Adverse Retrace: Min=%.2f, Max=%.2f, Avg=%.2f (Allowed: <=0.60)", c.dist_adverse_atr.Min(), c.dist_adverse_atr.Max(), c.dist_adverse_atr.Avg());
   }
}

// ------------------------------------------------------------------
// 15 & 16. Comprehensive Summary Output at Backtest End / Deinit
// ------------------------------------------------------------------
void TFDiag_PrintFunnelSummary()
{
   Print("\n========================================================");
   Print("TREND FOLLOWING REJECTION FUNNEL");
   Print("========================================================");
   
   TFFunnelCounters all_symbols_total;
   all_symbols_total.Init();
   
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      string sym = G_Pairs[i].symbol;
      PrintFormat("\nSYMBOL: %s", sym);
      Print("--------------------------------------------------------");
      PrintFunnelBlock("BUY", g_tf_diag[i].stats[TF_DIR_BUY]);
      Print("");
      PrintFunnelBlock("SELL", g_tf_diag[i].stats[TF_DIR_SELL]);
      Print("");
      PrintFunnelBlock("TOTAL (BUY+SELL)", g_tf_diag[i].stats[TF_DIR_TOT]);
      
      PrintDetailedMetricsBlock(sym, g_tf_diag[i].stats[TF_DIR_TOT]);
      Print("========================================================");
      
      all_symbols_total.Add(g_tf_diag[i].stats[TF_DIR_TOT]);
   }
   
   Print("\n========================================================");
   Print("ALL SYMBOLS TOTAL");
   Print("========================================================");
   PrintFunnelBlock("TOTAL ALL SYMBOLS", all_symbols_total);
   PrintDetailedMetricsBlock("ALL SYMBOLS", all_symbols_total);
   Print("========================================================");
   
   // 16. TOP REJECTION REASONS RANKING
   TFRejectionRankItem items[35];
   int n = 0;
   
   #define ADD_RANK_ITEM(label, cnt) \
      if(n < 35) { items[n].name = label; items[n].count = cnt; n++; }
   
   ADD_RANK_ITEM("Phase 3: Entry Candle Quality Reject", all_symbols_total.p3_rej_entry_candle);
   ADD_RANK_ITEM("Phase 3: Adverse Retracement Exceeded", all_symbols_total.p3_rej_adverse_retrace);
   ADD_RANK_ITEM("Phase 3: No Post-MSS Candles Wait", all_symbols_total.p3_rej_no_post_mss);
   ADD_RANK_ITEM("Phase 3: Spread / Execution Reject", all_symbols_total.p3_rej_spread);
   ADD_RANK_ITEM("Phase 3: Volatility Regime Reject", all_symbols_total.p3_rej_volatility);
   ADD_RANK_ITEM("Phase 3: Displacement Extension Reject", all_symbols_total.p3_rej_disp_ext);
   
   ADD_RANK_ITEM("Phase 2: Momentum Not Confirmed", all_symbols_total.p2_rej_momentum);
   ADD_RANK_ITEM("Phase 2: Score Below Threshold", all_symbols_total.p2_rej_score);
   ADD_RANK_ITEM("Phase 2: Entry Distance Too Far", all_symbols_total.p2_rej_entry_dist);
   ADD_RANK_ITEM("Phase 2: Entry Extension Too Far", all_symbols_total.p2_rej_entry_ext);
   ADD_RANK_ITEM("Phase 2: DXY Misaligned", all_symbols_total.p2_rej_dxy);
   ADD_RANK_ITEM("Phase 2: Event Coherence Broken", all_symbols_total.p2_rej_coherence);
   ADD_RANK_ITEM("Phase 2: MSS Break Distance Weak", all_symbols_total.p2_rej_mss);
   ADD_RANK_ITEM("Phase 2: Displacement Range Weak", all_symbols_total.p2_rej_displacement);
   ADD_RANK_ITEM("Phase 2: Sweep Missing", all_symbols_total.p2_rej_sweep);
   ADD_RANK_ITEM("Phase 2: M15 Quality Invalid", all_symbols_total.p2_rej_m15);
   ADD_RANK_ITEM("Phase 2: Protected Structure Broken", all_symbols_total.p2_rej_protected);
   ADD_RANK_ITEM("Phase 2: H1 Trend Invalid", all_symbols_total.p2_rej_h1);
   
   ADD_RANK_ITEM("M15: Protected Structure Broken", all_symbols_total.m15_rej_protected);
   ADD_RANK_ITEM("M15: Pullback Depth Out of Bounds", all_symbols_total.m15_rej_depth);
   ADD_RANK_ITEM("M15: EMA Distance Too Far", all_symbols_total.m15_rej_ema);
   ADD_RANK_ITEM("M15: Impulse Stale", all_symbols_total.m15_rej_stale);
   ADD_RANK_ITEM("M15: No Bullish/Bearish Impulse", all_symbols_total.m15_rej_impulse);
   
   ADD_RANK_ITEM("M5 Sweep: No Liquidity Sweep Found", all_symbols_total.sweep_rej_nosweep);
   ADD_RANK_ITEM("M5 Sweep: Swing Broken Before Sweep", all_symbols_total.sweep_rej_broken);
   ADD_RANK_ITEM("M5 Sweep: Target Consumed", all_symbols_total.sweep_rej_consumed);
   ADD_RANK_ITEM("M5 Sweep: Target Outside Range", all_symbols_total.sweep_rej_range);
   
   ADD_RANK_ITEM("M5 Displacement: Weak Range (<0.60 ATR)", all_symbols_total.disp_weak);
   ADD_RANK_ITEM("M5 MSS: Weak Break Distance (<0.20 ATR)", all_symbols_total.mss_weak);
   ADD_RANK_ITEM("M5 Event: Sequence Timeout (>5 bars)", all_symbols_total.coherence_timeout);
   
   ADD_RANK_ITEM("Momentum: Window Timeout (>10 bars)", all_symbols_total.mom_timeout);
   ADD_RANK_ITEM("Momentum: Price Continuation Missing", all_symbols_total.mom_fail_pc_missing);
   ADD_RANK_ITEM("Momentum: CCI Stale", all_symbols_total.mom_fail_cci_stale);
   ADD_RANK_ITEM("Momentum: Range Filter Stale", all_symbols_total.mom_fail_rf_stale);
   ADD_RANK_ITEM("Momentum: Opposite Signal", all_symbols_total.mom_fail_opposite);
   
   #undef ADD_RANK_ITEM
   
   // Sort descending by count
   for(int i = 0; i < n - 1; i++)
   {
      for(int j = i + 1; j < n; j++)
      {
         if(items[j].count > items[i].count)
         {
            TFRejectionRankItem tmp = items[i];
            items[i] = items[j];
            items[j] = tmp;
         }
      }
   }
   
   Print("\n[TF_TOP_REJECTION_REASONS]");
   int rank = 1;
   for(int i = 0; i < n; i++)
   {
      if(items[i].count > 0)
      {
         PrintFormat("%d. %s = %d", rank, items[i].name, items[i].count);
         rank++;
      }
   }
   if(rank == 1)
   {
      Print("(No rejections recorded)");
   }
   Print("========================================================\n");
}

// ------------------------------------------------------------------
// 17. Chart Display Summary Helper
// ------------------------------------------------------------------
string TFDiag_GetChartDisplaySummary()
{
   int tot_h1 = 0, tot_m15 = 0, tot_m5 = 0, tot_mom = 0, tot_p2 = 0, tot_p3 = 0, tot_entry = 0;
   
   for(int i = 0; i < TOTAL_PAIRS; i++)
   {
      tot_h1    += g_tf_diag[i].stats[TF_DIR_TOT].funnel_h1_valid;
      tot_m15   += g_tf_diag[i].stats[TF_DIR_TOT].funnel_m15_valid;
      tot_m5    += g_tf_diag[i].stats[TF_DIR_TOT].funnel_mss_found;
      tot_mom   += g_tf_diag[i].stats[TF_DIR_TOT].funnel_mom_pass;
      tot_p2    += g_tf_diag[i].stats[TF_DIR_TOT].funnel_p2_pass;
      tot_p3    += g_tf_diag[i].stats[TF_DIR_TOT].funnel_p3_pass;
      tot_entry += g_tf_diag[i].stats[TF_DIR_TOT].funnel_final_entry;
   }
   
   return StringFormat("FT Funnel | H1: %d | M15: %d | M5: %d | MOM: %d | P2: %d | P3: %d | ENTRY: %d",
                       tot_h1, tot_m15, tot_m5, tot_mom, tot_p2, tot_p3, tot_entry);
}

#endif // __TREND_FOLLOWING_DIAGNOSTICS_MQH__
