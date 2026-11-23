import os, shutil, sys, re

CAND = ["Experts/RTAS_Gold_Mind_Experiment_v2.mq5",
        "RTAS_Gold_Mind_Experiment_v2.mq5",
        "MQL5/Experts/RTAS_Gold_Mind_Experiment_v2.mq5"]
F = next((p for p in CAND if os.path.exists(p)), None)
if not F:
    print("❌ File nahi mili. In mein se koi ek path par honi chahiye:")
    for p in CAND: print("   ", p)
    print("\nCurrent folder:", os.getcwd())
    for root,_,fs in os.walk('.'):
        for f in fs:
            if 'Experiment_v2' in f and f.endswith('.mq5'):
                print("   MILI:", os.path.join(root,f))
    input(); sys.exit(1)

shutil.copy(F, F+".bak_phase1")
L = open(F, encoding="utf-8").read().splitlines()
print(f"✅ File: {F}\n📦 Backup: {F}.bak_phase1\n📄 {len(L)} lines\n")
log=[]

def find(sub, start=0):
    for i in range(start,len(L)):
        if sub in L[i]: return i
    return -1

def setline(sub, new, tag):
    i=find(sub)
    if i<0: print("  ⚠️ miss:",tag); return False
    L[i]=new; log.append(tag); print("  ✅",tag); return True

def ins_after(sub, block, tag):
    i=find(sub)
    if i<0: print("  ⚠️ miss:",tag); return False
    L[i+1:i+1]=block; log.append(tag); print("  ✅",tag); return True

def ins_before(sub, block, tag):
    i=find(sub)
    if i<0: print("  ⚠️ miss:",tag); return False
    L[i:i]=block; log.append(tag); print("  ✅",tag); return True

def repl_func(sig, new, tag):
    i=find(sig)
    if i<0: print("  ⚠️ miss:",tag); return False
    d=0; started=False; e=i
    for j in range(i,len(L)):
        d+=L[j].count("{")-L[j].count("}")
        if "{" in L[j]: started=True
        if started and d==0: e=j; break
    L[i:e+1]=new.splitlines(); log.append(tag); print("  ✅",tag); return True

def repl_block(startsub, block, tag):
    i=find(startsub)
    if i<0: print("  ⚠️ miss:",tag); return False
    e=i
    while "};" not in L[e]: e+=1
    L[i:e+1]=block; log.append(tag); print("  ✅",tag); return True

# ---------- 1. Version + description + panel height ----------
print("[1] Identity")
for i,l in enumerate(L):
    if l.strip().startswith("#property version"):
        L[i]='#property version   "2.300"'; log.append("version 2.300"); break
for i,l in enumerate(L):
    if 'SL 300 pip | TP 500 pip (1:2)' in l:
        L[i]='#property description "Phase1 Supervisor | adaptive SL 200-400 pip | TP = SL x 1.6667 | 1% equity."'; break
for i,l in enumerate(L):
    if '+50 pip: BE | +130 pip: trail' in l:
        L[i]='#property description "+50 BE | +130 trail 50 | structure shift 40 pip | early exit on flip."'; break
setline("#define TGM_PANEL_HEIGHT_FULL","#define TGM_PANEL_HEIGHT_FULL       320","panel height 320")

# ---------- 2. Per-level SL fallback fix ----------
print("\n[2] SL fallback fix (100 -> 300)")
setline("input double RESEARCH_INV_TP_L1_PIPS","input double RESEARCH_INV_TP_L1_PIPS  = 300.0; // L1 SL pips (fallback)","L1 300")
setline("input double RESEARCH_INV_TP_L2_PIPS","input double RESEARCH_INV_TP_L2_PIPS  = 300.0; // L2 SL pips (fallback)","L2 300")
setline("input double RESEARCH_INV_TP_L3_PIPS","input double RESEARCH_INV_TP_L3_PIPS  = 300.0; // L3 SL pips (fallback)","L3 300")

# ---------- 3. Supervisor inputs ----------
print("\n[3] Supervisor inputs")
SUP_IN = [
'input group "--- PHASE 1: Deterministic Supervisor ---"',
'input bool   InpSupEnable        = true;   // Supervisor ON/OFF',
'input bool   InpSupAdaptiveSLTP  = true;   // SL/TP from H4 ATR (backtestable)',
'input double InpSupATR_SL_Mult   = 1.2;    // SL = ATR x this',
'input double InpSupSLMinPips     = 200.0;  // SL lower bound (pip)',
'input double InpSupSLMaxPips     = 400.0;  // SL upper bound (pip)',
'input double InpSupRR           = 1.6667; // TP = SL x this',
'input bool   InpSupShiftPending  = true;   // Structure-based level shift',
'input double InpSupMaxShiftPips  = 40.0;   // Max shift per level (pip)',
'input bool   InpSupEarlyExit     = true;   // Close profit if structure flips',
'input double InpSupEarlyMinPips  = 30.0;   // Early exit only above this profit',
'input int    InpSupADXPeriod     = 14;     // ADX period (H4)',
'input double InpSupADXStrong     = 28.0;   // ADX strong threshold',
'input int    InpSupEmaFast       = 21;     // EMA fast (H4)',
'input int    InpSupEmaSlow       = 50;     // EMA slow (H4)',
'input int    InpSupMaxActionsH4  = 3;      // Max supervisor actions per H4',
'input int    InpSupCooldownSec   = 300;    // Cooldown between actions (sec)',
'input bool   InpSupLog           = true;   // Log supervisor decisions',
'',
]
ins_before('input group "--- Direction Control ---"', SUP_IN, "sup inputs")

# ---------- 4. Supervisor engine ----------
print("\n[4] Supervisor engine")
ENGINE = r'''
//==================== PHASE 1: DETERMINISTIC SUPERVISOR ====================
int      g_supAdxHandle  = INVALID_HANDLE;
int      g_supEmaFastH   = INVALID_HANDLE;
int      g_supEmaSlowH   = INVALID_HANDLE;
int      g_supBias       = 0;
double   g_supStrength   = 0.0;
double   g_supSlPips     = 300.0;
double   g_supAtrPips    = 0.0;
datetime g_supCalcBar    = 0;
datetime g_supLastAction = 0;
int      g_supActionsH4  = 0;
datetime g_supActionBar  = 0;
string   g_supStructTag  = "INIT";

double SupClamp(const double v,const double lo,const double hi)
{ return (v<lo?lo:(v>hi?hi:v)); }

bool SupBlocked()
{
   if(!InpSupEnable) return true;
   if(IsEmergencyLockThisH4()) return true;
   if(g_forceFlattenActive) return true;
   if(g_accountProtectionActive) return true;
   return false;
}

bool SupBudgetAvailable()
{
   const datetime h4=GetCurrentH4BarOpenTime();
   if(g_supActionBar!=h4){ g_supActionBar=h4; g_supActionsH4=0; }
   if(g_supActionsH4>=MathMax(1,InpSupMaxActionsH4)) return false;
   if(g_supLastAction>0 && (TimeCurrent()-g_supLastAction)<InpSupCooldownSec) return false;
   return true;
}

void SupConsumeBudget(const string what)
{
   g_supActionsH4++;
   g_supLastAction=TimeCurrent();
   if(InpSupLog)
      PrintFormat("TGM [SUP ACT]: %s | bias=%d str=%.2f | actions=%d/%d",
                  what,g_supBias,g_supStrength,g_supActionsH4,InpSupMaxActionsH4);
}

void SupRecalc()
{
   const datetime h4=GetCurrentH4BarOpenTime();
   if(h4<=0 || g_supCalcBar==h4) return;
   g_supCalcBar=h4;
   g_supBias=0; g_supStrength=0.0; g_supStructTag="RANGE";
   const double pip=Phase17_GetPipSize();
   if(pip<=0.0) return;

   double atr=0.0;
   if(GetLiveATR(atr) && atr>0.0)
   {
      g_supAtrPips=atr/pip;
      g_supSlPips=SupClamp(g_supAtrPips*InpSupATR_SL_Mult,InpSupSLMinPips,InpSupSLMaxPips);
   }
   else
      g_supSlPips=SupClamp(RESEARCH_FIX_SL_PIPS,InpSupSLMinPips,InpSupSLMaxPips);
   if(!InpSupAdaptiveSLTP)
      g_supSlPips=SupClamp(RESEARCH_FIX_SL_PIPS,InpSupSLMinPips,InpSupSLMaxPips);

   if(g_supAdxHandle==INVALID_HANDLE||g_supEmaFastH==INVALID_HANDLE||g_supEmaSlowH==INVALID_HANDLE) return;
   double ef[],es[],ax[],dp[],dm[];
   ArraySetAsSeries(ef,true); ArraySetAsSeries(es,true);
   ArraySetAsSeries(ax,true); ArraySetAsSeries(dp,true); ArraySetAsSeries(dm,true);
   if(CopyBuffer(g_supEmaFastH,0,1,1,ef)!=1) return;
   if(CopyBuffer(g_supEmaSlowH,0,1,1,es)!=1) return;
   if(CopyBuffer(g_supAdxHandle,0,1,1,ax)!=1) return;
   if(CopyBuffer(g_supAdxHandle,1,1,1,dp)!=1) return;
   if(CopyBuffer(g_supAdxHandle,2,1,1,dm)!=1) return;

   const double h1=iHigh(_Symbol,PERIOD_H4,1), l1=iLow(_Symbol,PERIOD_H4,1);
   const double c1=iClose(_Symbol,PERIOD_H4,1);
   const double h2=iHigh(_Symbol,PERIOD_H4,2), l2=iLow(_Symbol,PERIOD_H4,2);
   if(h1<=0||l1<=0||c1<=0||h2<=0||l2<=0) return;

   int emaB=0; if(ef[0]>es[0]) emaB=1; else if(ef[0]<es[0]) emaB=-1;
   int diB=0;  if(dp[0]>dm[0]) diB=1;  else if(dm[0]>dp[0]) diB=-1;
   int bosB=0; if(c1>h2) bosB=1;       else if(c1<l2) bosB=-1;
   const bool strong=(ax[0]>=InpSupADXStrong);
   const int score=emaB+diB+bosB;

   if(strong && score>=2)       { g_supBias=1;  g_supStructTag="TREND_UP"; }
   else if(strong && score<=-2) { g_supBias=-1; g_supStructTag="TREND_DOWN"; }
   else if(score>=2)            { g_supBias=1;  g_supStructTag="LEAN_UP"; }
   else if(score<=-2)           { g_supBias=-1; g_supStructTag="LEAN_DOWN"; }
   else                         { g_supBias=0;  g_supStructTag="RANGE"; }

   double s=MathMin(1.0,MathAbs((double)score)/3.0);
   if(strong) s=MathMin(1.0,s+0.25);
   g_supStrength=s;

   if(InpSupLog)
      PrintFormat("TGM [SUP]: %s | %s bias=%d str=%.2f | ATR=%.0fpip -> SL=%.0fpip TP=%.0fpip | EMA=%d DI=%d BOS=%d ADX=%.1f",
                  TimeToString(h4,TIME_DATE|TIME_MINUTES),g_supStructTag,g_supBias,g_supStrength,
                  g_supAtrPips,g_supSlPips,g_supSlPips*InpSupRR,emaB,diB,bosB,ax[0]);
}

double SupShiftEntry(const double rawEntry,const bool isBuyLevel)
{
   if(!InpSupEnable||!InpSupShiftPending) return rawEntry;
   if(g_supBias==0||g_supStrength<=0.0) return rawEntry;
   const double pip=Phase17_GetPipSize();
   if(pip<=0.0) return rawEntry;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double shift=InpSupMaxShiftPips*pip*g_supStrength;
   const double adj=(g_supBias>0)?+shift:-shift;
   const double out=NormalizeDouble(rawEntry+adj,digits);
   const double stops=GetSymbolStopsPrice();
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(isBuyLevel  && out>ask-stops-pip) return rawEntry;
   if(!isBuyLevel && out<bid+stops+pip) return rawEntry;
   return out;
}

void SupEarlyExit()
{
   if(SupBlocked()||!InpSupEarlyExit) return;
   if(g_supBias==0||g_supStrength<0.6) return;
   const double pip=Phase17_GetPipSize();
   if(pip<=0.0) return;
   CPositionInfo pos;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol||pos.Magic()!=(ulong)EXPERT_MAGIC) continue;
      if(!IsOurBotGridParent(pos.Ticket())) continue;
      const ulong ticket=pos.Ticket();
      const bool isBuy=(pos.PositionType()==POSITION_TYPE_BUY);
      const double entry=pos.PriceOpen();
      const double cur=isBuy?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      const double pips=(isBuy?(cur-entry):(entry-cur))/pip;
      if(pips<InpSupEarlyMinPips) continue;
      const bool against=(isBuy&&g_supBias<0)||(!isBuy&&g_supBias>0);
      if(!against) continue;
      const string k=StringFormat("TGM_SupExit_%I64u_%s_%I64u",
         (ulong)AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,ticket);
      if(GlobalVariableCheck(k)) continue;
      if(!SupBudgetAvailable()) return;
      if(ExecuteTradeOp("SupEarlyExit",g_trade.PositionClose(ticket),
            StringFormat("ticket=%I64u pips=%.1f struct=%s",ticket,pips,g_supStructTag)))
      {
         GlobalVariableSet(k,1.0);
         SupConsumeBudget(StringFormat("EARLY_EXIT #%I64u locked +%.0fpip (%s)",ticket,pips,g_supStructTag));
      }
   }
}

void SupManagePendings()
{
   if(SupBlocked()||!InpSupShiftPending) return;
   if(g_supBias==0) return;
   static datetime lastPass=0;
   if(lastPass>0 && (TimeCurrent()-lastPass)<300) return;
   lastPass=TimeCurrent();
   const double pip=Phase17_GetPipSize();
   if(pip<=0.0) return;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double h1,l1,pv,b1,b2,b3,s1,s2,s3;
   if(!CalculateH4GridLevels(h1,l1,pv,b1,b2,b3,s1,s2,s3)) return;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      const ulong t=OrderGetTicket(i);
      if(t==0||!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC)!=EXPERT_MAGIC) continue;
      const ENUM_ORDER_TYPE ot=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot!=ORDER_TYPE_BUY_LIMIT&&ot!=ORDER_TYPE_SELL_LIMIT) continue;
      const string lvl=ResolveGridLevelNameFromComment(OrderGetString(ORDER_COMMENT));
      if(lvl=="") continue;
      const bool isBuyLevel=(StringFind(lvl,"GM_BL")==0);
      double raw=0.0;
      if(lvl=="GM_BL1") raw=b1; else if(lvl=="GM_BL2") raw=b2; else if(lvl=="GM_BL3") raw=b3;
      else if(lvl=="GM_SL1") raw=s1; else if(lvl=="GM_SL2") raw=s2; else if(lvl=="GM_SL3") raw=s3;
      if(raw<=0.0) continue;
      const double want=SupShiftEntry(raw,isBuyLevel);
      const double cur=OrderGetDouble(ORDER_PRICE_OPEN);
      if(MathAbs(want-cur)<pip*5.0) continue;
      const int li=GridLevelCommentIndex(lvl)%3;
      double sl=0.0,tp=0.0,dist=0.0;
      if(!ResearchInvertedSlTpFor(isBuyLevel,want,li,sl,tp,dist)) continue;
      if(!SupBudgetAvailable()) return;
      if(ExecuteTradeOp("SupShift",g_trade.OrderModify(t,want,sl,tp,ORDER_TIME_GTC,0),
            StringFormat("ticket=%I64u %s -> %.*f",t,lvl,digits,want)))
         SupConsumeBudget(StringFormat("SHIFT %s %.*f -> %.*f",lvl,digits,cur,digits,want));
   }
}

void SupervisorOnTick()
{
   if(!InpSupEnable) return;
   SupRecalc();
   if(SupBlocked()) return;
   SupEarlyExit();
   SupManagePendings();
}

string SupPanelText()
{
   if(!InpSupEnable) return "OFF";
   return StringFormat("%s %d/%d",g_supStructTag,g_supActionsH4,InpSupMaxActionsH4);
}
//==========================================================================
'''
ins_before("int OnInit()", ENGINE.splitlines(), "sup engine")

# ---------- 5. SL/TP function replace ----------
print("\n[5] SL/TP function")
NEW_SLTP = r'''bool ResearchInvertedSlTpFor(const bool placingBuy, const double entry,
                             const int levelIndex,
                             double &slOut, double &tpOut, double &lotDistOut)
{
   if(entry <= 0.0) return false;
   const double pip = Phase17_GetPipSize();
   if(pip <= 0.0) return false;
   double slPips = RESEARCH_FIX_SL_PIPS;
   double rr     = (RESEARCH_RR_TP_MULT > 0.0) ? RESEARCH_RR_TP_MULT : 1.6667;
   if(InpSupEnable && InpSupAdaptiveSLTP && g_supSlPips > 0.0)
   {
      slPips = g_supSlPips;
      rr     = InpSupRR;
   }
   else
   {
      const double perLevel[3] = {RESEARCH_INV_TP_L1_PIPS,
                                  RESEARCH_INV_TP_L2_PIPS,
                                  RESEARCH_INV_TP_L3_PIPS};
      if(levelIndex >= 0 && levelIndex <= 2 && perLevel[levelIndex] > 0.0)
         slPips = perLevel[levelIndex];
   }
   if(slPips <= 0.0) return false;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double slDist = slPips * pip;
   const double tpDist = slPips * rr * pip;
   slOut      = NormalizeDouble(placingBuy ? (entry - slDist) : (entry + slDist), digits);
   tpOut      = NormalizeDouble(placingBuy ? (entry + tpDist) : (entry - tpDist), digits);
   lotDistOut = slDist;
   return true;
}'''
repl_func("bool ResearchInvertedSlTpFor(const bool placingBuy", NEW_SLTP, "SL/TP adaptive")

# ---------- 6. OnInit handles ----------
print("\n[6] OnInit / OnDeinit")
ins_after("Phase17_OnInit();", [
'   // PHASE 1: supervisor indicator handles',
'   if(InpSupEnable)',
'   {',
'      g_supAdxHandle = iADX(_Symbol, PERIOD_H4, InpSupADXPeriod);',
'      g_supEmaFastH  = iMA(_Symbol, PERIOD_H4, InpSupEmaFast, 0, MODE_EMA, PRICE_CLOSE);',
'      g_supEmaSlowH  = iMA(_Symbol, PERIOD_H4, InpSupEmaSlow, 0, MODE_EMA, PRICE_CLOSE);',
'      if(g_supAdxHandle==INVALID_HANDLE||g_supEmaFastH==INVALID_HANDLE||g_supEmaSlowH==INVALID_HANDLE)',
'         Print("TGM [SUP]: indicator handle FAILED - supervisor idle.");',
'      else',
'         PrintFormat("TGM [SUP]: Phase1 ON | SL=ATR x%.2f clamp %.0f-%.0f pip | RR=%.4f | shift<=%.0f pip | earlyExit>=%.0f pip | max %d act/H4",',
'                     InpSupATR_SL_Mult,InpSupSLMinPips,InpSupSLMaxPips,InpSupRR,',
'                     InpSupMaxShiftPips,InpSupEarlyMinPips,InpSupMaxActionsH4);',
'      SupRecalc();',
'   }',
], "OnInit sup init")

ins_after("void OnDeinit(const int reason)\n{", [], "noop") if False else None
i=find("EventKillTimer();")
if i>=0:
    L[i+1:i+1]=[
'   if(g_supAdxHandle!=INVALID_HANDLE){ IndicatorRelease(g_supAdxHandle); g_supAdxHandle=INVALID_HANDLE; }',
'   if(g_supEmaFastH!=INVALID_HANDLE){ IndicatorRelease(g_supEmaFastH);  g_supEmaFastH=INVALID_HANDLE; }',
'   if(g_supEmaSlowH!=INVALID_HANDLE){ IndicatorRelease(g_supEmaSlowH);  g_supEmaSlowH=INVALID_HANDLE; }',
    ]; log.append("OnDeinit release"); print("  ✅ OnDeinit release")

# ---------- 7. OnTick call ----------
print("\n[7] OnTick hook")
ins_after("ManageProfitRunners();", ["      SupervisorOnTick();"], "OnTick sup call")

# ---------- 8. Placement: recalc + shift ----------
print("\n[8] Placement hooks")
ins_after("g_gridStrategyBusy = true;", ["   if(InpSupEnable) SupRecalc();"], "recalc before place")
ins_after("double buyEntries[3] = {buy1, buy2, buy3};",
          ["   if(InpSupEnable) for(int k=0;k<3;k++) buyEntries[k]=SupShiftEntry(buyEntries[k],true);"],
          "buy shift")
ins_after("double sellEntries[3] = {sell1, sell2, sell3};",
          ["   if(InpSupEnable) for(int k=0;k<3;k++) sellEntries[k]=SupShiftEntry(sellEntries[k],false);"],
          "sell shift")

# ---------- 9. Dashboard ----------
print("\n[9] Dashboard")
ins_after('CreateUILabel("LblDirection", "Trade Direction"',
          ['   CreateUILabel("LblSup", "Supervisor", labelColor, 9, "Arial");'], "LblSup")
ins_after('CreateUILabel("ValDirection", "---"',
          ['   CreateUILabel("ValSup", "---", C\'150,220,255\', 9, "Arial Bold");'], "ValSup")
ins_after('SetUILabelText("ValDirection", dirStr);',
          ['   SetUILabelText("ValSup", SupPanelText());',
           '   SetUILabelColor("ValSup", (g_supBias>0)?C\'120,230,160\':((g_supBias<0)?C\'255,140,140\':C\'200,200,200\'));'],
          "ValSup update")

repl_block("string internalLabels[]", [
'string internalLabels[] = {"Sep0",',
'"LblAcc", "ValAcc", "LblRisk", "ValRisk", "LblPos", "ValPos",',
'"LblDirection", "ValDirection",',
'"LblSup", "ValSup",',
'"LblTrail", "ValTrail",',
'"Sep1", "LblLic", "ValLic",',
'"Sep2",',
'"LblDaily", "ValDaily", "LblSessionOpen", "ValSessionOpen",',
'"LblTotalTrades", "ValTotalTrades",',
'"LblWinLoss", "ValWinLoss"};'], "labels 25")

repl_block("int internalOffsetsY[]", [
'int internalOffsetsY[] = {52,',
'60, 60, 82, 82, 104, 104,',
'126, 126,',
'148, 148,',
'170, 170,',
'192, 200, 200,',
'222,',
'230, 230, 252, 252,',
'274, 274,',
'296, 296};'], "Y 25")

repl_block("int internalOffsetsX[]", [
'int internalOffsetsX[] = {12,',
'15, 140, 15, 140, 15, 140,',
'15, 140,',
'15, 140,',
'15, 140,',
'12, 15, 140,',
'12,',
'15, 140, 15, 140,',
'15, 140,',
'15, 140};'], "X 25")

setline("const int height = g_uiMinimized ? TGM_PANEL_HEIGHT_MIN",
        "   const int height = g_uiMinimized ? TGM_PANEL_HEIGHT_MIN : TGM_PANEL_HEIGHT_FULL;",
        "panel height dynamic")

# ---------- VALIDATE ----------
print("\n"+"="*58)
def cnt(sub):
    i=find(sub); t=""; e=i
    while "};" not in L[e]: t+=L[e]; e+=1
    t+=L[e]
    inner=t[t.index("{")+1:t.rindex("}")+1]
    return len([x for x in inner.split(",") if x.strip()])
nl,ny,nx = cnt("string internalLabels[]"),cnt("int internalOffsetsY[]"),cnt("int internalOffsetsX[]")
print(f"🔎 Arrays: labels={nl} Y={ny} X={nx}")
code="\n".join(L)
clean=re.sub(r'"(?:[^"\\]|\\.)*"','""',code)
clean=re.sub(r'//.*','',clean)
depth=clean.count("{")-clean.count("}")
print(f"🔎 Brace balance: {depth}")
if not (nl==ny==nx==25) or depth!=0:
    print("❌ Validation FAIL — restore"); shutil.copy(F+".bak_phase1",F); input(); sys.exit(1)

open(F,"w",encoding="utf-8").write(code+"\n")
print("\n🎉 PHASE 1 BUILD COMPLETE")
print(f"   {len(log)} changes applied")
for c in log: print("   ✅",c)
print("\n   MetaEditor: File > Reload → F7")
input("Press Enter...")