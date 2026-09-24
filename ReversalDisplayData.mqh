//+------------------------------------------------------------------+
//|                                        ReversalDisplayData.mqh   |
//|                                                  Yoogi Trading   |
//|   Provides unified Reversal Engine V2 state mapping for Dashboard|
//+------------------------------------------------------------------+
#property strict
#include "Globals.mqh"

struct ReversalDisplayData 
{ 
   string symbol; 
   string htfTrend; 
   string reversalBias; 
   double reversalScore; 
   double entryReadiness; 
   int    progressCompleted; 
   int    progressTotal; 
   string state; 
   string waitingFor; 
   string blockReason; 
   bool   htfZone; 
   bool   htfDivergence; 
   bool   htfExhaustion; 
   bool   ltfDivergence; 
   bool   ltfMSS; 
   bool   ltfExhaustion; 
   string cciRecovery; 
   string rangeFilter; 
   string dxyStatus; 
   bool   entryReady; 
   bool   activeChain; 
   string masterEntry;
   
   // V2 additions
   bool   sweep;
   bool   displacement;
   bool   rejection;
   bool   failedCont;
   bool   retest;
   string scoreBreakdown;
   
   // Trend-Following additions
   string tfState;
   string tfDirection;
   double tfScore;
   string tfScoreBreakdown;
   string entryMode;
   
   // Unified Dashboard Display Fields
   string displayMode;
   string displayDir;
   double displayScore;
   string displayScoreStr;
   string displayState;
   string displayNextGate;
   string displayBlockReason;
   string displayReadinessStr;
   string displayBreakdown;
};

bool BuildReversalDisplayData(int idx, ReversalDisplayData &data)
{
    if(idx < 0 || idx >= TOTAL_PAIRS) return false;
    
    // Basic Info
    data.symbol = G_Pairs[idx].symbol;
    
    // Trend (Regime)
    switch(G_Pairs[idx].regime)
    {
        case REGIME_TREND_BULL: data.htfTrend = "BULLISH"; break;
        case REGIME_TREND_BEAR: data.htfTrend = "BEARISH"; break;
        case REGIME_SIDEWAY:    data.htfTrend = "SIDEWAY"; break;
        case REGIME_EXHAUSTION: data.htfTrend = "EXHAUSTION"; break;
        default:                data.htfTrend = "UNKNOWN"; break;
    }
    
    // Reversal Bias
    if(G_Pairs[idx].htf_conflict)
    {
        data.reversalBias = "CONFLICT";
    }
    else
    {
        if(G_Pairs[idx].setup_direction == 1) data.reversalBias = "BUY";
        else if(G_Pairs[idx].setup_direction == -1) data.reversalBias = "SELL";
        else data.reversalBias = "NEUTRAL";
    }
    
    // Score
    data.reversalScore = G_Pairs[idx].reversal_score;
    
    // Progress calculation - V2: 7 possible states to pass through
    // HTF_LOCATION(1), EXHAUSTION(2), LIQUIDITY(3), REVERSAL_CONF(4), STRUCTURE_SHIFT(5), RETEST(6), ENTRY_READY(7)
    bool requireDXY = (G_Pairs[idx].isUSDPair && g_dxy_available && InpUseDXYReference);
    bool requireRetest = (InpRequireRetest && InpEnableRetest);
    
    // Total steps: Location + Exhaustion + Sweep + Displacement + MSS + (Retest) + Final
    data.progressTotal = requireRetest ? 7 : 6;
    data.progressCompleted = 0;
    
    // Map State & Progress
    switch(G_Pairs[idx].state_machine)
    {
        case STATE_NO_SETUP:
            data.state = "NO SETUP";
            data.waitingFor = "HTF REVERSAL ZONE";
            data.progressCompleted = 0;
            break;
            
        case STATE_HTF_LOCATION:
            data.state = "LOCATION";
            data.waitingFor = "EXHAUSTION";
            data.progressCompleted = 1;
            break;
            
        case STATE_EXHAUSTION:
            data.state = "EXHAUSTION";
            data.waitingFor = "LIQUIDITY SWEEP";
            data.progressCompleted = 2;
            break;
            
        case STATE_LIQUIDITY:
            data.state = "SWEEP OK";
            data.waitingFor = "DISPLACEMENT";
            data.progressCompleted = 3;
            break;
            
        case STATE_REVERSAL_CONF:
            data.state = "DISPLACEMENT OK";
            data.waitingFor = "STRUCTURE SHIFT";
            data.progressCompleted = 4;
            break;
            
        case STATE_STRUCTURE_SHIFT:
            data.state = "MSS CONFIRMED";
            if(requireRetest)
            {
                data.waitingFor = "RETEST";
                data.progressCompleted = 5;
            }
            else
            {
                data.waitingFor = "FINAL GATE";
                data.progressCompleted = 5;
            }
            break;
            
        case STATE_RETEST:
            data.state = "RETEST";
            data.waitingFor = "FINAL GATE";
            data.progressCompleted = requireRetest ? 6 : 5;
            break;
            
        case STATE_ENTRY_READY:
            data.state = "ENTRY READY";
            data.waitingFor = "NONE";
            data.progressCompleted = data.progressTotal;
            break;
            
        default:
            data.state = "UNKNOWN";
            data.waitingFor = "UNKNOWN";
            data.progressCompleted = 0;
            break;
    }
    
    // Active chain override
    data.activeChain = (G_Pairs[idx].active_chain_id > 0);
    
    // Block Reason Logic
    data.blockReason = "NONE";
    if(data.activeChain) data.blockReason = "ACTIVE CHAIN";
    else if(G_Pairs[idx].htf_conflict) data.blockReason = "BUY/SELL CONFLICT";
    else if(G_Pairs[idx].state_machine == STATE_NO_SETUP) data.blockReason = "NO HTF REVERSAL ZONE";
    else if(G_Pairs[idx].rev_status == "WAIT_EXHAUSTION") data.blockReason = "NO EXHAUSTION SIGNAL";
    else if(G_Pairs[idx].rev_status == "WAIT_SWEEP") data.blockReason = "NO LIQUIDITY SWEEP";
    else if(G_Pairs[idx].rev_status == "WAIT_DISPLACEMENT") data.blockReason = "NO DISPLACEMENT";
    else if(G_Pairs[idx].rev_status == "WAIT_MSS") data.blockReason = "MSS NOT CONFIRMED";
    else if(G_Pairs[idx].rev_status == "WAIT_RETEST") data.blockReason = "RETEST PENDING";
    else if(G_Pairs[idx].rev_status == "WAIT_DXY") data.blockReason = "DXY NOT READY";
    else if(StringFind(G_Pairs[idx].rev_status, "REJECTED") >= 0) data.blockReason = G_Pairs[idx].rev_status;
    
    // DXY Status mapping
    if(G_Pairs[idx].isUSDPair && g_dxy_available && InpUseDXYReference)
    {
        if(G_Pairs[idx].state_machine >= STATE_ENTRY_READY) data.dxyStatus = "CONFIRMED";
        else if(G_Pairs[idx].rev_status == "WAIT_DXY") data.dxyStatus = "WAITING";
        else if(StringFind(G_Pairs[idx].rev_status, "DXY") >= 0) data.dxyStatus = "CONFLICT";
        else data.dxyStatus = "PENDING";
    }
    else if(G_Pairs[idx].base_name == "EURGBP")
    {
        data.dxyStatus = "N/A (EURGBP)";
    }
    else
    {
         data.dxyStatus = "N/A";
    }
    
    // Readiness percentage
    data.entryReadiness = 0.0;
    if(data.progressTotal > 0)
    {
        data.entryReadiness = ((double)data.progressCompleted / (double)data.progressTotal) * 100.0;
    }
    
    // Master Entry
    if(data.activeChain) data.masterEntry = "BLOCKED";
    else if(G_Pairs[idx].htf_conflict) data.masterEntry = "BLOCKED";
    else if(G_Pairs[idx].state_machine == STATE_ENTRY_READY)
    {
        if(G_Pairs[idx].setup_direction == 1) data.masterEntry = "BUY READY";
        else if(G_Pairs[idx].setup_direction == -1) data.masterEntry = "SELL READY";
        else data.masterEntry = "WAIT";
    }
    else data.masterEntry = "WAIT";
    
    // Sub-components
    data.htfZone = G_Pairs[idx].htf_reversal_zone;
    data.htfDivergence = G_Pairs[idx].htf_div;
    data.htfExhaustion = G_Pairs[idx].htf_exh;
    data.ltfDivergence = G_Pairs[idx].exh_divergence;
    data.ltfMSS = G_Pairs[idx].conf_mss;
    data.ltfExhaustion = G_Pairs[idx].exh_rejection || G_Pairs[idx].exh_failed_cont;
    
    // V2 sub-components
    data.sweep = G_Pairs[idx].conf_sweep;
    data.displacement = G_Pairs[idx].conf_displacement;
    data.rejection = G_Pairs[idx].exh_rejection;
    data.failedCont = G_Pairs[idx].exh_failed_cont;
    data.retest = G_Pairs[idx].conf_retest;
    
    int dir = G_Pairs[idx].setup_direction;
    if(dir != 0 && G_Pairs[idx].ltf_cci_recov == dir) data.cciRecovery = "YES";
    else data.cciRecovery = "NO";
    
    if(G_Pairs[idx].ltf_rf_state == 1) data.rangeFilter = "BULLISH";
    else if(G_Pairs[idx].ltf_rf_state == -1) data.rangeFilter = "BEARISH";
    else data.rangeFilter = "NEUTRAL";
    
    data.entryReady = (G_Pairs[idx].state_machine == STATE_ENTRY_READY);
    
    // Score breakdown string
     data.scoreBreakdown = StringFormat("L%.0f E%.0f S%.0f D%.0f M%.0f Mom%.0f",
         G_Pairs[idx].score_location, G_Pairs[idx].score_exhaustion,
         G_Pairs[idx].score_sweep, G_Pairs[idx].score_displacement,
         G_Pairs[idx].score_mss, G_Pairs[idx].score_momentum);

     // Trend-Following Data
     if(!InpEnableTrendFollowing)
     {
         data.tfState = "TF OFF";
         data.tfDirection = "TF OFF";
         data.tfScore = 0.0;
         data.tfScoreBreakdown = "";
     }
     else
     {
         switch(G_TF[idx].setup_state)
         {
             case TF_STATE_NONE:                 data.tfState = "NONE"; break;
             case TF_STATE_H1_TREND:             data.tfState = "H1 TREND"; break;
             case TF_STATE_M15_PULLBACK:         data.tfState = "M15 PULLBACK"; break;
             case TF_STATE_M5_WAIT_SWEEP:        data.tfState = "WAIT SWEEP"; break;
             case TF_STATE_M5_WAIT_DISPLACEMENT: data.tfState = "WAIT DISP"; break;
             case TF_STATE_M5_WAIT_MSS:          data.tfState = "WAIT MSS"; break;
             case TF_STATE_ENTRY_READY:          data.tfState = "ENTRY READY"; break;
             default:                            data.tfState = "UNKNOWN"; break;
         }
         
         if(G_TF[idx].h1_trend_direction == 1) data.tfDirection = "BUY";
         else if(G_TF[idx].h1_trend_direction == -1) data.tfDirection = "SELL";
         else data.tfDirection = "NONE";
         
         data.tfScore = G_TF[idx].total_score;
         data.tfScoreBreakdown = StringFormat("H1:%.0f M15:%.0f Sw:%.0f Di:%.0f MS:%.0f Co:%.0f Mo:%.0f En:%.0f",
             G_TF[idx].score_h1_trend, G_TF[idx].score_m15_pullback,
             G_TF[idx].score_sweep, G_TF[idx].score_displacement,
             G_TF[idx].score_mss, G_TF[idx].score_event_coherence,
             G_TF[idx].score_momentum, G_TF[idx].score_entry_distance);
     }
     
     // Entry Mode
     if(InpEnableCounterTrend && InpEnableTrendFollowing) data.entryMode = "CT+TF";
     else if(InpEnableCounterTrend) data.entryMode = "CT";
     else if(InpEnableTrendFollowing) data.entryMode = "TF";
     else data.entryMode = "OFF";

     // Populate Unified Display Layer Fields
     PopulateUnifiedDisplayFields(idx, data);

     return true;
}

//+------------------------------------------------------------------+
//| Populate Unified Display Layer Fields (CT vs FT vs DUAL)         |
//+------------------------------------------------------------------+
void PopulateUnifiedDisplayFields(int idx, ReversalDisplayData &data)
{
    if(idx < 0 || idx >= TOTAL_PAIRS) return;

    // 1. Check open positions for this pair
    int count = 0;
    double pnl = 0.0;
    ulong active_magic = 0;
    for(int k = PositionsTotal() - 1; k >= 0; --k)
    {
        ulong t = PositionGetTicket(k);
        if(t > 0 && PositionSelectByTicket(t))
        {
            if(PositionGetString(POSITION_SYMBOL) == G_Pairs[idx].symbol)
            {
                ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
                ulong expected = EA_MAGIC_NUMBER * 1000 + idx;
                if(magic == expected || magic == G_Pairs[idx].active_chain_id || (magic == 0 && G_Pairs[idx].active_chain_id != 0))
                {
                    count++;
                    pnl += ProfitOf(t);
                    if(active_magic == 0) active_magic = magic;
                }
            }
        }
    }
    data.activeChain = (count > 0);

    // 2. Determine Strategy Mode
    if(data.activeChain)
    {
        data.displayMode = G_Pairs[idx].active_chain_strategy;
        if(data.displayMode == "") data.displayMode = "CT";
    }
    else
    {
        if(InpEnableCounterTrend && InpEnableTrendFollowing)
        {
            bool ct_ready = (G_Pairs[idx].state_machine == STATE_ENTRY_READY);
            bool ft_ready = (G_TF[idx].setup_state == TF_STATE_ENTRY_READY);

            if(ct_ready && ft_ready)
            {
                data.displayMode = "DUAL";
            }
            else if(ft_ready)
            {
                data.displayMode = "FT";
            }
            else if(ct_ready)
            {
                data.displayMode = "CT";
            }
            else if(G_TF[idx].total_score > G_Pairs[idx].reversal_score)
            {
                data.displayMode = "FT";
            }
            else if(G_Pairs[idx].reversal_score > G_TF[idx].total_score)
            {
                data.displayMode = "CT";
            }
            else if(G_TF[idx].setup_state > TF_STATE_NONE && G_Pairs[idx].state_machine == STATE_NO_SETUP)
            {
                data.displayMode = "FT";
            }
            else
            {
                data.displayMode = "CT";
            }
        }
        else if(InpEnableTrendFollowing)
        {
            data.displayMode = "FT";
        }
        else if(InpEnableCounterTrend)
        {
            data.displayMode = "CT";
        }
        else
        {
            data.displayMode = "OFF";
        }
    }

    // 3. Direction
    if(data.displayMode == "FT")
    {
        if(G_TF[idx].h1_trend_direction == 1) data.displayDir = "BUY";
        else if(G_TF[idx].h1_trend_direction == -1) data.displayDir = "SELL";
        else data.displayDir = "--";
    }
    else if(data.displayMode == "CT")
    {
        if(G_Pairs[idx].setup_direction == 1) data.displayDir = "BUY";
        else if(G_Pairs[idx].setup_direction == -1) data.displayDir = "SELL";
        else data.displayDir = "--";
    }
    else if(data.displayMode == "DUAL")
    {
        int ct_d = G_Pairs[idx].setup_direction;
        int ft_d = G_TF[idx].h1_trend_direction;
        if(ct_d == ft_d && ct_d != 0) data.displayDir = (ct_d == 1 ? "BUY" : "SELL");
        else if(ct_d != 0 && ft_d != 0) data.displayDir = "CNFL";
        else if(ct_d != 0) data.displayDir = (ct_d == 1 ? "BUY" : "SELL");
        else if(ft_d != 0) data.displayDir = (ft_d == 1 ? "BUY" : "SELL");
        else data.displayDir = "--";
    }
    else
    {
        data.displayDir = "--";
    }

    // 4. Score
    if(data.displayMode == "FT")
    {
        data.displayScore = G_TF[idx].total_score;
    }
    else if(data.displayMode == "CT")
    {
        data.displayScore = G_Pairs[idx].reversal_score;
    }
    else if(data.displayMode == "DUAL")
    {
        data.displayScore = MathMax(G_Pairs[idx].reversal_score, G_TF[idx].total_score);
    }
    else
    {
        data.displayScore = 0.0;
    }
    data.displayScoreStr = StringFormat("%.0f/100", data.displayScore);

    // 5. Block Reason
    data.displayBlockReason = "NONE";
    if(data.activeChain)
    {
        data.displayBlockReason = "ACTIVE CHAIN";
    }
    else if(G_Pairs[idx].htf_conflict)
    {
        data.displayBlockReason = "BUY/SELL CONFLICT";
    }
    else if(G_Pairs[idx].rev_status == "WAIT_DXY" || G_Pairs[idx].rev_status == "DXY_CONFLICT")
    {
        data.displayBlockReason = "DXY CONFLICT";
    }
    else if(G_Pairs[idx].rev_status == "DXY_NOT_READY")
    {
        data.displayBlockReason = "DXY NOT READY";
    }
    else if(StringFind(G_Pairs[idx].rev_status, "REJECT") >= 0)
    {
        data.displayBlockReason = G_Pairs[idx].rev_status;
    }
    else if(data.displayMode == "FT" && G_TF[idx].status == "H1_REGIME_WEAKENED")
    {
        data.displayBlockReason = "H1 WEAKENED";
    }
    else if(data.displayMode == "FT" && StringFind(G_TF[idx].status, "INVALIDATED") >= 0)
    {
        data.displayBlockReason = "INVALIDATED";
    }
    else if(data.displayMode == "DUAL" && G_Pairs[idx].setup_direction != G_TF[idx].h1_trend_direction && G_Pairs[idx].setup_direction != 0 && G_TF[idx].h1_trend_direction != 0)
    {
        data.displayBlockReason = "DIR CONFLICT";
    }

    // 6. State & Next Gate
    if(data.displayMode == "FT")
    {
        switch(G_TF[idx].setup_state)
        {
            case TF_STATE_NONE:
                data.displayState = "NO SETUP";
                data.displayNextGate = "H1 TREND";
                break;
            case TF_STATE_H1_TREND:
                data.displayState = "H1 TREND";
                data.displayNextGate = "M15 PULLBACK";
                break;
            case TF_STATE_M15_PULLBACK:
                data.displayState = "PULLBACK";
                data.displayNextGate = "LIQUIDITY";
                break;
            case TF_STATE_M5_WAIT_SWEEP:
                data.displayState = "WAIT SWEEP";
                data.displayNextGate = "LIQUIDITY";
                break;
            case TF_STATE_M5_WAIT_DISPLACEMENT:
                data.displayState = "WAIT DISP";
                data.displayNextGate = "DISPLACEMENT";
                break;
            case TF_STATE_M5_WAIT_MSS:
                data.displayState = "WAIT MSS";
                data.displayNextGate = "STRUCT SHIFT";
                break;
            case TF_STATE_ENTRY_READY:
                data.displayState = "READY";
                data.displayNextGate = "ENTRY";
                break;
            default:
                data.displayState = "UNKNOWN";
                data.displayNextGate = "--";
                break;
        }
    }
    else // CT or DUAL
    {
        switch(G_Pairs[idx].state_machine)
        {
            case STATE_NO_SETUP:
                data.displayState = "NO SETUP";
                data.displayNextGate = "HTF LOCATION";
                break;
            case STATE_HTF_LOCATION:
                data.displayState = "LOCATION";
                data.displayNextGate = "EXHAUSTION";
                break;
            case STATE_EXHAUSTION:
                data.displayState = "EXHAUSTION";
                data.displayNextGate = "LIQUIDITY";
                break;
            case STATE_LIQUIDITY:
                data.displayState = "LIQUIDITY";
                data.displayNextGate = "DISPLACEMENT";
                break;
            case STATE_REVERSAL_CONF:
                data.displayState = "REVERSAL CONF";
                data.displayNextGate = "STRUCT SHIFT";
                break;
            case STATE_STRUCTURE_SHIFT:
                data.displayState = "MSS CONF";
                data.displayNextGate = (InpRequireRetest && InpEnableRetest) ? "RETEST" : "ENTRY";
                break;
            case STATE_RETEST:
                data.displayState = "RETEST";
                data.displayNextGate = "ENTRY";
                break;
            case STATE_ENTRY_READY:
                data.displayState = "READY";
                data.displayNextGate = "ENTRY";
                break;
            default:
                data.displayState = "UNKNOWN";
                data.displayNextGate = "--";
                break;
        }
    }

    // Override State if Blocked
    if(data.displayScore >= 100.0 && data.displayBlockReason != "NONE" && !data.activeChain)
    {
        data.displayState = "BLOCKED";
        data.displayNextGate = data.displayBlockReason;
    }

    // 7. Readiness
    if(data.displayState == "BLOCKED")
    {
        data.displayReadinessStr = "BLOCKED";
    }
    else if(data.displayState == "READY")
    {
        data.displayReadinessStr = "100% (READY)";
    }
    else if(data.displayMode == "FT")
    {
        double pct = ((double)G_TF[idx].setup_state / 6.0) * 100.0;
        data.displayReadinessStr = StringFormat("%.0f%%", pct);
    }
    else
    {
        data.displayReadinessStr = StringFormat("%d/%d (%.0f%%)", data.progressCompleted, data.progressTotal, data.entryReadiness);
    }

    // 8. Breakdown string
    if(data.displayMode == "FT")
    {
        data.displayBreakdown = data.tfScoreBreakdown;
    }
    else
    {
        data.displayBreakdown = data.scoreBreakdown;
    }
}
