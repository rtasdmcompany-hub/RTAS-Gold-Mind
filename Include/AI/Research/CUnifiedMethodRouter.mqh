//+------------------------------------------------------------------+
//|                                      CUnifiedMethodRouter.mqh    |
//|  R445/R448 UNIFIED METHOD ROUTER  (H4 RANGE ONLY -> 2 methods)   |
//|    range <= SmallRange : BOTH sides LIMIT  (mean-reversion)      |
//|    range >= LargeRange : BOTH sides STOP   (breakout)            |
//|    in between          : GAP -> NO TRADE (unless gap enabled)    |
//|  Direction / ADX / SMC are LABELS ONLY - they never gate trades. |
//|  RTAS Group of Companies | RTAS Digital Marketing Company        |
//+------------------------------------------------------------------+
#ifndef GM_CUNIFIED_METHOD_ROUTER_MQH
#define GM_CUNIFIED_METHOD_ROUTER_MQH

enum ENUM_TGM_ROUTER_STATUS
  {
   TGM_ROUTER_WAIT               = 0,
   TGM_ROUTER_ACTIVE             = 1,
   TGM_ROUTER_NO_TRADE_GAP       = 2,
   TGM_ROUTER_WAIT_WEAK_PULLBACK = 3
  };

struct STgmRouterDecision
  {
   ENUM_TGM_ROUTER_STATUS status;
   bool                   armBuyLoop;
   bool                   armSellLoop;
   bool                   breakoutPlacement;
   string                 methodLabel;
   string                 marketModeLabel;
   string                 trendState;
   double                 rangePips;
   datetime               h4Open;
  };

class CUnifiedMethodRouter
  {
private:
   string             m_symbol;
   int                m_emaFast,m_emaSlow,m_adxPeriod,m_atrPeriod;
   int                m_hEmaFast,m_hEmaSlow,m_hAdx,m_hAtr,m_hD1Fast,m_hD1Slow;
   bool               m_useD1,m_useH4,m_gapEnabled,m_useSMC,m_useBOS,m_useVWAP;
   double             m_adxMin,m_adxStrong,m_largeRange,m_smallRange;
   int                m_alignedMin,m_pullbackMin;
   bool               m_ready,m_hasLock;
   datetime           m_lockBar;
   STgmRouterDecision m_last;
   int                m_cycles,m_limitCycles,m_stopCycles,m_gapSkips;

   double BufVal(const int handle,const int buffer,const int shift)
     {
      if(handle==INVALID_HANDLE) return 0.0;
      double tmp[];
      if(CopyBuffer(handle,buffer,shift,1,tmp)!=1) return 0.0;
      return tmp[0];
     }

   void ResetDecision(STgmRouterDecision &d)
     {
      d.status            = TGM_ROUTER_WAIT;
      d.armBuyLoop        = false;
      d.armSellLoop       = false;
      d.breakoutPlacement = false;
      d.methodLabel       = "";
      d.marketModeLabel   = "";
      d.trendState        = "";
      d.rangePips         = 0.0;
      d.h4Open            = 0;
     }

   //--- LABELS ONLY: never blocks a trade (R437+)
   void BuildLabels(STgmRouterDecision &d)
     {
      double ef=BufVal(m_hEmaFast,0,1);
      double es=BufVal(m_hEmaSlow,0,1);
      if(ef>0.0 && es>0.0)
         d.trendState=(ef>es ? "BULL" : (ef<es ? "BEAR" : "FLAT"));
      else
         d.trendState="N/A";

      if(m_useD1)
        {
         double df=BufVal(m_hD1Fast,0,1);
         double ds=BufVal(m_hD1Slow,0,1);
         if(df>0.0 && ds>0.0)
            d.trendState=d.trendState+(df>ds ? " D1+" : " D1-");
        }

      double adx=BufVal(m_hAdx,0,1);
      if(adx>=m_adxStrong)   d.marketModeLabel="STRONG TREND";
      else if(adx>=m_adxMin) d.marketModeLabel="TREND";
      else                   d.marketModeLabel="RANGE";
     }

public:
   CUnifiedMethodRouter()
     {
      m_symbol="";
      m_emaFast=50; m_emaSlow=200; m_adxPeriod=14; m_atrPeriod=14;
      m_hEmaFast=INVALID_HANDLE; m_hEmaSlow=INVALID_HANDLE;
      m_hAdx=INVALID_HANDLE; m_hAtr=INVALID_HANDLE;
      m_hD1Fast=INVALID_HANDLE; m_hD1Slow=INVALID_HANDLE;
      m_useD1=false; m_useH4=true; m_gapEnabled=false;
      m_useSMC=true; m_useBOS=true; m_useVWAP=false;
      m_adxMin=20.0; m_adxStrong=25.0; m_largeRange=300.0; m_smallRange=250.0;
      m_alignedMin=70; m_pullbackMin=80;
      m_ready=false; m_hasLock=false; m_lockBar=0;
      m_cycles=0; m_limitCycles=0; m_stopCycles=0; m_gapSkips=0;
      ResetDecision(m_last);
     }
  ~CUnifiedMethodRouter() { Shutdown(); }

   bool Init(const string symbol,const int emaFast,const int emaSlow,
             const int adxPeriod,const int atrPeriod)
     {
      m_symbol    = (symbol=="" ? _Symbol : symbol);
      m_emaFast   = (emaFast>0   ? emaFast   : 50);
      m_emaSlow   = (emaSlow>0   ? emaSlow   : 200);
      m_adxPeriod = (adxPeriod>0 ? adxPeriod : 14);
      m_atrPeriod = (atrPeriod>0 ? atrPeriod : 14);

      m_hEmaFast=iMA(m_symbol,PERIOD_H4,m_emaFast,0,MODE_EMA,PRICE_CLOSE);
      m_hEmaSlow=iMA(m_symbol,PERIOD_H4,m_emaSlow,0,MODE_EMA,PRICE_CLOSE);
      m_hAdx    =iADX(m_symbol,PERIOD_H4,m_adxPeriod);
      m_hAtr    =iATR(m_symbol,PERIOD_H4,m_atrPeriod);

      m_ready=(m_hEmaFast!=INVALID_HANDLE && m_hEmaSlow!=INVALID_HANDLE &&
               m_hAdx!=INVALID_HANDLE && m_hAtr!=INVALID_HANDLE);
      if(!m_ready)
         Print("TGM [ROUTER]: indicator init failed - labels unavailable.");
      return m_ready;
     }

   void Configure(const bool useD1,const bool useH4,const double adxMin,const double adxStrong,
                  const int alignedMin,const int pullbackMin,
                  const double largeRange,const double smallRange,
                  const bool gapEnabled,const bool useSMC,const bool useBOS,const bool useVWAP)
     {
      m_useD1=useD1; m_useH4=useH4;
      m_adxMin=adxMin; m_adxStrong=adxStrong;
      m_alignedMin=alignedMin; m_pullbackMin=pullbackMin;
      m_largeRange=largeRange; m_smallRange=smallRange;
      m_gapEnabled=gapEnabled; m_useSMC=useSMC; m_useBOS=useBOS; m_useVWAP=useVWAP;

      if(m_useD1 && m_hD1Fast==INVALID_HANDLE)
        {
         m_hD1Fast=iMA(m_symbol,PERIOD_D1,m_emaFast,0,MODE_EMA,PRICE_CLOSE);
         m_hD1Slow=iMA(m_symbol,PERIOD_D1,m_emaSlow,0,MODE_EMA,PRICE_CLOSE);
        }
     }

   bool IsReady() const { return m_ready; }
   bool HasLock() const { return m_hasLock; }

   //--- ONE decision per H4 cycle. Range only. Direction never gates.
   bool EvaluateForH4Cycle(const datetime h4Open,const double rangePips,STgmRouterDecision &d)
     {
      ResetDecision(d);
      d.h4Open=h4Open;
      d.rangePips=rangePips;

      if(m_hasLock && h4Open>0 && m_lockBar==h4Open)
        {
         d=m_last;
         return (d.status==TGM_ROUTER_ACTIVE && (d.armBuyLoop || d.armSellLoop));
        }

      BuildLabels(d);
      m_cycles++;

      if(rangePips<=m_smallRange)
        {
         d.status=TGM_ROUTER_ACTIVE;
         d.armBuyLoop=true; d.armSellLoop=true;
         d.breakoutPlacement=false;
         d.methodLabel="RANGE BOTH LIMIT";
         m_limitCycles++;
        }
      else if(rangePips>=m_largeRange)
        {
         d.status=TGM_ROUTER_ACTIVE;
         d.armBuyLoop=true; d.armSellLoop=true;
         d.breakoutPlacement=true;
         d.methodLabel="RANGE BOTH STOP";
         m_stopCycles++;
        }
      else
        {
         m_gapSkips++;
         if(m_gapEnabled)
           {
            d.status=TGM_ROUTER_ACTIVE;
            d.armBuyLoop=true; d.armSellLoop=true;
            d.breakoutPlacement=false;
            d.methodLabel="GAP BOTH LIMIT";
           }
         else
           {
            d.status=TGM_ROUTER_NO_TRADE_GAP;
            d.methodLabel="";
           }
        }

      m_last=d;
      m_hasLock=true;
      m_lockBar=h4Open;

      const bool ok=(d.status==TGM_ROUTER_ACTIVE && (d.armBuyLoop || d.armSellLoop));
      if(ok)
         PrintFormat("TGM [R448 ROUTER]: H4 %s range=%.0fpip -> %s | BUY+SELL | trend=%s mode=%s (labels only)",
                     TimeToString(h4Open,TIME_DATE|TIME_MINUTES),rangePips,
                     d.methodLabel,d.trendState,d.marketModeLabel);
      else
         PrintFormat("TGM [R448 ROUTER]: H4 %s range=%.0fpip in GAP %.0f-%.0f -> NO TRADE",
                     TimeToString(h4Open,TIME_DATE|TIME_MINUTES),rangePips,m_smallRange,m_largeRange);
      return ok;
     }

   void LogSummary()
     {
      PrintFormat("TGM [ROUTER SUMMARY]: cycles=%d | limit=%d | stop=%d | gap-skip=%d | small<=%.0f large>=%.0f",
                  m_cycles,m_limitCycles,m_stopCycles,m_gapSkips,m_smallRange,m_largeRange);
     }

   void Shutdown()
     {
      if(m_hEmaFast!=INVALID_HANDLE){ IndicatorRelease(m_hEmaFast); m_hEmaFast=INVALID_HANDLE; }
      if(m_hEmaSlow!=INVALID_HANDLE){ IndicatorRelease(m_hEmaSlow); m_hEmaSlow=INVALID_HANDLE; }
      if(m_hAdx!=INVALID_HANDLE)    { IndicatorRelease(m_hAdx);     m_hAdx=INVALID_HANDLE; }
      if(m_hAtr!=INVALID_HANDLE)    { IndicatorRelease(m_hAtr);     m_hAtr=INVALID_HANDLE; }
      if(m_hD1Fast!=INVALID_HANDLE) { IndicatorRelease(m_hD1Fast);  m_hD1Fast=INVALID_HANDLE; }
      if(m_hD1Slow!=INVALID_HANDLE) { IndicatorRelease(m_hD1Slow);  m_hD1Slow=INVALID_HANDLE; }
      m_ready=false;
     }
  };

#endif // GM_CUNIFIED_METHOD_ROUTER_MQH