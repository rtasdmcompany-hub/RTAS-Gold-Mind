//+------------------------------------------------------------------+
//|                                                The_Gold_Mind.mq5 |
//|                        The Gold Mind - H4 Grid Expert Advisor     |
//|  EXPERIMENT v2 - 1% equity risk | 300 pip SL | 500 pip TP        |
//+------------------------------------------------------------------+
#property copyright "RTAS Digital Marketing Company | RTAS Group of Companies"
#property version   "2.300"
#property description "RTAS Gold Mind Experiment v2 - XAUUSD H4 range-adaptive grid EA."
#property description "2 BUY + 2 SELL | SL 300 pip | TP 500 pip (1:1.67) | 1% equity risk."
#property description "+50 pip: BE | +130 pip: trail 50 pip | inverted entry 300+ pip range."
#property link      "https://www.mql5.com/en/users/rtas"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <AI/ExecutionSupervisor/Phase11B/CGmEAPreActivationBridge.mqh>
#include <AI/InstitutionalValidation/CGmPhase14ValidationBridge.mqh>

//--- Core constants
#define EXPERT_MAGIC              112299
#define GRID_LINE_PREFIX          "TGM_GL_"
#define UI_PREFIX                 "TGM_UI_"
#define TGM_SHARED_SL_BEYOND_LAST_PIPS 50.0
#define TGM_RISK_DIST_PIPS           50.0
#define TGM_BUILD_SERIAL            448
#define TGM_R380_FORCE_NO_H4_RANGE_FILTER 1
#define TGM_FORCE_DISABLE_DAILY_PROFIT_LOCK 1
#define TGM_PENDING_CLAIM_STALE_SEC  3

#include <AI/RiskGovernor/Phase17/CPhase17RiskGovernor.mqh>
#include <AI/Research/CUnifiedMethodRouter.mqh>

#define TGM_RETCODE_FROZEN          10029
#define TGM_AUTO_MAX_LOT_CAP        0.00
#define TGM_HEDGE_COMMENT              "GM_HEDGE"
#define TGM_PROTECTION_ALERT_INTERVAL_SEC 120
#define TGM_HEDGE_CHOP_MAX_EVENTS   6
#define TGM_GRID_LEVEL_IDLE         0.0
#define TGM_GRID_LEVEL_PENDING      1.0
#define TGM_GRID_LEVEL_LIVE         2.0
#define TGM_GRID_LEVEL_SPENT        3.0
#define TGM_DASHBOARD_BE_EPSILON    0.50
#define TGM_PANEL_WIDTH             250
#define TGM_PANEL_HEIGHT_MIN        48
#define TGM_PANEL_HEIGHT_FULL       295
#define TGM_HEADER_H                50
#define TGM_LOGO_W                  42
#define TGM_LOGO_H                  42
#define TGM_LOGO_X_OFFSET           7
#define TGM_LOGO_Y_OFFSET           5
#define TGM_TITLE_X_OFFSET          58
#define TGM_TITLE_Y_OFFSET          8
#define TGM_TAGLINE_Y_OFFSET        26
#define TGM_AUTOTRADE_COOLDOWN_SEC  30
#define TGM_TRADE_WARN_INTERVAL_SEC 300
#define TGM_MODIFY_RETRY_SEC        20
#define TGM_SERVER_PAUSE_SEC        900
#define TGM_DASHBOARD_TIMER_SEC     2
#define TGM_RETCODE_MARKET_CLOSED   10018
#define TGM_BASE_DEVIATION_PTS      50.0
#define CLEANUP_SLEEP_MS            300
#define CLEANUP_MAX_ITERATIONS      500

#ifndef OBJ_ALL_PERIODS
#define OBJ_ALL_PERIODS 0x00FFFFFF
#endif
#ifndef OBJ_NO_PERIODS
#define OBJ_NO_PERIODS 0x00000000
#endif

#resource "\\Images\\TheGoldMind_Logo.bmp"
#define LOGO_RESOURCE_PATH        "::Images\\TheGoldMind_Logo.bmp"
#define LOGO_FIT_RESOURCE         "::TGM_LogoFit"
bool   g_logoFitOk = false;
bool   BuildScaledLogoResource(const string srcResource, const int dstW, const int dstH);
string ActiveLogoResource();

#define TGM_UI_Z_PANEL            0
#define TGM_UI_Z_LOGO             3
#define TGM_UI_Z_LABELS           10
#define TGM_UI_Z_BUTTON           11
#define UI_LEGACY_PREFIX_LOCK     "TGMLK_UI_"
#define UI_LEGACY_PREFIX_RTAS     "RTAS_"

enum ENUM_RISK_MODE
{
   RISK_AUTO_3_PERCENT_EQUITY = 0,
   RISK_MANUAL_LOT            = 1
};

enum ENUM_DIRECTION_MODE
{
   DIR_BOTH = 0,
   DIR_BUY  = 1,
   DIR_SELL = 2
};

input group "--- Optional ---"
input bool InpEnableWebsiteSync = true;  // Send stats to your dashboard
input int  InpSyncIntervalSec   = 60;    // Sync interval (sec)

input group "--- Risk & Lot Sizing ---"
input double InpRiskPercent = 1.0;       // Risk % of EQUITY per trade (1% safe)
input ENUM_RISK_MODE RiskMode           = RISK_AUTO_3_PERCENT_EQUITY;
input double         Manual_Lot_Size      = 0.50;
input double         Max_Lot_Size         = 5.00;

input group "--- ATR Fallback ---"
input double         InpFixedStopLossUSD  = 3.00;

input group "--- Live ATR Indicator Settings ---"
input int            ATR_Period           = 12;

input group "--- SL & TP Settings ---"
input double         TP_ATR_Multiplier       = 1.0;

input group "=== RESEARCH 428 ==="
input int    RESEARCH_LEVEL_MASK      = 3;
input string RESEARCH_CYCLES          = "";
input double RESEARCH_FIX_SL_PIPS     = 300.0;  // SL 300 pip
input double RESEARCH_RR_TP_MULT      = 1.6667; // TP = SL × 1.6667 (500 pip)
input double RESEARCH_INV_TP_L1_PIPS  = 300.0;  // L1 SL pips (FIXED: was 100)
input double RESEARCH_INV_TP_L2_PIPS  = 300.0;  // L2 SL pips (FIXED: was 100)
input double RESEARCH_INV_TP_L3_PIPS  = 300.0;  // L3 SL pips (FIXED: was 100)

input group "=== UNIFIED METHOD ROUTER (R445 RANGE BOTH) ==="
input bool   UseD1Direction            = false;
input bool   UseH4Direction            = true;
input int    ROUTER_EMA_Fast_Period    = 50;
input int    ROUTER_EMA_Slow_Period    = 200;
input int    ROUTER_ADX_Period         = 14;
input double ROUTER_ADX_Min            = 20.0;
input double ROUTER_ADX_Strong         = 25.0;
input int    ROUTER_ATR_Period         = 14;
input int    AlignedMinScore           = 70;
input int    PullbackMinScore          = 80;
input double LargeRangePips            = 300.0;
input double SmallRangePips            = 250.0;
input bool   GapTradingEnabled         = false;
input bool   UseSMCConfirmation        = true;
input bool   UseBOSCHoCH               = true;
input bool   UseVWAPConfirmation       = false;

const int            InpHedgeRearmMinSec  = 0;

input group "--- Account Protection (mandatory safety) ---"
input bool           Enable_Account_Protection = true;
input double         Max_Floating_DD_Percent   = 8.0;

const int            Hedge_Retry_Seconds       = 30;

input group "--- Kill Switch (last resort) ---"
input bool           Enable_Triple_Protection       = true;
input double         Emergency_Close_DD_Percent     = 10.0;
input double         Max_Daily_Loss_Percent         = 12.0;

input group "--- Gap / Freeze LIVE SAFE (R440) ---"
input bool           Enable_GapFreeze_Hardening     = true;
input int            Live_MaxOpenBotPositions       = 4;
input int            Live_MaxPendingLevels          = 2;
input double         PendingCancel_DD_Percent       = 0.0;
input double         MaxLossMultipleOfPlannedSL     = 1.25;
input double         Live_MaxSpreadPips             = 80.0;

input group "--- Direction Control ---"
input ENUM_DIRECTION_MODE TradeDirection = DIR_BOTH;

input group "--- R449 Profit Formula ---"
input double InpPartialTriggerPips = 50.0;
input double InpPartialPercent     = 0.0;
input double InpRunnerTrailPips    = 50.0;

//--- Globals
CTrade              g_trade;
int                 g_atrHandle              = INVALID_HANDLE;
datetime            g_lastH4BarTime          = 0;
datetime            g_lastDashboardUpdate    = 0;
datetime            g_historyCacheH4Start    = 0;
bool                g_historyCacheSelectOk   = false;
double              point_modifier           = 1.0;
int                 g_uiX                    = 15;
int                 g_uiY                    = 40;
bool                g_uiMinimized            = false;
bool                g_isDragging             = false;
int                 g_dragOffsetX            = 0;
int                 g_dragOffsetY            = 0;
datetime            g_autotradeCooldownUntil  = 0;
datetime            g_lastTradeBlockWarnTime  = 0;
datetime            g_lastRetcode10026LogTime = 0;
bool                g_autotradeBoxShown       = false;
datetime            g_serverTradePausedUntil  = 0;
datetime            g_modifyPausedUntil       = 0;
datetime            g_lastServerPauseLogTime  = 0;
string              g_lastServerPauseReason   = "";
datetime            g_lastProtectionAlertTime  = 0;
bool                g_gridStrategyBusy         = false;
datetime            g_lastEmptyGridRebuildH4  = 0;
bool                g_accountProtectionActive = false;
string              g_accountProtectionReason = "";
bool                g_emergencyKillSwitchActive = false;
string              g_emergencyKillSwitchReason = "";
bool                g_forceFlattenActive          = false;
datetime            g_lastFlattenRetryTime        = 0;
datetime            g_emergencyLockH4Open         = 0;
string              g_emergencyLockReason         = "";
bool                g_h4PlacementDone             = false;
datetime            g_pendingClaimTime[6];
datetime            g_lastPendingMaintainTime     = 0;
bool                g_marketValidationCompleted = false;
ENUM_RISK_MODE      g_effectiveRiskMode         = RISK_AUTO_3_PERCENT_EQUITY;
double              g_effectiveManualLotSize    = 0.50;
double              g_effectiveMaxLotSize         = 5.00;
bool                g_dirEnableBuyArm             = false;
bool                g_dirEnableSellArm            = false;
bool                g_dirBreakoutPlacement        = false;
CUnifiedMethodRouter g_unifiedRouter;
STgmRouterDecision   g_lastRouterDecision;
datetime            lastWebSendTime = 0;

//--- Forward declarations
bool   ShouldRenderUI();
void   InitBrokerPointModifier();
bool   GetLiveATR(double &atrOut);
double GetConfiguredStopDistance();
bool   GetSharedGridSideStopLoss(const ENUM_POSITION_TYPE side, double &slOut);
double GetLotSizingCapital();
bool   CalculateH4GridLevels(double &high1, double &low1, double &pivot, double &buy1, double &buy2, double &buy3, double &sell1, double &sell2, double &sell3);
bool   CalculateExcelGridSLTP(const double buy1, const double buy2, const double buy3, const double sell1, const double sell2, const double sell3, const double atrValue, double &buySL, double &sellSL, double &buyTP1, double &buyTP2, double &buyTP3, double &sellTP1, double &sellTP2, double &sellTP3);
void   ManagePositionTradeLifecycle(const ulong ticket);
void   CloseAllBotPositionsForced(const string reason);
void   RecordEaBuildSerial();
bool   EnsureAllBotPendingDeleted();
bool   EnsureAllBotPendingDeletedForced();
void   CleanupEAChartVisuals();
bool   PreTradeGuard(const string operation);
bool   PreProtectionTradeGuard(const string operation);
bool   HasOpenBotPositions();
bool   IsPositionMgmtAllowed();
bool   IsGridOpsAllowed();
bool   IsWeekendOrMarketClosed();
bool   IsModifyTradeOperation(const string operation);
void   MarkBreakEvenPending(const ulong ticket);
bool   IsDashboardMarketClosed();
string GetDashboardClosedStatusLabel();
void   RegisterServerTradePause(const uint retcode, const string operation);
void   MonitorServerTradeRecovery();
bool   IsTradeModifyCooldownActive();
void   ShowAutoTradeSetupWarningIfNeeded();
void   EnableDashboardChartEvents();
void   EnsureDashboardPresent();
void   UpdateDashboard(const bool forceUpdate = false);
void   DestroyAllChartDashboardUI();
bool   CreateUIBitmap(string name, string bmp_path);
void   CreateUISeparator(string name);
void   CreateUILogoFrame();
bool   LoadDashboardLogo();
void   RemoveLogoFrame();
void   RemoveDashboardDragHandle();
bool   IsDashboardSymbolMatch(const string dealSymbol);
double GetDashboardDealNetProfit(const ulong ticket);
bool   IsGridPositionComment(const string comment);
bool   IsBotGridPendingOrder(const ulong orderTicket);
void   CollectDashboardTradeStats(double &sessionProfit, int &openGridTrades, int &openHedgeTrades, int &sessionOpenedGrid, int &sessionClosedTotal, int &sessionClosedWins, int &sessionClosedLosses);
bool   AddUniquePositionId(const long positionId, long &ids[]);
bool   GetDashboardDayWindow(datetime &fromOut, datetime &toOut);
string FormatDashboardMoney(const double value);
color  GetDailyProfitColor(const double dailyProfit);
void   SetUILabelColor(const string name, const color textColor);
string GetDashboardMarketStatus();
color  GetMarketStatusColor(const string status);
void   InitDashboard();
void   RenderDashboardLayout();
int    ExecuteH4GridStrategy(const bool freshH4Cycle = false);
int    MaintainArmedPendings(const string trigger);
int    GridLevelCommentIndex(const string comment);
void   MarkPendingClaim(const string comment);
void   ClearPendingClaim(const string comment);
bool   IsStalePendingClaim(const string comment);
bool   LevelNeedsPendingRestore(const string comment);
bool   AnyLevelNeedsPendingRestore();
void   HealGhostPendingStates(const string reason);
bool   PlaceBuyLimit(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment);
bool   PlaceBuyStop(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment);
bool   PlaceSellLimit(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment);
bool   PlaceSellStop(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment);
void   LogLotCalculationDetail(const string tag, const string comment, const int levelIndex, const double slDistancePrice, const double finalLots);
void   RefreshGridOnNewH4Bar(const string trigger);
void   ForceRebuildCurrentGrid(const string trigger);
bool   MaybeForceRebuildCurrentH4IfEmpty(const string trigger);
void   RefreshGridChartLinesFromH4();
void   UniversalGoldTrailingEngine();
void   ClearHedgePeakProfitPoints(const ulong hedgeTicket);
void   RunAccountProtectionEngine();
void   MonitorAccountDrawdownProtection();
void   MonitorLiveGapFreezeGuards();
void   RetryForceFlattenUntilFlat();
int    CountBotPendings();
int    CountOpenBotPositions();
bool   LiveSafeAllowsNewPending(const int levelIndex);
bool   IsGridPlacementAllowed(const bool freshH4Cycle = false);
void   ClearHedgeProtectionState(const ulong parentTicket);
void   LogProtectionAlert(const string message);
void   MonitorLayer3HardKillSwitch();
bool   IsKillSwitchActiveToday();
string KillSwitchDayKey();
bool   StrictH4CycleOnly();
bool   IsEmergencyLockThisH4();
void   SetEmergencyLockThisH4(const string reason);
void   ClearEmergencyLockIfNewH4();
void   MarkH4PlacementDone();
bool   SafePositionModify(const ulong ticket, const double sl, const double tp, const string operation);
bool   CloseHedgePosition(const ulong hedgeTicket, const string reason);
bool   IsProfitEngineArmed(const ulong ticket);
void   SetHedgeTriggerReady(const ulong parentTicket, const bool ready);
bool   EnsureModeBFixedBrokerSL(const ulong parentTicket);
void   CloseStrayHedgesInFixedSlMode();
bool   IsFixedSlReentryMode();
double GetActiveHedgeTriggerUSD();
string ResolveGridLevelNameFromComment(const string comment);
string ResolveGridLevelFromClosedDeal(const ulong dealTicket, const string dealComment);
void   ProcessModeBLevelExitFromDeal(const ulong dealTicket);
string LevelBELockKey(const string comment);
bool   IsLevelBELockedThisH4(const string comment);
void   MarkLevelBELockedThisH4(const string comment);
void   ClearAllLevelBELocksThisH4();
int    GetLevelActivationCountThisH4(const string comment);
int    MaxLevelActivationsThisH4();
bool   LevelHasLivePositionThisH4(const string comment);
int    CancelPendingOrdersForLevel(const string comment);
void   IncrementLevelActivationThisH4(const string comment);
void   ClearAllLevelActivationCountsThisH4();
bool   IsLevelActivationExhaustedThisH4(const string comment);
void   MarkLevelActivationExhaustedThisH4(const string comment);
void   LogPriceThroughOnce(const string comment, const string reason);
void   ShowManualLotWarning();
void   ApplyEffectiveRiskSettingsFromInputs();
bool   ConfirmManualRiskOverride();
void   SetFillingMode();
bool   IsGoldChartSymbol();
bool   IsMarketValidationMode();
bool   IsSymbolTradeSessionOpen();
bool   ValidationMarketDealCheck(const ENUM_ORDER_TYPE orderType, const double lots);
bool   RunMarketValidationTradeOnce();
void   SynchronizePersistentState(const string reason);
void   SynchronizeGridLevelStates(const string reason);
void   SeedHedgeMonitorForParent(const ulong parentTicket);
void   ApplyHedgeRecycleCooldown(const ulong parentTicket, const int lifeSec);
void   ClearHedgeReturnArmed(const ulong hedgeTicket);
void   ResetAllGridLevelStates();
bool   PositionMatchesGridComment(const ulong positionTicket, const string comment);
ulong  FindGridPositionTicketByCommentThisH4(const string comment, const datetime currentH4);
ulong  FindGridPendingTicketByComment(const string comment);
bool   HasBotPendingByComment(const string comment);
bool   IsCommentActiveInPositions(const string comment);
bool   IsLevelAlreadySpentInCurrentH4Bar(const string comment);
bool   IsLevelBELockedThisH4(const string comment);
bool   IsLevelActivationExhaustedThisH4(const string comment);
int    GetLevelActivationCountThisH4(const string comment);
int    CountBotPendings();
void   SetGridLevelState(const string comment, const double state, const ulong ticket = 0);
void   ClearGridLevelState(const string comment);
bool   PendingCommentMatchesLevel(const string orderComment, const string levelComment);
int    CancelDuplicatePendingsAtSamePrice();
bool   GetPositionOpeningComments(const ulong positionTicket, string &dealCommentOut, string &orderCommentOut);
bool   WasOpenedAsGridLimit(const ulong positionTicket);
bool   IsOurBotMagicPosition(const ulong ticket);
bool   IsOurBotGridParent(const ulong ticket);
bool   IsForeignOrManualPosition(const ulong ticket);
bool   IsBotHedgePosition(const ulong ticket, const string comment);
bool   IsProfitEngineArmed(const ulong ticket);
bool   IsPartialClosedBeRunner(const ulong ticket);
void   LogPhase28A(const string eventName, const ulong ticket, const string detail);
double GetPositionProfitUSD(const ulong ticket);
void   ClearGridLevelState(const string comment);
void   SaveGridH4BarTime(const datetime barTime);
void   CleanDeadGlobalVariables();
void   SendDataToWebsite();
void   ManageProfitRunners();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(ATR_Period < 1)
   {
      Print("The Gold Mind: ATR_Period must be >= 1.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(TP_ATR_Multiplier <= 0.0)
   {
      Print("The Gold Mind: TP_ATR_Multiplier must be > 0.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Max_Floating_DD_Percent <= 0.0 || Max_Floating_DD_Percent > 50.0)
   {
      Print("The Gold Mind: Max_Floating_DD_Percent must be between 0 and 50.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Max_Lot_Size < 0.0)
   {
      Print("The Gold Mind: Max_Lot_Size must be >= 0 (0 = no EA cap).");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpFixedStopLossUSD <= 0.0)
   {
      Print("The Gold Mind: InpFixedStopLossUSD must be > 0 (fixed $ SL / ATR fallback).");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Emergency_Close_DD_Percent <= Max_Floating_DD_Percent || Emergency_Close_DD_Percent > 40.0)
   {
      Print("The Gold Mind: Emergency_Close_DD_Percent must be > Max_Floating_DD_Percent and <= 40.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Enable_GapFreeze_Hardening)
   {
      if(PendingCancel_DD_Percent < 0.0 ||
         (PendingCancel_DD_Percent > 0.0 && PendingCancel_DD_Percent >= Emergency_Close_DD_Percent))
      {
         Print("The Gold Mind: PendingCancel_DD_Percent must be 0 (OFF) or >0 and < Emergency_Close_DD_Percent.");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(Live_MaxOpenBotPositions < 1 || Live_MaxOpenBotPositions > 6)
      {
         Print("The Gold Mind: Live_MaxOpenBotPositions must be 1..6.");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(Live_MaxPendingLevels < 1 || Live_MaxPendingLevels > 3)
      {
         Print("The Gold Mind: Live_MaxPendingLevels must be 1..3.");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(MaxLossMultipleOfPlannedSL < 1.0 || MaxLossMultipleOfPlannedSL > 5.0)
      {
         Print("The Gold Mind: MaxLossMultipleOfPlannedSL must be 1.0..5.0.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(Max_Daily_Loss_Percent <= 0.0 || Max_Daily_Loss_Percent > 40.0)
   {
      Print("The Gold Mind: Max_Daily_Loss_Percent must be between 0 and 40.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(PHASE18_ENABLE_DD_GOVERNOR)
   {
      if(PHASE18_DD_HARD_LIMIT_PERCENT <= 0.0 || PHASE18_DD_HARD_LIMIT_PERCENT > 90.0)
      {
         Print("The Gold Mind: PHASE18_DD_HARD_LIMIT_PERCENT must be between 0 and 90.");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(PHASE18_DD_FREEZE_PERCENT >= PHASE18_DD_HARD_LIMIT_PERCENT ||
         PHASE18_DD_RISK_REDUCTION_PERCENT >= PHASE18_DD_FREEZE_PERCENT ||
         PHASE18_DD_RISK_REDUCTION_PERCENT <= 0.0)
      {
         Print("The Gold Mind: PHASE18 DD levels must satisfy 0 < RiskReduction < Freeze < HardLimit.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(PHASE18_ENABLE_DAILY_PROFIT_LOCK && (PHASE18_DAILY_PROFIT_LOCK_PERCENT <= 0.0 || PHASE18_DAILY_PROFIT_LOCK_PERCENT > 50.0))
   {
      Print("The Gold Mind: PHASE18_DAILY_PROFIT_LOCK_PERCENT must be between 0 and 50.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(PHASE18_ENABLE_H4_RANGE_FILTER && PHASE18_MAX_H4_RANGE_PIPS <= 0.0)
   {
      Print("The Gold Mind: PHASE18_MAX_H4_RANGE_PIPS must be > 0 when H4 range filter is enabled.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(PHASE18_MAX_LEVEL_ACTIVATIONS_H4 < 1)
   {
      Print("The Gold Mind: PHASE18_MAX_LEVEL_ACTIVATIONS_H4 must be >= 1.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(SmallRangePips <= 0.0 || LargeRangePips <= SmallRangePips)
   {
      Print("The Gold Mind: Unified router requires 0 < SmallRangePips < LargeRangePips.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(AlignedMinScore < 1 || PullbackMinScore < AlignedMinScore)
   {
      Print("The Gold Mind: 0 < AlignedMinScore <= PullbackMinScore required.");
      return INIT_PARAMETERS_INCORRECT;
   }

   ApplyEffectiveRiskSettingsFromInputs();
   InitBrokerPointModifier();
   g_trade.SetExpertMagicNumber(EXPERT_MAGIC);
   g_trade.SetDeviationInPoints((ulong)MathRound(TGM_BASE_DEVIATION_PTS * point_modifier));
   SetFillingMode();

   g_atrHandle = iATR(_Symbol, PERIOD_H4, ATR_Period);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("The Gold Mind: Failed to create iATR handle. GetLastError=", GetLastError());
      return INIT_FAILED;
   }

   if(!g_unifiedRouter.Init(_Symbol, ROUTER_EMA_Fast_Period, ROUTER_EMA_Slow_Period,
                            ROUTER_ADX_Period, ROUTER_ATR_Period))
      return INIT_FAILED;

   g_unifiedRouter.Configure(UseD1Direction, UseH4Direction,
                             ROUTER_ADX_Min, ROUTER_ADX_Strong,
                             AlignedMinScore, PullbackMinScore,
                             LargeRangePips, SmallRangePips,
                             GapTradingEnabled, UseSMCConfirmation, UseBOSCHoCH,
                             UseVWAPConfirmation);

   Print("TGM [R445]: Range router ON | <=Small BOTH limits | >=Large BOTH stops | gap skip | direction never blocks.");
   PrintFormat("TGM [DIRECTION]: TradeDirection=%s (0=Both,1=Buy,2=Sell)", (string)(int)TradeDirection);

   double initAtr = 0.0;
   if(GetLiveATR(initAtr))
   {
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      PrintFormat("The Gold Mind: Live H4 ATR(%d)=%.*f | sharedSL last+/-%.0fpip | TP=%.*f (%.1fx ATR) | hedge=OFF",
                  ATR_Period, digits, initAtr,
                  TGM_SHARED_SL_BEYOND_LAST_PIPS,
                  digits, initAtr * TP_ATR_Multiplier, TP_ATR_Multiplier);
   }

   if(ShouldRenderUI())
   {
      DestroyAllChartDashboardUI();
      InitDashboard();
      EnableDashboardChartEvents();
      RefreshGridChartLinesFromH4();
      EventSetTimer(TGM_DASHBOARD_TIMER_SEC);
   }

   GmP11B_OnInit(EXPERT_MAGIC, g_effectiveMaxLotSize, g_atrHandle, g_uiX, g_uiY);
   GmP14_OnInit(g_atrHandle);
   Phase17_OnInit();

   if(!IsStrategyTester())
   {
      RecordEaBuildSerial();
      Print("The Gold Mind: EA started - open positions and pendings preserved on reload.");
   }

   g_historyCacheH4Start = 0;
   g_historyCacheSelectOk = false;
   g_lastH4BarTime = LoadGridH4BarTime();
   SynchronizePersistentState("OnInit");

   if(!IsMarketValidationMode() && IsGoldChartSymbol())
   {
      ClearEmergencyLockIfNewH4();
      if(IsNewH4GridPeriod())
         RefreshGridOnNewH4Bar("OnInit-Fresh");
      else if(IsGridPlacementAllowed() && !StrictH4CycleOnly())
      {
         if(!MaybeForceRebuildCurrentH4IfEmpty("OnInit-EmptySameH4"))
            ExecuteH4GridStrategy();
      }
      else if(StrictH4CycleOnly() && !IsEmergencyLockThisH4())
      {
         if(IsGridPlacementAllowed(true))
         {
            HealGhostPendingStates("OnInit");
            Print("TGM [R444]: Mid-H4 attach — arm up to 3 pending levels now (manual delete restores while EA active).");
            const int n = ExecuteH4GridStrategy(true);
            MarkH4PlacementDone();
            SaveGridH4BarTime(GetCurrentH4BarOpenTime());
            PrintFormat("TGM [R444]: Initial arm placed=%d pendingNow=%d", n, CountBotPendings());
         }
         else
            Print("TGM [R444]: Mid-H4 attach deferred — waiting for Algo Trading ON (OnTick will arm + keep restoring).");
      }
   }
   else if(!IsMarketValidationMode())
      Print("The Gold Mind: Non-Gold symbol (", _Symbol, ") - grid/trading disabled. Use XAUUSD on H4.");

   if(!IsStrategyTester() && IsWeekendOrMarketClosed())
   {
      g_serverTradePausedUntil = TimeCurrent() + TGM_SERVER_PAUSE_SEC;
      g_lastServerPauseReason = "Market closed (weekend / session)";
      Print("The Gold Mind: Market closed (session break) - trade ops paused until quotes resume.");
   }

   if(!IsStrategyTester())
   {
      const string block = GetAutoTradeBlockReason();
      if(block != "")
         Print("The Gold Mind: Trade blocked - ", block);
   }

   Print("The Gold Mind v2.300 EXPERIMENT (build ", TGM_BUILD_SERIAL, "): Initialized on ", _Symbol, " (", _Digits, " digits).");
   PrintFormat("TGM: Max activations/level/H4=%d (ONE shot - no re-arm after SL/TP).",
               MaxLevelActivationsThisH4());

   {
      const double rr = (RESEARCH_RR_TP_MULT > 0.0) ? RESEARCH_RR_TP_MULT : 1.5;
      PrintFormat("TGM [R448]: RANGE BOTH | small<=%.0f | large>=%.0f | risk=%.0f%% EQUITY | SL:TP=1:%.2f | L1 %.0f/%.0f L2 %.0f/%.0f L3 %.0f/%.0f",
                  SmallRangePips, LargeRangePips, (InpRiskPercent/100.0) * 100.0, rr,
                  RESEARCH_INV_TP_L1_PIPS, RESEARCH_INV_TP_L1_PIPS * rr,
                  RESEARCH_INV_TP_L2_PIPS, RESEARCH_INV_TP_L2_PIPS * rr,
                  RESEARCH_INV_TP_L3_PIPS, RESEARCH_INV_TP_L3_PIPS * rr);
      Print("TGM [H4-POLICY]: last closed H4 high-low ONLY -> method | BUY+SELL together | no direction gate | broker TP.");
      if(MathAbs(SmallRangePips - 250.0) > 0.01 || MathAbs(LargeRangePips - 300.0) > 0.01)
         PrintFormat("TGM [WARN]: Range gates Small=%.0f Large=%.0f (intended live lock 250/300).",
                     SmallRangePips, LargeRangePips);
   }

   PrintFormat("TGM [OWNERSHIP]: Magic=%d ONLY - manual/foreign trades are invisible (no manage, no DD, no block).", EXPERT_MAGIC);
   PrintFormat("TGM [LOT]: Auto uncapped | Manual max=%.2f | AutoRisk=%.0f%% of EQUITY | DD lot scale 70/50/35%%.",
               TGM_AUTO_MAX_LOT_CAP, g_effectiveMaxLotSize, (InpRiskPercent/100.0) * 100.0);
   Print("TGM [METHOD]: Inverted directional | fixed SL/TP ladder | no +30 FULL book | no hedge.");

   if(Enable_GapFreeze_Hardening)
      PrintFormat("TGM [R440 LIVE-SAFE]: flatten-retry ON | maxOpen=%d maxLevels=%d | pendingCancelDD=%.1f%% | killDD=%.1f%% | SL*x=%.2f | maxSpread=%.0fpip",
                  Live_MaxOpenBotPositions, Live_MaxPendingLevels,
                  PendingCancel_DD_Percent, Emergency_Close_DD_Percent,
                  MaxLossMultipleOfPlannedSL, Live_MaxSpreadPips);

   if(StrictH4CycleOnly())
      Print("TGM [R444 PENDING]: Attach => arm 3 levels | manual delete => restore while EA on chart | SPENT only after SL/TP exit | remove EA to stop restore.");

   Print("TGM [P11E]: AI Dynamic Exec Engine DISABLED (removed from strategy).");
   PrintFormat("TGM [P14]: AI_VALIDATION_ENABLED=%s (OFF = unchanged H4 OrderSend path).",
               (AI_VALIDATION_ENABLED ? "true" : "false"));
   Print("TGM [PLACE]: Pendings only when Ask>BuyLevel (BuyLimit) / Bid<SellLevel (SellLimit). Price-through = wait.");

   EventSetTimer(60);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   g_unifiedRouter.LogSummary();
   g_unifiedRouter.Shutdown();

   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
      Print("The Gold Mind: EA removed - trades & pendings left intact (managed exits only).");

   if(reason != REASON_CHARTCHANGE)
   {
      Phase17_LogSummary();
      GmP11B_OnDeinit();
      GmP14_OnDeinit();
      CleanupEAChartVisuals();
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static bool validation_completed = false;
   if(!validation_completed && IsMarketValidationMode())
   {
      if(RunMarketValidationTradeOnce())
      {
         validation_completed = true;
         g_marketValidationCompleted = true;
      }
      else
         return;
   }

   if(!IsGoldChartSymbol())
      return;

   static datetime lastStateSync = 0;
   const datetime nowSync = TimeCurrent();
   if(nowSync != lastStateSync)
   {
      SynchronizePersistentState("OnTick");
      lastStateSync = nowSync;
   }

   static int warmupTicks = 0;
   if(warmupTicks < 5)
   {
      warmupTicks++;
      if(warmupTicks == 5)
         ShowAutoTradeSetupWarningIfNeeded();
   }

   MonitorServerTradeRecovery();
   GmP11B_OnTick();
   Phase17_OnTickUpdate();

   if(Phase17_ConsumePendingCancelRequest())
   {
      if(!StrictH4CycleOnly())
      {
         EnsureAllBotPendingDeletedForced();
         Print("TGM [P17B]: Bot pendings cancelled after DD freeze (open positions untouched).");
      }
      else
         Print("TGM [R444]: DD freeze noted — method pendings kept armed (manual delete restores).");
   }

   if(IsGridOpsAllowed())
   {
      if(IsNewH4GridPeriod())
         RefreshGridOnNewH4Bar("OnTick");
      else if(StrictH4CycleOnly())
      {
         if(!IsEmergencyLockThisH4())
         {
            if(!g_h4PlacementDone && IsGridPlacementAllowed(true))
            {
               HealGhostPendingStates("OnTick-InitArm");
               Print("TGM [R444]: Same-H4 initial arm (Algo ready).");
               ExecuteH4GridStrategy(true);
               MarkH4PlacementDone();
               SaveGridH4BarTime(GetCurrentH4BarOpenTime());
            }
            MaintainArmedPendings("OnTick");
         }
      }
      else
      {
         if(!MaybeForceRebuildCurrentH4IfEmpty("OnTick-EmptySameH4"))
            ExecuteH4GridStrategy();
      }
   }

   if(IsPositionMgmtAllowed() || HasOpenBotPositions())
   {
      RunAccountProtectionEngine();
      ManageProfitRunners();
   }

   CleanDeadGlobalVariables();

   if(ShouldRenderUI())
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Trade transaction function                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(IsMarketValidationMode() || !IsGoldChartSymbol())
      return;

   GmP11B_OnTradeTransaction(trans);

   if((trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_HISTORY_ADD) && trans.deal > 0)
      ProcessModeBLevelExitFromDeal(trans.deal);

   if(trans.type == TRADE_TRANSACTION_ORDER_ADD ||
      trans.type == TRADE_TRANSACTION_ORDER_UPDATE ||
      trans.type == TRADE_TRANSACTION_ORDER_DELETE ||
      trans.type == TRADE_TRANSACTION_DEAL_ADD ||
      trans.type == TRADE_TRANSACTION_HISTORY_ADD ||
      trans.type == TRADE_TRANSACTION_POSITION)
   {
      SynchronizePersistentState("OnTradeTransaction");
      if(trans.type == TRADE_TRANSACTION_ORDER_DELETE &&
         StrictH4CycleOnly() &&
         !IsEmergencyLockThisH4() &&
         IsGridOpsAllowed())
         MaintainArmedPendings("OrderDelete");
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(ShouldRenderUI())
   {
      EnsureDashboardPresent();
      UpdateDashboard(true);
      MonitorServerTradeRecovery();
   }

   if(InpEnableWebsiteSync)
   {
      const datetime now = TimeCurrent();
      if(lastWebSendTime == 0 || (now - lastWebSendTime) >= MathMax(15, InpSyncIntervalSec))
      {
         lastWebSendTime = now;
         SendDataToWebsite();
      }
   }
}

//+------------------------------------------------------------------+
//| Chart event function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!ShouldRenderUI())
      return;

   if(GmP11B_OnChartEvent(id, lparam, dparam, sparam))
      return;

   const long chartId = ChartID();
   const string btnMinName = UI_PREFIX + "BtnMin";

   if(id == CHARTEVENT_CHART_CHANGE)
   {
      EnableDashboardChartEvents();
      EnsureDashboardPresent();
      RenderDashboardLayout();
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == btnMinName)
      {
         ObjectSetInteger(chartId, btnMinName, OBJPROP_STATE, false);
         g_uiMinimized = !g_uiMinimized;
         RenderDashboardLayout();
         UpdateDashboard(true);
         ChartRedraw(chartId);
      }
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      const int mouseX = (int)lparam;
      const int mouseY = (int)dparam;
      const int mouseState = (sparam == "" ? 0 : (int)StringToInteger(sparam));
      const bool leftButtonDown = ((mouseState & 1) == 1);

      if(leftButtonDown)
      {
         if(!g_isDragging)
         {
            if(IsPointInsideDashboardHeader(mouseX, mouseY) && !IsPointInsideMinButton(mouseX, mouseY))
            {
               g_isDragging = true;
               g_dragOffsetX = mouseX - g_uiX;
               g_dragOffsetY = mouseY - g_uiY;
               ChartSetInteger(chartId, CHART_MOUSE_SCROLL, false);
            }
         }
         else
         {
            g_uiX = mouseX - g_dragOffsetX;
            g_uiY = mouseY - g_dragOffsetY;
            if(g_uiX < 0) g_uiX = 0;
            if(g_uiY < 0) g_uiY = 0;
            RenderDashboardLayout();
         }
      }
      else if(g_isDragging)
      {
         g_isDragging = false;
         ChartSetInteger(chartId, CHART_MOUSE_SCROLL, true);
         ChartRedraw(chartId);
      }
   }
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
bool IsStrategyTester() { return (bool)MQLInfoInteger(MQL_TESTER); }
bool ShouldRenderUI()   { return !IsStrategyTester(); }

bool IsMarketValidationMode()
{
   return (IsStrategyTester() && !g_marketValidationCompleted);
}

bool IsSymbolTradeSessionOpen()
{
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   const datetime dayStart = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   datetime sessFrom = 0;
   datetime sessTo = 0;
   for(uint i = 0; SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, i, sessFrom, sessTo); i++)
   {
      datetime fromTime = dayStart + sessFrom;
      datetime toTime   = dayStart + sessTo;
      if(sessTo < sessFrom)
         toTime += 86400;
      if(now >= fromTime && now < toTime)
         return true;
   }
   return false;
}

bool ValidationMarketDealCheck(const ENUM_ORDER_TYPE orderType, const double lots)
{
   MqlTradeRequest req = {};
   MqlTradeCheckResult res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lots;
   req.type      = orderType;
   req.price     = (orderType == ORDER_TYPE_BUY)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.deviation = (ulong)TGM_BASE_DEVIATION_PTS;
   req.magic     = EXPERT_MAGIC;
   long filling = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      req.type_filling = ORDER_FILLING_IOC;
   else if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      req.type_filling = ORDER_FILLING_FOK;
   else
      req.type_filling = ORDER_FILLING_RETURN;
   if(!OrderCheck(req, res))
      return false;
   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == 0);
}

bool RunMarketValidationTradeOnce()
{
   static int phase = 0;
   static datetime lastBarTime = 0;
   if(phase >= 2)
      return true;
   if(!IsStrategyTester())
      return true;
   const datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return false;
   if(!IsSymbolTradeSessionOpen())
      return false;
   const double lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lots <= 0.0)
      return false;
   g_trade.SetExpertMagicNumber(EXPERT_MAGIC);
   SetFillingMode();
   if(phase == 0)
   {
      if(!ValidationMarketDealCheck(ORDER_TYPE_BUY, lots))
         return false;
      if(g_trade.Buy(lots, _Symbol, 0, 0, 0, "TGM_MarketValidation"))
      {
         lastBarTime = barTime;
         phase = 1;
      }
      return false;
   }
   if(phase == 1)
   {
      if(!ValidationMarketDealCheck(ORDER_TYPE_SELL, lots))
         return false;
      if(g_trade.Sell(lots, _Symbol, 0, 0, 0, "TGM_MarketValidation"))
      {
         lastBarTime = barTime;
         phase = 2;
         return true;
      }
   }
   return false;
}

bool IsGoldChartSymbol()
{
   const string sym = _Symbol;
   if(sym == "XAUUSD" || sym == "XAUUSDm" || sym == "GOLD")
      return true;
   if(StringFind(sym, "XAUUSD") == 0)
      return true;
   string upper = sym;
   StringToUpper(upper);
   if(upper == "GOLD" || StringFind(upper, "XAUUSD") == 0)
      return true;
   return false;
}

void LogTradeFailure(const string operation, const string context, const uint retcode, const string hint = "")
{
   const datetime now = TimeCurrent();
   if(retcode == 10026 && (now - g_lastRetcode10026LogTime) < TGM_AUTOTRADE_COOLDOWN_SEC)
      return;
   if(retcode == 10026)
      g_lastRetcode10026LogTime = now;
   const string ctx = (context == "" ? "" : " | " + context);
   if(hint != "")
      PrintFormat("The Gold Mind | %s FAILED | retcode=%u (%s) | %s%s",
                  operation, retcode, g_trade.ResultRetcodeDescription(), hint, ctx);
   else
      PrintFormat("The Gold Mind | %s FAILED | retcode=%u (%s) | GetLastError=%d%s",
                  operation, retcode, g_trade.ResultRetcodeDescription(), GetLastError(), ctx);
   ResetLastError();
}

string GetAutoTradeBlockReason()
{
   if(IsStrategyTester())
      return "";
   if(IsServerTradePaused())
      return g_lastServerPauseReason;
   if(IsWeekendOrMarketClosed())
      return "Market closed (weekend / session)";
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
      return "MT5 Algo Trading button is OFF (toolbar)";
   if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
      return "This chart EA: Properties > Common > Allow Algo Trading is OFF";
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
      return "Account trading is disabled";
   const long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      return StringFormat("%s trading is disabled", _Symbol);
   if(tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return StringFormat("%s is close-only", _Symbol);
   return "";
}

datetime SessionBoundaryForToday(const datetime sessionTime, const datetime now)
{
   MqlDateTime nowDt, sessDt;
   TimeToStruct(now, nowDt);
   TimeToStruct(sessionTime, sessDt);
   nowDt.hour = sessDt.hour;
   nowDt.min  = sessDt.min;
   nowDt.sec  = sessDt.sec;
   return StructToTime(nowDt);
}

bool IsSymbolTradeSessionOpenNow()
{
   const datetime now = TimeTradeServer();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime from = 0, to = 0;
   for(uint session = 0; session < 32; session++)
   {
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, session, from, to))
         break;
      datetime sessFrom = SessionBoundaryForToday(from, now);
      datetime sessTo   = SessionBoundaryForToday(to, now);
      if(sessTo < sessFrom)
         sessTo += 86400;
      if(now >= sessFrom && now <= sessTo)
         return true;
   }
   return false;
}

bool IsWeekendOrMarketClosed()
{
   if(IsStrategyTester())
      return false;
   return !IsSymbolTradeSessionOpenNow();
}

bool IsDashboardMarketClosed()
{
   if(IsStrategyTester())
      return false;
   if(!IsSymbolTradeSessionOpenNow())
      return true;
   const datetime lastM1 = iTime(_Symbol, PERIOD_M1, 0);
   if(lastM1 <= 0)
      return true;
   const int maxQuotePauseSec = 1800;
   return ((TimeTradeServer() - lastM1) > maxQuotePauseSec);
}

string GetDashboardClosedStatusLabel()
{
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return "WEEKEND";
   return "CLOSED";
}

bool IsServerTradePaused()
{
   return (!IsStrategyTester() && TimeCurrent() < g_serverTradePausedUntil);
}

bool IsModifyTradeOperation(const string operation)
{
   if(StringFind(operation, "PositionModify") >= 0)
      return true;
   if(StringFind(operation, "PositionClosePartial") >= 0)
      return true;
   if(StringFind(operation, "EmergencyParentSL") >= 0)
      return true;
   return false;
}

bool IsProtectionTradeOperation(const string operation)
{
   if(IsModifyTradeOperation(operation))
      return true;
   if(StringFind(operation, "Hedge") >= 0)
      return true;
   if(StringFind(operation, "EmergencyClose") >= 0)
      return true;
   if(StringFind(operation, "PositionClose") >= 0)
      return true;
   if(StringFind(operation, "OrderDelete") >= 0)
      return true;
   if(StringFind(operation, "KillSwitch") >= 0)
      return true;
   if(StringFind(operation, "ForceFlatten") >= 0)
      return true;
   if(StringFind(operation, "GapGuard") >= 0)
      return true;
   return false;
}

ulong ParseTicketFromTradeContext(const string context)
{
   const int pos = StringFind(context, "ticket=");
   if(pos < 0)
      return 0;
   return (ulong)StringToInteger(StringSubstr(context, pos + 7));
}

void RegisterServerTradePause(const uint retcode, const string operation)
{
   if(retcode != TGM_RETCODE_MARKET_CLOSED &&
      retcode != TGM_RETCODE_FROZEN &&
      retcode != 10017 &&
      retcode != 10019 &&
      retcode != 10026)
      return;

   if(IsProtectionTradeOperation(operation) &&
      (retcode == TGM_RETCODE_FROZEN || retcode == TGM_RETCODE_MARKET_CLOSED))
   {
      g_modifyPausedUntil = TimeCurrent() + TGM_MODIFY_RETRY_SEC;
      const datetime now = TimeCurrent();
      if((now - g_lastServerPauseLogTime) >= TGM_TRADE_WARN_INTERVAL_SEC)
      {
         g_lastServerPauseLogTime = now;
         PrintFormat("The Gold Mind: Protection retry in %d sec (%s | retcode %u).",
                     TGM_MODIFY_RETRY_SEC, operation, retcode);
      }
      return;
   }

   g_serverTradePausedUntil = TimeCurrent() + TGM_SERVER_PAUSE_SEC;
   if(retcode == TGM_RETCODE_MARKET_CLOSED)
      g_lastServerPauseReason = "Market closed - broker rejected trade (retcode 10018)";
   else if(retcode == TGM_RETCODE_FROZEN)
      g_lastServerPauseReason = "Market frozen - broker rejected modify/order (retcode 10029)";
   else if(retcode == 10017)
      g_lastServerPauseReason = "Trading disabled by broker (retcode 10017)";
   else if(retcode == 10026)
      g_lastServerPauseReason = "Auto-trading disabled by server (retcode 10026)";
   else
      g_lastServerPauseReason = StringFormat("Broker rejected %s (retcode %u)", operation, retcode);

   const datetime now = TimeCurrent();
   if((now - g_lastServerPauseLogTime) >= TGM_TRADE_WARN_INTERVAL_SEC)
   {
      g_lastServerPauseLogTime = now;
      PrintFormat("The Gold Mind: Trade ops paused for %d min - %s", TGM_SERVER_PAUSE_SEC / 60, g_lastServerPauseReason);
   }
}

void MonitorServerTradeRecovery()
{
   if(IsStrategyTester() || g_serverTradePausedUntil == 0)
      return;
   if(TimeCurrent() >= g_serverTradePausedUntil && !IsWeekendOrMarketClosed())
   {
      g_serverTradePausedUntil = 0;
      g_lastServerPauseReason = "";
      Print("The Gold Mind: Broker session available again - grid/trade ops resumed.");
   }
   if(g_modifyPausedUntil > 0 && TimeCurrent() >= g_modifyPausedUntil)
      g_modifyPausedUntil = 0;
}

bool IsPositionMgmtAllowed()
{
   if(IsStrategyTester())
      return true;
   if(IsWeekendOrMarketClosed())
      return false;
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
      return false;
   if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
      return false;
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
      return false;
   const long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   return true;
}

bool IsGridOpsAllowed()
{
   if(IsKillSwitchActiveToday())
      return false;
   if(!IsPositionMgmtAllowed())
      return false;
   if(IsServerTradePaused())
      return false;
   return true;
}

bool IsTradeModifyCooldownActive()
{
   return (!IsStrategyTester() && TimeCurrent() < g_autotradeCooldownUntil);
}

void WarnAutoTradeBlocked(const string operation)
{
   const string reason = GetAutoTradeBlockReason();
   if(reason == "")
      return;
   const datetime now = TimeCurrent();
   if((now - g_lastTradeBlockWarnTime) < TGM_TRADE_WARN_INTERVAL_SEC)
      return;
   g_lastTradeBlockWarnTime = now;
   PrintFormat("The Gold Mind: Trade ops skipped (%s) - %s", operation, reason);
}

bool PreTradeGuard(const string operation)
{
   if(IsPositionMgmtAllowed())
      return true;
   WarnAutoTradeBlocked(operation);
   return false;
}

bool PreProtectionTradeGuard(const string operation)
{
   if(IsStrategyTester())
      return true;
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
   {
      WarnAutoTradeBlocked(operation);
      return false;
   }
   if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
   {
      WarnAutoTradeBlocked(operation);
      return false;
   }
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
   {
      WarnAutoTradeBlocked(operation);
      return false;
   }
   const long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
   {
      WarnAutoTradeBlocked(operation);
      return false;
   }
   return true;
}

bool HasOpenBotPositions()
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      return true;
   }
   return false;
}

void ShowAutoTradeSetupWarningIfNeeded()
{
   if(IsPositionMgmtAllowed())
   {
      g_autotradeBoxShown = false;
      return;
   }
   if(g_autotradeBoxShown)
      return;
   g_autotradeBoxShown = true;
   MessageBox("Auto-trading is NOT enabled.\n" + GetAutoTradeBlockReason(),
              "The Gold Mind - Setup Required",
              (int)(MB_OK | MB_ICONWARNING));
}

bool ExecuteTradeOp(const string operation, const bool success, const string context = "")
{
   if(!success)
   {
      const uint retcode = g_trade.ResultRetcode();
      RegisterServerTradePause(retcode, operation);
      if(StringFind(operation, "BE-") >= 0)
      {
         const ulong ticket = ParseTicketFromTradeContext(context);
         if(ticket > 0)
            MarkBreakEvenPending(ticket);
      }
      if(retcode == 10026)
      {
         g_autotradeCooldownUntil = TimeCurrent() + TGM_AUTOTRADE_COOLDOWN_SEC;
         LogTradeFailure(operation, context, retcode,
                         "Auto-trading disabled - enable Algo Trading on toolbar and EA properties.");
      }
      else if(retcode == TGM_RETCODE_MARKET_CLOSED)
      {
         if((TimeCurrent() - g_lastServerPauseLogTime) >= TGM_TRADE_WARN_INTERVAL_SEC)
            PrintFormat("The Gold Mind | %s blocked | retcode=10018 (market closed) | %s",
                        operation, context);
      }
      else
         LogTradeFailure(operation, context, retcode);
   }
   return success;
}

bool SafePositionModify(const ulong ticket, const double sl, const double tp, const string operation)
{
   if(ticket == 0)
   {
      PrintFormat("TGM [SAFE]: %s blocked — ticket #0 (invalid).", operation);
      return false;
   }
   CPositionInfo pos;
   if(!pos.SelectByTicket(ticket))
      return false;
   if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
      return false;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double nSL = (sl > 0.0) ? NormalizeDouble(sl, digits) : 0.0;
   const double nTP = (tp > 0.0) ? NormalizeDouble(tp, digits) : 0.0;
   if(nSL > 0.0 && nTP > 0.0)
   {
      if(pos.PositionType() == POSITION_TYPE_BUY && nSL >= nTP)
      {
         PrintFormat("TGM [SAFE]: %s blocked #%I64u — BUY SL>=TP (sl=%.*f tp=%.*f).",
                     operation, ticket, digits, nSL, digits, nTP);
         return false;
      }
      if(pos.PositionType() == POSITION_TYPE_SELL && nSL <= nTP)
      {
         PrintFormat("TGM [SAFE]: %s blocked #%I64u — SELL SL<=TP (sl=%.*f tp=%.*f).",
                     operation, ticket, digits, nSL, digits, nTP);
         return false;
      }
   }
   return ExecuteTradeOp(operation, g_trade.PositionModify(ticket, nSL, nTP),
                         StringFormat("ticket=%I64u sl=%.*f tp=%.*f", ticket, digits, nSL, digits, nTP));
}

void InitBrokerPointModifier()
{
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   point_modifier = (digits == 3 || digits == 5) ? 10.0 : 1.0;
}

double PriceMoveToBrokerPoints(const double priceMove, const double point)
{
   if(point <= 0.0) return 0.0;
   return priceMove / point;
}

void ShowManualLotWarning()
{
   MessageBox("WARNING — Manual lot sizing is active.\n"
              "Larger lots amplify losses. In adverse moves your account can be wiped out.\n"
              "Click OK only if you fully accept this risk.",
              "The Gold Mind — Risk Warning",
              (int)(MB_OK | MB_ICONWARNING));
}

bool ConfirmManualRiskOverride()
{
   const int res = (int)MessageBox(
      "WARNING — You are changing lot or risk settings.\n"
      "Higher lot sizes can seriously harm your account. "
      "In adverse market moves your balance can be wiped out.\n"
      "Click OK to apply your manual settings, or Cancel to keep safe defaults.",
      "The Gold Mind — Risk Warning",
      (int)(MB_OKCANCEL | MB_ICONWARNING));
   return (res == IDOK);
}

string EffectiveRiskSettingsKey(const string suffix)
{
   return StringFormat("TGM_Risk_%I64d_%u_%s_%s",
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       EXPERT_MAGIC,
                       _Symbol,
                       suffix);
}

bool LoadSavedRiskSettings(int &modeOut, double &manualOut, double &maxOut)
{
   const string kMode   = EffectiveRiskSettingsKey("mode");
   const string kManual = EffectiveRiskSettingsKey("man");
   const string kMax    = EffectiveRiskSettingsKey("max");
   if(!GlobalVariableCheck(kMode))
      return false;
   modeOut   = (int)GlobalVariableGet(kMode);
   manualOut = GlobalVariableGet(kManual);
   maxOut    = GlobalVariableGet(kMax);
   return true;
}

void SaveRiskSettings(const int mode, const double manual, const double max)
{
   GlobalVariableSet(EffectiveRiskSettingsKey("mode"), (double)mode);
   GlobalVariableSet(EffectiveRiskSettingsKey("man"), manual);
   GlobalVariableSet(EffectiveRiskSettingsKey("max"), max);
}

bool RiskInputsChangedFromSaved(const int savedMode, const double savedManual, const double savedMax)
{
   if((int)RiskMode != savedMode)
      return true;
   if(MathAbs(Manual_Lot_Size - savedManual) > 0.001)
      return true;
   if(MathAbs(Max_Lot_Size - savedMax) > 0.001)
      return true;
   return false;
}

bool RiskInputsAreRisky()
{
   return (RiskMode == RISK_MANUAL_LOT);
}

void ApplyEffectiveRiskSettingsFromInputs()
{
   if(IsStrategyTester())
   {
      g_effectiveRiskMode      = RiskMode;
      g_effectiveManualLotSize = Manual_Lot_Size;
      g_effectiveMaxLotSize    = Max_Lot_Size;
      return;
   }
   int    savedMode   = RISK_AUTO_3_PERCENT_EQUITY;
   double savedManual = Manual_Lot_Size;
   double savedMax    = Max_Lot_Size;
   const bool hasSaved = LoadSavedRiskSettings(savedMode, savedManual, savedMax);
   const bool changed = hasSaved &&
                        RiskInputsChangedFromSaved(savedMode, savedManual, savedMax);
   const bool risky   = RiskInputsAreRisky();
   if(ShouldRenderUI() && changed && risky)
   {
      if(!ConfirmManualRiskOverride())
      {
         g_effectiveRiskMode      = (ENUM_RISK_MODE)savedMode;
         g_effectiveManualLotSize = savedManual;
         g_effectiveMaxLotSize    = savedMax;
         Print("TGM [RISK]: Manual change declined — keeping previously accepted settings.");
         return;
      }
      if(RiskMode == RISK_MANUAL_LOT)
         ShowManualLotWarning();
   }
   g_effectiveRiskMode      = RiskMode;
   g_effectiveManualLotSize = Manual_Lot_Size;
   g_effectiveMaxLotSize    = Max_Lot_Size;
   if(ShouldRenderUI())
      SaveRiskSettings((int)RiskMode, Manual_Lot_Size, Max_Lot_Size);
}

void SetFillingMode()
{
   ENUM_ORDER_TYPE_FILLING fill = ORDER_FILLING_FOK;
   long filling = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) fill = ORDER_FILLING_IOC;
   else if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) fill = ORDER_FILLING_FOK;
   else fill = ORDER_FILLING_RETURN;
   g_trade.SetTypeFilling(fill);
}

int CountPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && IsBotGridPendingOrder(ticket))
         count++;
   }
   return count;
}

bool IsBotGridPendingOrder(const ulong orderTicket)
{
   if(orderTicket == 0 || !OrderSelect(orderTicket))
      return false;
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;
   if((long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC)
      return false;
   if(!IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
      return false;
   const string comment = OrderGetString(ORDER_COMMENT);
   return IsGridPositionComment(comment);
}

bool IsPendingOrderType(const ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
}

string GridH4BarStateKey() { return StringFormat("TGM_GridH4_%s_%u_%I64d", _Symbol, EXPERT_MAGIC, AccountInfoInteger(ACCOUNT_LOGIN)); }
datetime GetCurrentH4BarOpenTime() { return iTime(_Symbol, PERIOD_H4, 0); }
datetime LoadGridH4BarTime() { string key = GridH4BarStateKey(); return GlobalVariableCheck(key) ? (datetime)GlobalVariableGet(key) : 0; }
string GridLevelStateKey(const string comment) { return StringFormat("TGM_GridState_%I64u_%s_%s", (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, comment); }
string GridLevelTicketKey(const string comment) { return StringFormat("TGM_GridTicket_%I64u_%s_%s", (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, comment); }
double GetGridLevelState(const string comment) { return GlobalVariableCheck(GridLevelStateKey(comment)) ? GlobalVariableGet(GridLevelStateKey(comment)) : TGM_GRID_LEVEL_IDLE; }
ulong GetGridLevelTicket(const string comment) { return GlobalVariableCheck(GridLevelTicketKey(comment)) ? (ulong)GlobalVariableGet(GridLevelTicketKey(comment)) : 0; }

void ClearGridLevelState(const string comment)
{
   const string stateKey = GridLevelStateKey(comment);
   const string ticketKey = GridLevelTicketKey(comment);
   if(GlobalVariableCheck(stateKey)) GlobalVariableDel(stateKey);
   if(GlobalVariableCheck(ticketKey)) GlobalVariableDel(ticketKey);
}

void SetGridLevelState(const string comment, const double state, const ulong ticket = 0)
{
   GlobalVariableSet(GridLevelStateKey(comment), state);
   if(ticket > 0)
      GlobalVariableSet(GridLevelTicketKey(comment), (double)ticket);
   else
   {
      const string ticketKey = GridLevelTicketKey(comment);
      if(GlobalVariableCheck(ticketKey))
         GlobalVariableDel(ticketKey);
   }
}

void ResetAllGridLevelStates()
{
   string comments[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
      ClearGridLevelState(comments[i]);
   ClearAllLevelBELocksThisH4();
   ClearAllLevelActivationCountsThisH4();
}

bool IsFixedSlReentryMode()
{
   return true;
}

double GetConfiguredStopDistance()
{
   const double pip = Phase17_GetPipSize();
   if(pip > 0.0 && RESEARCH_FIX_SL_PIPS > 0.0)
      return RESEARCH_FIX_SL_PIPS * pip;
   if(pip > 0.0)
      return TGM_RISK_DIST_PIPS * pip;
   return (InpFixedStopLossUSD > 0.0) ? InpFixedStopLossUSD : 5.0;
}

bool GetSharedGridSideStopLoss(const ENUM_POSITION_TYPE side, double &slOut)
{
   slOut = 0.0;
   return false;
}

double GetActiveHedgeTriggerUSD()
{
   return GetConfiguredStopDistance();
}

bool EnsureModeBFixedBrokerSL(const ulong parentTicket)
{
   if(parentTicket == 0)
      return false;
   if(!IsOurBotGridParent(parentTicket))
      return false;
   if(IsProfitEngineArmed(parentTicket))
      return false;
   CPositionInfo pos;
   if(!pos.SelectByTicket(parentTicket))
      return false;
   if(pos.StopLoss() > 0.0)
      return true;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   double targetSL = 0.0;
   if(!GetSharedGridSideStopLoss(pos.PositionType(), targetSL) || targetSL <= 0.0)
   {
      const double slDist = GetConfiguredStopDistance();
      if(slDist <= 0.0)
         return false;
      if(pos.PositionType() == POSITION_TYPE_BUY)
         targetSL = NormalizeDouble(pos.PriceOpen() - slDist, digits);
      else
         targetSL = NormalizeDouble(pos.PriceOpen() + slDist, digits);
   }
   const double stops  = GetSymbolStopsPrice();
   const double liveTP = pos.TakeProfit();
   if(pos.PositionType() == POSITION_TYPE_BUY)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double maxValid = NormalizeDouble(bid - stops - point, digits);
      if(targetSL > maxValid)
         targetSL = maxValid;
      if(targetSL >= bid)
         return false;
   }
   else
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double minValid = NormalizeDouble(ask + stops + point, digits);
      if(targetSL < minValid)
         targetSL = minValid;
      if(targetSL <= ask)
         return false;
   }
   if(IsTradeModifyCooldownActive())
      return false;
   if(!SafePositionModify(parentTicket, targetSL, liveTP, "ModeB-SharedSL"))
      return false;
   PrintFormat("TGM [MODE-B]: Parent #%I64u shared SL restored at %.*f (last+/-%.0fpip).",
               parentTicket, digits, targetSL, TGM_SHARED_SL_BEYOND_LAST_PIPS);
   return true;
}

void CloseStrayHedgesInFixedSlMode()
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      if(!IsBotHedgePosition(pos.Ticket(), pos.Comment()))
         continue;
      CloseHedgePosition(pos.Ticket(), "ModeBNoHedge");
   }
}

string ResolveGridLevelNameFromComment(const string comment)
{
   if(comment == "")
      return "";
   string names[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
   {
      if(StringFind(comment, names[i]) >= 0)
         return names[i];
   }
   return "";
}

int MaxLevelActivationsThisH4()
{
   if(StrictH4CycleOnly())
      return 1;
   return MathMax(1, PHASE18_MAX_LEVEL_ACTIVATIONS_H4);
}

bool StrictH4CycleOnly()
{
   return true;
}

bool IsEmergencyLockThisH4()
{
   if(!Enable_Triple_Protection)
   {
      g_emergencyKillSwitchActive = false;
      return false;
   }
   ClearEmergencyLockIfNewH4();
   const datetime h4 = GetCurrentH4BarOpenTime();
   if(h4 <= 0 || g_emergencyLockH4Open <= 0)
   {
      g_emergencyKillSwitchActive = false;
      return false;
   }
   const bool locked = (g_emergencyLockH4Open == h4);
   g_emergencyKillSwitchActive = locked;
   return locked;
}

void ClearEmergencyLockIfNewH4()
{
   const datetime h4 = GetCurrentH4BarOpenTime();
   if(h4 > 0 && g_emergencyLockH4Open > 0 && g_emergencyLockH4Open != h4)
   {
      PrintFormat("TGM [R441]: Emergency H4-lock cleared on new H4 (was %s).",
                  TimeToString(g_emergencyLockH4Open, TIME_DATE|TIME_MINUTES));
      g_emergencyLockH4Open = 0;
      g_emergencyLockReason = "";
      g_emergencyKillSwitchActive = false;
      const string dayKey = KillSwitchDayKey();
      if(GlobalVariableCheck(dayKey))
         GlobalVariableDel(dayKey);
   }
}

void SetEmergencyLockThisH4(const string reason)
{
   const datetime h4 = GetCurrentH4BarOpenTime();
   g_emergencyLockH4Open = h4;
   g_emergencyLockReason = reason;
   g_emergencyKillSwitchActive = true;
   g_accountProtectionActive = true;
   g_accountProtectionReason = "H4 LOCK: " + reason;
   g_h4PlacementDone = true;
   PrintFormat("TGM [R441]: Emergency lock THIS H4 only (%s) — next placement on next H4 candle.",
               TimeToString(h4, TIME_DATE|TIME_MINUTES));
}

void MarkH4PlacementDone()
{
   g_h4PlacementDone = true;
}

int GridLevelCommentIndex(const string comment)
{
   string names[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
      if(names[i] == comment)
         return i;
   return -1;
}

void MarkPendingClaim(const string comment)
{
   const int idx = GridLevelCommentIndex(comment);
   if(idx >= 0)
      g_pendingClaimTime[idx] = TimeCurrent();
}

void ClearPendingClaim(const string comment)
{
   const int idx = GridLevelCommentIndex(comment);
   if(idx >= 0)
      g_pendingClaimTime[idx] = 0;
}

bool IsStalePendingClaim(const string comment)
{
   const int idx = GridLevelCommentIndex(comment);
   if(idx < 0)
      return true;
   if(g_pendingClaimTime[idx] <= 0)
      return true;
   return ((TimeCurrent() - g_pendingClaimTime[idx]) >= TGM_PENDING_CLAIM_STALE_SEC);
}

bool LevelNeedsPendingRestore(const string comment)
{
   if(comment == "")
      return false;
   if(HasBotPendingByComment(comment))
      return false;
   if(IsCommentActiveInPositions(comment))
      return false;
   if(IsLevelBELockedThisH4(comment) || IsLevelActivationExhaustedThisH4(comment))
      return false;
   if(GetLevelActivationCountThisH4(comment) >= MaxLevelActivationsThisH4())
      return false;
   const double st = GetGridLevelState(comment);
   if(st == TGM_GRID_LEVEL_SPENT || st == TGM_GRID_LEVEL_LIVE)
      return false;
   if(st == TGM_GRID_LEVEL_PENDING && GetGridLevelTicket(comment) == 0 && !IsStalePendingClaim(comment))
      return false;
   return true;
}

bool AnyLevelNeedsPendingRestore()
{
   string comments[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
      if(LevelNeedsPendingRestore(comments[i]))
         return true;
   return false;
}

void HealGhostPendingStates(const string reason)
{
   string comments[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   bool any = false;
   for(int i = 0; i < 6; i++)
   {
      const string comment = comments[i];
      if(GetGridLevelState(comment) != TGM_GRID_LEVEL_PENDING)
         continue;
      if(FindGridPendingTicketByComment(comment) > 0)
         continue;
      if(GetGridLevelTicket(comment) == 0 && !IsStalePendingClaim(comment))
         continue;
      if(IsLevelAlreadySpentInCurrentH4Bar(comment))
      {
         SetGridLevelState(comment, TGM_GRID_LEVEL_SPENT);
         continue;
      }
      ClearGridLevelState(comment);
      ClearPendingClaim(comment);
      any = true;
   }
   if(any)
      PrintFormat("TGM [R444]: Cleared ghost PENDING state(s) (%s).", reason);
}

int MaintainArmedPendings(const string trigger)
{
   if(!StrictH4CycleOnly())
      return 0;
   if(IsEmergencyLockThisH4())
      return 0;
   if(!IsGridOpsAllowed())
      return 0;
   if(!g_h4PlacementDone)
      return 0;
   HealGhostPendingStates(trigger);
   if(!AnyLevelNeedsPendingRestore())
      return 0;
   if(trigger == "OnTick")
   {
      const datetime now = TimeCurrent();
      if(g_lastPendingMaintainTime != 0 && (now - g_lastPendingMaintainTime) < 1)
         return 0;
      g_lastPendingMaintainTime = now;
   }
   if(!IsGridPlacementAllowed(true))
      return 0;
   const int n = ExecuteH4GridStrategy(true);
   if(n > 0)
      PrintFormat("TGM [R444]: Restored %d pending level(s) (%s). pendingNow=%d",
                  n, trigger, CountBotPendings());
   return n;
}

bool LevelHasLivePositionThisH4(const string comment)
{
   const datetime h4 = GetCurrentH4BarOpenTime();
   if(h4 <= 0)
      return false;
   return (FindGridPositionTicketByCommentThisH4(comment, h4) > 0);
}

int CancelPendingOrdersForLevel(const string comment)
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC)
         continue;
      if(!PendingCommentMatchesLevel(OrderGetString(ORDER_COMMENT), comment))
         continue;
      if(ExecuteTradeOp("OrderDelete", g_trade.OrderDelete(ticket),
                        StringFormat("2nd-SL cancel %s ticket=%I64u", comment, ticket)))
         n++;
   }
   if(n > 0)
      ClearGridLevelState(comment);
   return n;
}

string ResolveGridLevelFromClosedDeal(const ulong dealTicket, const string dealComment)
{
   string level = ResolveGridLevelNameFromComment(dealComment);
   if(level != "")
      return level;
   const ulong closeOrder = (ulong)HistoryDealGetInteger(dealTicket, DEAL_ORDER);
   if(closeOrder > 0 && HistoryOrderSelect(closeOrder))
   {
      level = ResolveGridLevelNameFromComment(HistoryOrderGetString(closeOrder, ORDER_COMMENT));
      if(level != "")
         return level;
   }
   const ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   if(posId == 0 || !HistorySelectByPosition((long)posId))
      return "";
   const int n = HistoryDealsTotal();
   for(int d = 0; d < n; d++)
   {
      const ulong t = HistoryDealGetTicket(d);
      if(t == 0)
         continue;
      const long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      level = ResolveGridLevelNameFromComment(HistoryDealGetString(t, DEAL_COMMENT));
      if(level != "")
         break;
      const ulong inOrder = (ulong)HistoryDealGetInteger(t, DEAL_ORDER);
      if(inOrder > 0 && HistoryOrderSelect(inOrder))
      {
         level = ResolveGridLevelNameFromComment(HistoryOrderGetString(inOrder, ORDER_COMMENT));
         if(level != "")
            break;
      }
   }
   HistorySelect(0, TimeCurrent());
   HistoryDealSelect(dealTicket);
   return level;
}

void LogPriceThroughOnce(const string comment, const string reason)
{
   static string logged[6];
   static datetime loggedH4 = 0;
   const datetime h4 = GetCurrentH4BarOpenTime();
   string names[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   int idx = -1;
   for(int i = 0; i < 6; i++)
      if(names[i] == comment) { idx = i; break; }
   if(idx < 0)
      return;
   if(loggedH4 != h4)
   {
      for(int j = 0; j < 6; j++)
         logged[j] = "";
      loggedH4 = h4;
   }
   if(logged[idx] == "PRICE_THROUGH")
      return;
   logged[idx] = "PRICE_THROUGH";
   PrintFormat("TGM [P28-EXEC]: PRICE_THROUGH | %s | %s | acts=%d | h4=%s",
               comment, reason, GetLevelActivationCountThisH4(comment),
               TimeToString(h4, TIME_DATE|TIME_MINUTES));
}

void ProcessModeBLevelExitFromDeal(const ulong dealTicket)
{
   if(!IsFixedSlReentryMode() || dealTicket == 0)
      return;
   if(!HistoryDealSelect(dealTicket))
   {
      HistorySelect(0, TimeCurrent());
      if(!HistoryDealSelect(dealTicket))
         return;
   }
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
      return;
   const long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   if(magic != 0 && magic != EXPERT_MAGIC)
      return;
   const long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;
   string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   if(IsHedgePositionComment(dealComment))
      return;
   string level = ResolveGridLevelFromClosedDeal(dealTicket, dealComment);
   if(!HistoryDealSelect(dealTicket))
   {
      HistorySelect(0, TimeCurrent());
      HistoryDealSelect(dealTicket);
   }
   if(level == "")
      return;
   static ulong seen[32];
   static int seenN = 0;
   for(int s = 0; s < seenN && s < 32; s++)
      if(seen[s] == dealTicket)
         return;
   if(seenN < 32)
      seen[seenN++] = dealTicket;
   else
      seen[dealTicket % 32] = dealTicket;
   const datetime h4 = GetCurrentH4BarOpenTime();
   const ulong liveTicket = (h4 > 0) ? FindGridPositionTicketByCommentThisH4(level, h4) : 0;
   if(liveTicket > 0 && PositionSelectByTicket(liveTicket))
   {
      const double posVol = PositionGetDouble(POSITION_VOLUME);
      const double dealVol = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      if(posVol > dealVol + 1e-8)
         return;
   }
   const ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   const double net = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   if(net > 0.0 || (posId > 0 && IsProfitEngineArmed(posId)))
   {
      if(IsPartialClosedBeRunner(posId) || IsProfitEngineArmed(posId))
         LogPhase28A("RUNNER_SL_CLOSE", posId,
                     StringFormat("level=%s net=%.2f deal_comment=%s", level, net, dealComment));
      MarkLevelBELockedThisH4(level);
      MarkLevelActivationExhaustedThisH4(level);
      SetGridLevelState(level, TGM_GRID_LEVEL_SPENT);
      PrintFormat("TGM [R441]: Level %s PROFIT exit — spent until next H4 (net $%.2f).", level, net);
      return;
   }
   MarkLevelActivationExhaustedThisH4(level);
   MarkLevelBELockedThisH4(level);
   SetGridLevelState(level, TGM_GRID_LEVEL_SPENT);
   const int cancelled = CancelPendingOrdersForLevel(level);
   PrintFormat("TGM [R441]: Level %s SL/LOSS exit — spent until next H4 | PENDING_CANCELLED=%d | net=$%.2f",
               level, cancelled, net);
}

string LevelBELockKey(const string comment)
{
   return StringFormat("TGM_LvlBE_%I64u_%s_%I64d_%s",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       (long)GetCurrentH4BarOpenTime(),
                       comment);
}

string LevelActCountKey(const string comment)
{
   return StringFormat("TGM_LvlAct_%I64u_%s_%I64d_%s",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       (long)GetCurrentH4BarOpenTime(),
                       comment);
}

string LevelActExhaustKey(const string comment)
{
   return StringFormat("TGM_LvlAx_%I64u_%s_%I64d_%s",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       (long)GetCurrentH4BarOpenTime(),
                       comment);
}

int GetLevelActivationCountThisH4(const string comment)
{
   const string key = LevelActCountKey(comment);
   return GlobalVariableCheck(key) ? (int)GlobalVariableGet(key) : 0;
}

void IncrementLevelActivationThisH4(const string comment)
{
   if(comment == "")
      return;
   const int next = GetLevelActivationCountThisH4(comment) + 1;
   GlobalVariableSet(LevelActCountKey(comment), (double)next);
   PrintFormat("TGM [MODE-B]: Level %s activation #%d / %d this H4.",
               comment, next, MaxLevelActivationsThisH4());
   LogPhase28A("POSITION_ENTRY", 0,
               StringFormat("%s activation=%d/%d h4=%s",
                            comment, next, MaxLevelActivationsThisH4(),
                            TimeToString(GetCurrentH4BarOpenTime(), TIME_DATE|TIME_MINUTES)));
}

void ClearAllLevelActivationCountsThisH4()
{
   string comments[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
   {
      const string ck = LevelActCountKey(comments[i]);
      const string ek = LevelActExhaustKey(comments[i]);
      if(GlobalVariableCheck(ck)) GlobalVariableDel(ck);
      if(GlobalVariableCheck(ek)) GlobalVariableDel(ek);
   }
}

bool IsLevelActivationExhaustedThisH4(const string comment)
{
   return (GlobalVariableCheck(LevelActExhaustKey(comment)) &&
           GlobalVariableGet(LevelActExhaustKey(comment)) > 0.5);
}

void MarkLevelActivationExhaustedThisH4(const string comment)
{
   if(comment == "")
      return;
   GlobalVariableSet(LevelActExhaustKey(comment), 1.0);
   SetGridLevelState(comment, TGM_GRID_LEVEL_SPENT);
}

bool IsLevelBELockedThisH4(const string comment)
{
   return (GlobalVariableCheck(LevelBELockKey(comment)) &&
           GlobalVariableGet(LevelBELockKey(comment)) > 0.5);
}

void MarkLevelBELockedThisH4(const string comment)
{
   if(comment == "")
      return;
   GlobalVariableSet(LevelBELockKey(comment), 1.0);
   SetGridLevelState(comment, TGM_GRID_LEVEL_SPENT);
   PrintFormat("TGM [MODE-B]: Level %s LOCKED for this H4 (profit BE hit) — no more re-entries.", comment);
}

void ClearAllLevelBELocksThisH4()
{
   string comments[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
   {
      const string key = LevelBELockKey(comments[i]);
      if(GlobalVariableCheck(key))
         GlobalVariableDel(key);
   }
}

void SaveGridH4BarTime(const datetime barTime)
{
   g_lastH4BarTime = barTime;
   g_historyCacheH4Start = 0;
   GlobalVariableSet(GridH4BarStateKey(), (double)barTime);
}

bool IsNewH4GridPeriod()
{
   datetime currentH4 = GetCurrentH4BarOpenTime();
   if(currentH4 <= 0) return false;
   if(g_lastH4BarTime <= 0) g_lastH4BarTime = LoadGridH4BarTime();
   return (g_lastH4BarTime != currentH4);
}

int CountBotPendingByComment(const string comment)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC)
         continue;
      if(!IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(PendingCommentMatchesLevel(OrderGetString(ORDER_COMMENT), comment))
         count++;
   }
   return count;
}

bool IsCommentActiveInPositions(const string comment)
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i) && pos.Symbol() == _Symbol && pos.Magic() == (ulong)EXPERT_MAGIC)
      {
         if(StringFind(pos.Comment(), comment) >= 0) return true;
      }
   }
   return false;
}

bool IsLevelAlreadySpentInCurrentH4Bar(const string comment)
{
   if(IsFixedSlReentryMode())
      return (IsLevelBELockedThisH4(comment) || IsLevelActivationExhaustedThisH4(comment) ||
              GetLevelActivationCountThisH4(comment) >= MaxLevelActivationsThisH4());
   datetime currentH4Start = GetCurrentH4BarOpenTime();
   if(currentH4Start <= 0) return false;
   g_historyCacheH4Start  = currentH4Start;
   g_historyCacheSelectOk = HistorySelect(currentH4Start, TimeCurrent());
   if(!g_historyCacheSelectOk) return false;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == EXPERT_MAGIC)
         {
            string dealComment = HistoryDealGetString(ticket, DEAL_COMMENT);
            if(StringFind(dealComment, comment) >= 0) return true;
         }
      }
   }
   return false;
}

void CloseAllBotPositionsForced(const string reason)
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(IsStopped()) return;
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC) continue;
      const ulong ticket = pos.Ticket();
      const double pts = GetTicketProfitPoints(ticket, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
      PrintFormat("The Gold Mind: Force-close #%I64u (%s) reason=%s | profit=%.0f broker pts",
                  ticket,
                  (pos.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                  reason,
                  pts);
      const string op = (StringFind(reason, "Kill") >= 0 || StringFind(reason, "Flatten") >= 0 ||
                         StringFind(reason, "Gap") >= 0)
                        ? "ForceFlattenClose" : "PositionClose";
      if(!ExecuteTradeOp(op, g_trade.PositionClose(ticket),
                         StringFormat("ticket=%I64u reason=%s", ticket, reason)))
         g_forceFlattenActive = true;
   }
}

string EaBuildVersionKey()
{
   return StringFormat("TGM_Build_%I64u_%s",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol);
}

void RecordEaBuildSerial()
{
   const string key = EaBuildVersionKey();
   const int prevBuild = GlobalVariableCheck(key) ? (int)GlobalVariableGet(key) : 0;
   GlobalVariableSet(key, (double)TGM_BUILD_SERIAL);
   if(prevBuild > 0 && prevBuild != TGM_BUILD_SERIAL)
      PrintFormat("The Gold Mind: Build %d -> %d (existing trades NOT closed).", prevBuild, TGM_BUILD_SERIAL);
}

bool IsGridEntryPriceBlocked(const double entryPrice)
{
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double normEntry = NormalizeDouble(entryPrice, digits);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return false;
   const double tolerance = point * 10.0;
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC) continue;
      if(MathAbs(pos.PriceOpen() - normEntry) <= tolerance) return true;
   }
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      ulong ticket = OrderGetTicket(j);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || (long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC) continue;
      if(!IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE))) continue;
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - normEntry) <= tolerance) return true;
   }
   return false;
}

bool PendingCommentMatchesLevel(const string orderComment, const string levelComment)
{
   if(levelComment == "")
      return false;
   if(orderComment == levelComment)
      return true;
   if(orderComment != "" && StringFind(orderComment, levelComment) >= 0)
      return true;
   return (ResolveGridLevelNameFromComment(orderComment) == levelComment);
}

int CancelDuplicatePendingsAtSamePrice()
{
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0;
   const double tolerance = point * 10.0;
   int removed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      const ulong ticketA = OrderGetTicket(i);
      if(ticketA == 0 || !OrderSelect(ticketA))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC)
         continue;
      if(!IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(!IsGridPositionComment(OrderGetString(ORDER_COMMENT)) &&
         ResolveGridLevelNameFromComment(OrderGetString(ORDER_COMMENT)) == "")
         continue;
      const double priceA = NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN), digits);
      const ENUM_ORDER_TYPE typeA = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      for(int j = i - 1; j >= 0; j--)
      {
         const ulong ticketB = OrderGetTicket(j);
         if(ticketB == 0 || !OrderSelect(ticketB))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC)
            continue;
         if(!IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
            continue;
         if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != typeA)
            continue;
         const double priceB = NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN), digits);
         if(MathAbs(priceA - priceB) > tolerance)
            continue;
         const ulong kill = (ticketA > ticketB) ? ticketA : ticketB;
         const string killComment = OrderSelect(kill) ? OrderGetString(ORDER_COMMENT) : "";
         if(ExecuteTradeOp("OrderDelete", g_trade.OrderDelete(kill),
                           StringFormat("DUP_PRICE cancel ticket=%I64u @ %.*f comment=%s",
                                        kill, digits, priceA, killComment)))
         {
            removed++;
            PrintFormat("TGM [DEDUP]: Removed duplicate pending #%I64u at %.*f (kept older twin).",
                        kill, digits, priceA);
         }
         break;
      }
   }
   return removed;
}

void CleanupEAChartVisuals()
{
   DeleteAllGridChartObjects();
   DestroyAllChartDashboardUI();
   Comment("");
   ChartRedraw(ChartID());
}

bool HasBotPendingByComment(const string comment) { return (CountBotPendingByComment(comment) > 0); }

ulong FindGridPendingTicketByComment(const string comment)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != EXPERT_MAGIC)
         continue;
      if(!IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(PendingCommentMatchesLevel(OrderGetString(ORDER_COMMENT), comment))
         return ticket;
   }
   return 0;
}

bool PositionMatchesGridComment(const ulong positionTicket, const string comment)
{
   CPositionInfo pos;
   if(!pos.SelectByTicket(positionTicket))
      return false;
   if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
      return false;
   if(!WasOpenedAsGridLimit(positionTicket))
      return false;
   if(pos.Comment() == comment)
      return true;
   string dealComment = "";
   string orderComment = "";
   if(!GetPositionOpeningComments(positionTicket, dealComment, orderComment))
      return false;
   return (dealComment == comment || orderComment == comment);
}

ulong FindGridPositionTicketByCommentThisH4(const string comment, const datetime currentH4)
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      if((datetime)pos.Time() < currentH4)
         continue;
      if(PositionMatchesGridComment(pos.Ticket(), comment))
         return pos.Ticket();
   }
   return 0;
}

void SynchronizeGridLevelStates(const string reason)
{
   const datetime currentH4 = GetCurrentH4BarOpenTime();
   if(currentH4 <= 0)
      return;
   CancelDuplicatePendingsAtSamePrice();
   bool anyChange = false;
   string comments[6] = {"GM_BL1","GM_BL2","GM_BL3","GM_SL1","GM_SL2","GM_SL3"};
   for(int i = 0; i < 6; i++)
   {
      const string comment = comments[i];
      const double oldState = GetGridLevelState(comment);
      const ulong oldTicket = GetGridLevelTicket(comment);
      const ulong pendingTicket = FindGridPendingTicketByComment(comment);
      if(pendingTicket > 0)
      {
         if(oldState != TGM_GRID_LEVEL_PENDING || oldTicket != pendingTicket)
            anyChange = true;
         SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, pendingTicket);
         continue;
      }
      if(oldState == TGM_GRID_LEVEL_PENDING && oldTicket == 0)
      {
         if(!IsStalePendingClaim(comment))
            continue;
         ClearGridLevelState(comment);
         ClearPendingClaim(comment);
         anyChange = true;
      }
      const ulong liveTicket = FindGridPositionTicketByCommentThisH4(comment, currentH4);
      if(liveTicket > 0)
      {
         if(oldState != TGM_GRID_LEVEL_LIVE || oldTicket != liveTicket)
         {
            anyChange = true;
            if(IsFixedSlReentryMode() &&
               (oldState != TGM_GRID_LEVEL_LIVE || oldTicket != liveTicket))
               IncrementLevelActivationThisH4(comment);
            SetGridLevelState(comment, TGM_GRID_LEVEL_LIVE, liveTicket);
            SeedHedgeMonitorForParent(liveTicket);
         }
         continue;
      }
      if(IsLevelAlreadySpentInCurrentH4Bar(comment))
      {
         if(oldState != TGM_GRID_LEVEL_SPENT)
            anyChange = true;
         SetGridLevelState(comment, TGM_GRID_LEVEL_SPENT);
         continue;
      }
      if(oldState != TGM_GRID_LEVEL_IDLE || oldTicket != 0)
         anyChange = true;
      ClearGridLevelState(comment);
   }
   if(anyChange || reason == "OnInit")
      PrintFormat("TGM [SYNC]: Grid state healed (%s) for H4 bar %s.",
                  reason, TimeToString(currentH4, TIME_DATE|TIME_MINUTES));
}

void SynchronizePersistentState(const string reason)
{
   if(!IsGoldChartSymbol())
      return;
   CleanDeadGlobalVariables();
   SynchronizeGridLevelStates(reason);
}

void ForceRebuildCurrentGrid(const string trigger)
{
   if(!EnsureAllBotPendingDeleted()) return;
   ResetAllGridLevelStates();
   ExecuteH4GridStrategy(true);
   SaveGridH4BarTime(GetCurrentH4BarOpenTime());
}

bool MaybeForceRebuildCurrentH4IfEmpty(const string trigger)
{
   if(StrictH4CycleOnly())
      return false;
   const datetime currentH4 = GetCurrentH4BarOpenTime();
   if(currentH4 <= 0)
      return false;
   if(g_lastEmptyGridRebuildH4 == currentH4)
      return false;
   if(CountPendingOrders() > 0 || HasOpenBotPositions())
      return false;
   g_lastEmptyGridRebuildH4 = currentH4;
   PrintFormat("TGM [SYNC]: Empty bot book on current H4 -> force rebuild (%s).", trigger);
   ForceRebuildCurrentGrid(trigger);
   return true;
}

bool EnsureAllBotPendingDeletedForced()
{
   int safetyIterations = 0;
   while(CountPendingOrders() > 0)
   {
      if(safetyIterations++ > CLEANUP_MAX_ITERATIONS)
      {
         Print("The Gold Mind: Forced pending-order cleanup exceeded max iterations. GetLastError=", GetLastError());
         return false;
      }
      if(IsStopped()) return false;
      bool deletedAny = false;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket > 0 && IsBotGridPendingOrder(ticket))
         {
            const string comment = OrderGetString(ORDER_COMMENT);
            if(ExecuteTradeOp("OrderDelete", g_trade.OrderDelete(ticket), StringFormat("ticket=%I64u", ticket)))
            {
               ClearGridLevelState(comment);
               deletedAny = true;
            }
         }
      }
      if(!deletedAny && CountPendingOrders() > 0)
         break;
      if(!IsStrategyTester())
         Sleep(CLEANUP_SLEEP_MS);
   }
   return (CountPendingOrders() == 0);
}

bool EnsureAllBotPendingDeleted()
{
   if(!PreTradeGuard("OrderDelete"))
      return false;
   int safetyIterations = 0;
   while(CountPendingOrders() > 0)
   {
      if(safetyIterations++ > CLEANUP_MAX_ITERATIONS)
      {
         Print("The Gold Mind: Pending-order cleanup exceeded max iterations. GetLastError=", GetLastError());
         return false;
      }
      if(IsStopped()) return false;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         const ulong ticket = OrderGetTicket(i);
         if(ticket > 0 && OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol && (long)OrderGetInteger(ORDER_MAGIC) == EXPERT_MAGIC)
         {
            if(!IsBotGridPendingOrder(ticket))
               continue;
            const string comment = OrderGetString(ORDER_COMMENT);
            if(!ExecuteTradeOp("OrderDelete", g_trade.OrderDelete(ticket), StringFormat("ticket=%I64u", ticket)))
            {
               const uint retcode = g_trade.ResultRetcode();
               if(retcode == TGM_RETCODE_MARKET_CLOSED || retcode == 10026 || IsServerTradePaused() || IsWeekendOrMarketClosed())
                  return false;
               break;
            }
            ClearGridLevelState(comment);
         }
      }
      if(!IsStrategyTester())
         Sleep(CLEANUP_SLEEP_MS);
   }
   return true;
}

void RefreshGridOnNewH4Bar(const string trigger)
{
   ClearEmergencyLockIfNewH4();
   g_h4PlacementDone = false;
   g_lastEmptyGridRebuildH4 = 0;
   if(!EnsureAllBotPendingDeleted())
      return;
   ResetAllGridLevelStates();
   LogPhase28A("H4_RESET", 0, StringFormat("trigger=%s acts=0 strict=%s",
                                           trigger, (StrictH4CycleOnly() ? "yes" : "no")));
   if(IsEmergencyLockThisH4())
   {
      Print("TGM [R441]: New H4 but emergency lock still set — skip placement.");
      return;
   }
   ExecuteH4GridStrategy(true);
   MarkH4PlacementDone();
   SaveGridH4BarTime(GetCurrentH4BarOpenTime());
}

bool CreateOrUpdateGridHLine(const long chart_id, const string object_name, const double price, const color line_color)
{
   if(price <= 0.0) return false;
   if(ObjectFind(chart_id, object_name) < 0)
   {
      ObjectCreate(chart_id, object_name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(chart_id, object_name, OBJPROP_STYLE, STYLE_DOT);
   }
   ObjectSetDouble(chart_id, object_name, OBJPROP_PRICE, price);
   ObjectSetInteger(chart_id, object_name, OBJPROP_TIMEFRAMES, 0);
   return true;
}

void DeleteAllGridChartObjects()
{
   long chart_id = ChartID();
   for(int i = ObjectsTotal(chart_id, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(chart_id, i, 0, -1);
      if(StringFind(name, GRID_LINE_PREFIX) == 0) ObjectDelete(chart_id, name);
   }
   ChartRedraw(chart_id);
}

void UpdateGridChartLines(const double high1, const double low1, const double pivot, const double buy1, const double buy2, const double buy3, const double sell1, const double sell2, const double sell3)
{
   long chart_id = ChartID(); string p = GRID_LINE_PREFIX;
   CreateOrUpdateGridHLine(chart_id, p + "HIGH",  high1, clrSilver);
   CreateOrUpdateGridHLine(chart_id, p + "LOW",   low1,  clrSilver);
   CreateOrUpdateGridHLine(chart_id, p + "PIVOT", pivot, clrGold);
   CreateOrUpdateGridHLine(chart_id, p + "BUY1",  buy1,  clrDodgerBlue);
   CreateOrUpdateGridHLine(chart_id, p + "BUY2",  buy2,  clrDodgerBlue);
   CreateOrUpdateGridHLine(chart_id, p + "BUY3",  buy3,  clrDodgerBlue);
   CreateOrUpdateGridHLine(chart_id, p + "SELL1", sell1, clrOrangeRed);
   CreateOrUpdateGridHLine(chart_id, p + "SELL2", sell2, clrOrangeRed);
   CreateOrUpdateGridHLine(chart_id, p + "SELL3", sell3, clrOrangeRed);
   ChartRedraw(chart_id);
}

bool CalculateH4GridLevels(double &high1, double &low1, double &pivot, double &buy1, double &buy2, double &buy3, double &sell1, double &sell2, double &sell3)
{
   high1 = iHigh(_Symbol, PERIOD_H4, 1); low1 = iLow(_Symbol, PERIOD_H4, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || high1 <= low1) return false;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double diff = high1 - low1;
   pivot = NormalizeDouble((high1 + low1) / 2.0, digits);
   buy1  = NormalizeDouble(low1  - (diff * 0.20), digits);
   buy2  = NormalizeDouble(low1  - (diff * 0.58), digits);
   buy3  = NormalizeDouble(low1  - (diff * 0.92), digits);
   sell1 = NormalizeDouble(high1 + (diff * 0.20), digits);
   sell2 = NormalizeDouble(high1 + (diff * 0.58), digits);
   sell3 = NormalizeDouble(high1 + (diff * 0.92), digits);
   return true;
}

bool ResearchApplyDirectionalCyclePlan(const double rangePips)
{
   g_dirEnableBuyArm      = false;
   g_dirEnableSellArm     = false;
   g_dirBreakoutPlacement = false;
   const datetime h4Open = iTime(_Symbol, PERIOD_H4, 0);
   STgmRouterDecision d;
   const bool ok = g_unifiedRouter.EvaluateForH4Cycle(h4Open, rangePips, d);
   g_lastRouterDecision = d;
   if(!ok)
      return false;
   g_dirEnableBuyArm      = d.armBuyLoop;
   g_dirEnableSellArm     = d.armSellLoop;
   g_dirBreakoutPlacement = d.breakoutPlacement;
   return (g_dirEnableBuyArm || g_dirEnableSellArm);
}

bool ResearchInvertedUsesBreakoutPlacement()
{
   return false;
}

bool ResearchInvertedSlTpFor(const bool placingBuy, const double entry,
                             const int levelIndex,
                             double &slOut, double &tpOut, double &lotDistOut)
{
   if(entry <= 0.0)
      return false;
   const double pip = Phase17_GetPipSize();
   if(pip <= 0.0)
      return false;
   double slPips = RESEARCH_FIX_SL_PIPS;
   const double perLevel[3] = {RESEARCH_INV_TP_L1_PIPS,
                               RESEARCH_INV_TP_L2_PIPS,
                               RESEARCH_INV_TP_L3_PIPS};
   if(levelIndex >= 0 && levelIndex <= 2 && perLevel[levelIndex] > 0.0)
      slPips = perLevel[levelIndex];
   if(slPips <= 0.0)
      return false;
   const double rr = (RESEARCH_RR_TP_MULT > 0.0) ? RESEARCH_RR_TP_MULT : 1.5;
   const double tpPips = slPips * rr;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double slDist = slPips * pip;
   const double tpDist = tpPips * pip;
   slOut      = NormalizeDouble(placingBuy ? (entry - slDist) : (entry + slDist), digits);
   tpOut      = NormalizeDouble(placingBuy ? (entry + tpDist) : (entry - tpDist), digits);
   lotDistOut = slDist;
   return true;
}

bool ResearchLevelEnabled(const int levelIndex)
{
   if(levelIndex < 0 || levelIndex > 2)
      return false;
   if(RESEARCH_LEVEL_MASK <= 0)
      return true;
   return ((RESEARCH_LEVEL_MASK & (1 << levelIndex)) != 0);
}

bool ResearchCycleAllowed()
{
   if(StringLen(RESEARCH_CYCLES) == 0)
      return true;
   const datetime h4 = GetCurrentH4BarOpenTime();
   if(h4 <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(h4, dt);
   const int cycle = dt.hour - (dt.hour % 4);
   string parts[];
   const int n = StringSplit(RESEARCH_CYCLES, ',', parts);
   for(int i = 0; i < n; i++)
   {
      if(StringLen(parts[i]) == 0)
         continue;
      const int wanted = (int)StringToInteger(parts[i]);
      if(wanted - (wanted % 4) == cycle)
         return true;
   }
   return false;
}

bool CalculateExcelGridSLTP(const double buy1, const double buy2, const double buy3, const double sell1, const double sell2, const double sell3, const double atrValue, double &buySL, double &sellSL, double &buyTP1, double &buyTP2, double &buyTP3, double &sellTP1, double &sellTP2, double &sellTP3)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = Phase17_GetPipSize();
   if(pip <= 0.0)
      return false;
   if(atrValue <= 0.0)
      return false;
   buySL  = NormalizeDouble(buy3  - (TGM_SHARED_SL_BEYOND_LAST_PIPS * pip), digits);
   sellSL = NormalizeDouble(sell3 + (TGM_SHARED_SL_BEYOND_LAST_PIPS * pip), digits);
   const double tpDist = atrValue * TP_ATR_Multiplier;
   if(tpDist <= 0.0)
      return false;
   buyTP1  = NormalizeDouble(buy1 + tpDist, digits);
   buyTP2  = NormalizeDouble(buy2 + tpDist, digits);
   buyTP3  = NormalizeDouble(buy3 + tpDist, digits);
   sellTP1 = NormalizeDouble(sell1 - tpDist, digits);
   sellTP2 = NormalizeDouble(sell2 - tpDist, digits);
   sellTP3 = NormalizeDouble(sell3 - tpDist, digits);
   return (buySL > 0.0 && sellSL > 0.0);
}

void RefreshGridChartLinesFromH4()
{
   double high1, low1, pivot, buy1, buy2, buy3, sell1, sell2, sell3;
   if(CalculateH4GridLevels(high1, low1, pivot, buy1, buy2, buy3, sell1, sell2, sell3))
      UpdateGridChartLines(high1, low1, pivot, buy1, buy2, buy3, sell1, sell2, sell3);
}

int ExecuteH4GridStrategy(const bool freshH4Cycle = false)
{
   if(IsEmergencyLockThisH4())
      return 0;
   if(StrictH4CycleOnly() && g_h4PlacementDone && !freshH4Cycle)
      return 0;
   if(!IsGridPlacementAllowed(freshH4Cycle))
      return 0;
   if(!ResearchCycleAllowed())
      return 0;
   if(g_gridStrategyBusy)
      return 0;
   g_gridStrategyBusy = true;
   int placedCount = 0;
   double atrValue = 0.0;
   if(!GetLiveATR(atrValue))
   {
      g_gridStrategyBusy = false;
      return 0;
   }
   double high1, low1, pivot, buy1, buy2, buy3, sell1, sell2, sell3;
   if(!CalculateH4GridLevels(high1, low1, pivot, buy1, buy2, buy3, sell1, sell2, sell3))
   {
      g_gridStrategyBusy = false;
      return 0;
   }
   if(ShouldRenderUI())
      UpdateGridChartLines(high1, low1, pivot, buy1, buy2, buy3, sell1, sell2, sell3);
   const double pipSize = Phase17_GetPipSize();
   double rangePips = 0.0;
   if(pipSize > 0.0)
      rangePips = (high1 - low1) / pipSize;
   if(pipSize <= 0.0)
   {
      g_gridStrategyBusy = false;
      return 0;
   }
   if(!ResearchApplyDirectionalCyclePlan(rangePips))
   {
      g_gridStrategyBusy = false;
      return 0;
   }
   const bool armBuyLoop  = g_dirEnableBuyArm && (TradeDirection == DIR_BOTH || TradeDirection == DIR_BUY);
   const bool armSellLoop = g_dirEnableSellArm && (TradeDirection == DIR_BOTH || TradeDirection == DIR_SELL);
   double buySL, sellSL, buyTP1, buyTP2, buyTP3, sellTP1, sellTP2, sellTP3;
   if(!CalculateExcelGridSLTP(buy1, buy2, buy3, sell1, sell2, sell3, atrValue, buySL, sellSL, buyTP1, buyTP2, buyTP3, sellTP1, sellTP2, sellTP3))
   {
      g_gridStrategyBusy = false;
      return 0;
   }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double buyLotDist  = MathAbs(buy1 - buySL);
   const double sellLotDist = MathAbs(sellSL - sell1);
   double buyEntries[3] = {buy1, buy2, buy3};
   double buyTPs[3]     = {buyTP1, buyTP2, buyTP3};
   string buyComments[3]= {"GM_BL1", "GM_BL2", "GM_BL3"};
   for(int b = 0; armBuyLoop && b < 3; b++)
   {
      if(!ResearchLevelEnabled(b))
         continue;
      if(!LiveSafeAllowsNewPending(b))
         continue;
      const double entry_price   = buyEntries[b];
      double       calculated_SL = buySL;
      double       tp            = buyTPs[b];
      const string comment       = buyComments[b];
      double       slDistLots    = buyLotDist;
      if(!ResearchInvertedSlTpFor(!ResearchInvertedUsesBreakoutPlacement(), entry_price, b,
                                  calculated_SL, tp, slDistLots))
         continue;
      const double levelState = GetGridLevelState(comment);
      if(HasBotPendingByComment(comment) || levelState == TGM_GRID_LEVEL_PENDING) continue;
      if(levelState == TGM_GRID_LEVEL_LIVE && LevelHasLivePositionThisH4(comment)) continue;
      if(levelState == TGM_GRID_LEVEL_SPENT) continue;
      if(IsLevelBELockedThisH4(comment) || IsLevelActivationExhaustedThisH4(comment)) continue;
      if(GetLevelActivationCountThisH4(comment) >= MaxLevelActivationsThisH4()) continue;
      if(!Phase17_AllowReArm(GetLevelActivationCountThisH4(comment))) continue;
      if(IsGridEntryPriceBlocked(entry_price)) continue;
      if(ResearchInvertedUsesBreakoutPlacement() ? (calculated_SL <= entry_price) : (calculated_SL >= entry_price)) continue;
      if(slDistLots <= 0.0) continue;
      if(ResearchInvertedUsesBreakoutPlacement())
      {
         if(bid > entry_price)
         {
            if(PlaceSellStop(entry_price, calculated_SL, tp, slDistLots, b, comment)) placedCount++;
         }
         else
         {
            LogPriceThroughOnce(comment,
                                StringFormat("STOP_INVALID_PRICE_THROUGH SELLSTOP bid=%.3f <= level=%.3f WAIT",
                                             bid, entry_price));
         }
      }
      else if(ask > entry_price)
      {
         if(PlaceBuyLimit(entry_price, calculated_SL, tp, slDistLots, b, comment)) placedCount++;
      }
      else
      {
         LogPriceThroughOnce(comment,
                             StringFormat("LIMIT_INVALID_PRICE_THROUGH BUY ask=%.3f <= level=%.3f WAIT_FOR_VALID_LIMIT",
                                          ask, entry_price));
      }
   }
   double sellEntries[3] = {sell1, sell2, sell3};
   double sellTPs[3]     = {sellTP1, sellTP2, sellTP3};
   string sellComments[3]= {"GM_SL1", "GM_SL2", "GM_SL3"};
   for(int s = 0; armSellLoop && s < 3; s++)
   {
      if(!ResearchLevelEnabled(s))
         continue;
      if(!LiveSafeAllowsNewPending(s))
         continue;
      const double entry_price   = sellEntries[s];
      double       calculated_SL = sellSL;
      double       tp            = sellTPs[s];
      const string comment       = sellComments[s];
      double       slDistLots    = sellLotDist;
      if(!ResearchInvertedSlTpFor(ResearchInvertedUsesBreakoutPlacement(), entry_price, s,
                                  calculated_SL, tp, slDistLots))
         continue;
      const double levelState = GetGridLevelState(comment);
      if(HasBotPendingByComment(comment) || levelState == TGM_GRID_LEVEL_PENDING) continue;
      if(levelState == TGM_GRID_LEVEL_LIVE && LevelHasLivePositionThisH4(comment)) continue;
      if(levelState == TGM_GRID_LEVEL_SPENT) continue;
      if(IsLevelBELockedThisH4(comment) || IsLevelActivationExhaustedThisH4(comment)) continue;
      if(GetLevelActivationCountThisH4(comment) >= MaxLevelActivationsThisH4()) continue;
      if(!Phase17_AllowReArm(GetLevelActivationCountThisH4(comment))) continue;
      if(IsGridEntryPriceBlocked(entry_price)) continue;
      if(ResearchInvertedUsesBreakoutPlacement() ? (calculated_SL >= entry_price) : (calculated_SL <= entry_price)) continue;
      if(slDistLots <= 0.0) continue;
      if(ResearchInvertedUsesBreakoutPlacement())
      {
         if(ask < entry_price)
         {
            if(PlaceBuyStop(entry_price, calculated_SL, tp, slDistLots, s, comment)) placedCount++;
         }
         else
         {
            LogPriceThroughOnce(comment,
                                StringFormat("STOP_INVALID_PRICE_THROUGH BUYSTOP ask=%.3f >= level=%.3f WAIT",
                                             ask, entry_price));
         }
      }
      else if(bid < entry_price)
      {
         if(PlaceSellLimit(entry_price, calculated_SL, tp, slDistLots, s, comment)) placedCount++;
      }
      else
      {
         LogPriceThroughOnce(comment,
                             StringFormat("LIMIT_INVALID_PRICE_THROUGH SELL bid=%.3f >= level=%.3f WAIT_FOR_VALID_LIMIT",
                                          bid, entry_price));
      }
   }
   g_gridStrategyBusy = false;
   return placedCount;
}

bool GetLiveATR(double &atrOut)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, buf) != 1)
   {
      Print("The Gold Mind: CopyBuffer(iATR) failed. GetLastError=", GetLastError());
      return false;
   }
   atrOut = buf[0];
   return (atrOut > 0.0);
}

double GetLotSizingCapital()
{
   double cap = AccountInfoDouble(ACCOUNT_EQUITY);
   if(cap > 0.0)
      return cap;
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

double CalculateAutoLotSize(const double slDistancePrice, const int levelIndex)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || slDistancePrice <= 0.0) return 0.01;
   double slPoints = slDistancePrice / point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(slPoints <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0) return 0.01;
   double equity = GetLotSizingCapital();
   if(equity <= 0.0)
      return 0.01;
   const double riskAmount = equity * (InpRiskPercent/100.0);
   double pointsValue = (point / tickSize) * tickValue;
   double lots = riskAmount / (slPoints * pointsValue);
   return NormalizeVolume(lots);
}

double GetTradeVolume(const double slDistancePrice, const int levelIndex)
{
   double lots = (g_effectiveRiskMode == RISK_MANUAL_LOT) ? NormalizeVolume(g_effectiveManualLotSize) : CalculateAutoLotSize(slDistancePrice, levelIndex);
   lots *= Phase17_GetLotExposureMultiplier();
   return NormalizeVolume(lots);
}

double NormalizeVolume(double volume)
{
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(g_effectiveMaxLotSize > 0.0 && g_effectiveMaxLotSize < vmax)
      vmax = g_effectiveMaxLotSize;
   volume = MathFloor(volume / vstep) * vstep;
   return NormalizeDouble(MathMax(vmin, MathMin(vmax, volume)), 2);
}

void LogLotCalculationDetail(const string tag, const string comment, const int levelIndex, const double slDistancePrice, const double finalLots)
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double equity = GetLotSizingCapital();
   double slPoints = 0.0;
   double pointsValue = 0.0;
   double rawLots = 0.0;
   if(point > 0.0 && tickSize > 0.0 && tickValue > 0.0 && slDistancePrice > 0.0)
   {
      slPoints = slDistancePrice / point;
      pointsValue = (point / tickSize) * tickValue;
      if(slPoints > 0.0 && pointsValue > 0.0 && equity > 0.0)
         rawLots = (equity * (InpRiskPercent/100.0)) / (slPoints * pointsValue);
   }
   const double ddMult = Phase17_GetLotExposureMultiplier();
   const double ddLots = NormalizeVolume(rawLots * ddMult);
   const double slPips = slDistancePrice / 0.10;
   const double riskAmount = equity * (InpRiskPercent/100.0);
   PrintFormat("TGM [LOTDBG]: %s %s L%d | balance=%.2f risk$=%.2f sl_price=%.3f sl_pips=%.1f raw=%.4f dd_mult=%.2f dd_lots=%.2f final=%.2f",
               tag, comment, levelIndex + 1, equity, riskAmount, slDistancePrice, slPips, rawLots, ddMult, ddLots, finalLots);
}

bool PlaceBuyLimit(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment)
{
   if(!PreTradeGuard("BuyLimit"))
      return false;
   if(!GmP11B_AllowPlacement(comment, levelIndex))
      return false;
   if(IsGridEntryPriceBlocked(price) || HasBotPendingByComment(comment) ||
      GetGridLevelState(comment) == TGM_GRID_LEVEL_PENDING)
   {
      PrintFormat("TGM [DEDUP]: Skip BuyLimit %s @ %s — level/price already armed.",
                  comment, DoubleToString(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      return false;
   }
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double lots = GmP11B_AdjustLot(GetTradeVolume(slDistForLots, levelIndex), levelIndex, comment, true);
   const bool attachSL = (sl > 0.0);
   double orderSL = attachSL ? NormalizeDouble(sl, digits) : 0.0;
   double orderTP = NormalizeDouble(tp, digits);
   if(!GmP14_ValidateBeforeOrderSend(true, price, orderSL, orderTP, comment, levelIndex))
      return false;
   LogLotCalculationDetail("BuyLimit", comment, levelIndex, slDistForLots, lots);
   SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, 0);
   MarkPendingClaim(comment);
   bool ok = g_trade.BuyLimit(lots, price, _Symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment);
   const bool placed = ExecuteTradeOp("BuyLimit", ok, StringFormat("comment=%s lots=%.2f price=%.*f", comment, lots, digits, price));
   if(placed)
   {
      SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, g_trade.ResultOrder());
      ClearPendingClaim(comment);
      GmP11B_RegisterPlaced(g_trade.ResultOrder(), comment, levelIndex);
   }
   else
   {
      ClearGridLevelState(comment);
      ClearPendingClaim(comment);
   }
   return placed;
}

bool PlaceBuyStop(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment)
{
   if(!PreTradeGuard("BuyStop"))
      return false;
   if(!GmP11B_AllowPlacement(comment, levelIndex))
      return false;
   if(IsGridEntryPriceBlocked(price) || HasBotPendingByComment(comment) ||
      GetGridLevelState(comment) == TGM_GRID_LEVEL_PENDING)
      return false;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double lots = GmP11B_AdjustLot(GetTradeVolume(slDistForLots, levelIndex), levelIndex, comment, true);
   const bool attachSL = (sl > 0.0);
   double orderSL = attachSL ? NormalizeDouble(sl, digits) : 0.0;
   double orderTP = NormalizeDouble(tp, digits);
   if(!GmP14_ValidateBeforeOrderSend(true, price, orderSL, orderTP, comment, levelIndex))
      return false;
   LogLotCalculationDetail("BuyStop", comment, levelIndex, slDistForLots, lots);
   SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, 0);
   MarkPendingClaim(comment);
   bool ok = g_trade.BuyStop(lots, price, _Symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment);
   const bool placed = ExecuteTradeOp("BuyStop", ok, StringFormat("comment=%s lots=%.2f price=%.*f REARM", comment, lots, digits, price));
   if(placed)
   {
      SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, g_trade.ResultOrder());
      ClearPendingClaim(comment);
      GmP11B_RegisterPlaced(g_trade.ResultOrder(), comment, levelIndex);
      PrintFormat("TGM [REARM]: BUY STOP %s @ %.*f (price was at/below level after SL).", comment, digits, price);
   }
   else
   {
      ClearGridLevelState(comment);
      ClearPendingClaim(comment);
   }
   return placed;
}

bool PlaceSellLimit(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment)
{
   if(!PreTradeGuard("SellLimit"))
      return false;
   if(!GmP11B_AllowPlacement(comment, levelIndex))
      return false;
   if(IsGridEntryPriceBlocked(price) || HasBotPendingByComment(comment) ||
      GetGridLevelState(comment) == TGM_GRID_LEVEL_PENDING)
   {
      PrintFormat("TGM [DEDUP]: Skip SellLimit %s @ %s — level/price already armed.",
                  comment, DoubleToString(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      return false;
   }
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double lots = GmP11B_AdjustLot(GetTradeVolume(slDistForLots, levelIndex), levelIndex, comment, false);
   const bool attachSL = (sl > 0.0);
   double orderSL = attachSL ? NormalizeDouble(sl, digits) : 0.0;
   double orderTP = NormalizeDouble(tp, digits);
   if(!GmP14_ValidateBeforeOrderSend(false, price, orderSL, orderTP, comment, levelIndex))
      return false;
   LogLotCalculationDetail("SellLimit", comment, levelIndex, slDistForLots, lots);
   SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, 0);
   MarkPendingClaim(comment);
   bool ok = g_trade.SellLimit(lots, price, _Symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment);
   const bool placed = ExecuteTradeOp("SellLimit", ok, StringFormat("comment=%s lots=%.2f price=%.*f", comment, lots, digits, price));
   if(placed)
   {
      SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, g_trade.ResultOrder());
      ClearPendingClaim(comment);
      GmP11B_RegisterPlaced(g_trade.ResultOrder(), comment, levelIndex);
   }
   else
   {
      ClearGridLevelState(comment);
      ClearPendingClaim(comment);
   }
   return placed;
}

bool PlaceSellStop(const double price, const double sl, const double tp, const double slDistForLots, const int levelIndex, const string comment)
{
   if(!PreTradeGuard("SellStop"))
      return false;
   if(!GmP11B_AllowPlacement(comment, levelIndex))
      return false;
   if(IsGridEntryPriceBlocked(price) || HasBotPendingByComment(comment) ||
      GetGridLevelState(comment) == TGM_GRID_LEVEL_PENDING)
      return false;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double lots = GmP11B_AdjustLot(GetTradeVolume(slDistForLots, levelIndex), levelIndex, comment, false);
   const bool attachSL = (sl > 0.0);
   double orderSL = attachSL ? NormalizeDouble(sl, digits) : 0.0;
   double orderTP = NormalizeDouble(tp, digits);
   if(!GmP14_ValidateBeforeOrderSend(false, price, orderSL, orderTP, comment, levelIndex))
      return false;
   LogLotCalculationDetail("SellStop", comment, levelIndex, slDistForLots, lots);
   SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, 0);
   MarkPendingClaim(comment);
   bool ok = g_trade.SellStop(lots, price, _Symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment);
   const bool placed = ExecuteTradeOp("SellStop", ok, StringFormat("comment=%s lots=%.2f price=%.*f REARM", comment, lots, digits, price));
   if(placed)
   {
      SetGridLevelState(comment, TGM_GRID_LEVEL_PENDING, g_trade.ResultOrder());
      ClearPendingClaim(comment);
      GmP11B_RegisterPlaced(g_trade.ResultOrder(), comment, levelIndex);
      PrintFormat("TGM [REARM]: SELL STOP %s @ %.*f (price was at/above level after SL).", comment, digits, price);
   }
   else
   {
      ClearGridLevelState(comment);
      ClearPendingClaim(comment);
   }
   return placed;
}

string PositionHedgePeakProfitKey(const ulong hedgeTicket)
{
   return StringFormat("TGM_HedgePk_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       hedgeTicket);
}

void ClearHedgePeakProfitPoints(const ulong hedgeTicket)
{
   const string key = PositionHedgePeakProfitKey(hedgeTicket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

double GetTicketProfitPoints(const ulong ticket, const double point)
{
   if(point <= 0.0)
      return 0.0;
   CPositionInfo pos;
   if(!pos.SelectByTicket(ticket))
      return 0.0;
   const double openPrice = pos.PriceOpen();
   if(pos.PositionType() == POSITION_TYPE_BUY)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return PriceMoveToBrokerPoints(bid - openPrice, point);
   }
   if(pos.PositionType() == POSITION_TYPE_SELL)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return PriceMoveToBrokerPoints(openPrice - ask, point);
   }
   return 0.0;
}

string PositionBreakEvenPendingKey(const ulong ticket)
{
   return StringFormat("TGM_BEPend_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       ticket);
}

void MarkBreakEvenPending(const ulong ticket)
{
   GlobalVariableSet(PositionBreakEvenPendingKey(ticket), (double)TimeCurrent());
}

string PositionHedgeLinkKey(const ulong parentTicket)
{
   return StringFormat("TGM_Hedge_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       parentTicket);
}

bool IsHedgePositionComment(const string comment)
{
   return (StringFind(comment, TGM_HEDGE_COMMENT) == 0);
}

bool IsGridPositionComment(const string comment)
{
   if(IsHedgePositionComment(comment))
      return false;
   return (StringFind(comment, "GM_BL") == 0 || StringFind(comment, "GM_SL") == 0);
}

bool IsTrackedHedgeTicket(const ulong ticket)
{
   const string prefix = StringFormat("TGM_Hedge_%I64u_%s_",
                                      (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                      _Symbol);
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      const string name = GlobalVariableName(i);
      if(StringFind(name, prefix) != 0)
         continue;
      if((ulong)GlobalVariableGet(name) == ticket)
         return true;
   }
   return false;
}

bool IsBotHedgePosition(const ulong ticket, const string comment)
{
   if(WasOpenedAsGridLimit(ticket))
      return false;
   if(IsHedgePositionComment(comment))
      return true;
   if(IsTrackedHedgeTicket(ticket))
      return true;
   if(FindParentForLinkedHedge(ticket) > 0)
      return true;
   if(HasHedgeOpeningEvidence(ticket))
      return true;
   return WasOpenedAsMarketHedge(ticket);
}

bool IsOurBotMagicPosition(const ulong ticket)
{
   CPositionInfo pos;
   if(!pos.SelectByTicket(ticket))
      return false;
   if(pos.Symbol() != _Symbol)
      return false;
   if(pos.Magic() != (ulong)EXPERT_MAGIC)
      return false;
   return true;
}

bool IsForeignOrManualPosition(const ulong ticket)
{
   CPositionInfo pos;
   if(!pos.SelectByTicket(ticket))
      return true;
   if(pos.Symbol() != _Symbol)
      return true;
   return (pos.Magic() != (ulong)EXPERT_MAGIC);
}

bool IsOurBotGridParent(const ulong ticket)
{
   if(!IsOurBotMagicPosition(ticket))
      return false;
   CPositionInfo pos;
   if(!pos.SelectByTicket(ticket))
      return false;
   if(IsBotHedgePosition(ticket, pos.Comment()))
      return false;
   return true;
}

ulong ParseHedgeParentTicket(const string comment)
{
   const string prefix = TGM_HEDGE_COMMENT + "_";
   if(StringFind(comment, prefix) != 0)
      return 0;
   return (ulong)StringToInteger(StringSubstr(comment, StringLen(prefix)));
}

bool GetPositionOpeningInfo(const ulong positionTicket,
                            ENUM_ORDER_TYPE &orderTypeOut,
                            string &dealCommentOut,
                            string &orderCommentOut)
{
   orderTypeOut    = ORDER_TYPE_BUY;
   dealCommentOut  = "";
   orderCommentOut = "";
   CPositionInfo pos;
   if(!pos.SelectByTicket(positionTicket))
      return false;
   if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
      return false;
   const long positionId = (long)pos.Identifier();
   if(positionId == 0 || !HistorySelectByPosition(positionId))
      return false;
   const int dealsTotal = HistoryDealsTotal();
   for(int d = 0; d < dealsTotal; d++)
   {
      const ulong dealTicket = HistoryDealGetTicket(d);
      if(dealTicket == 0)
         continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;
      const long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != 0 && dealMagic != EXPERT_MAGIC)
         continue;
      const long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      dealCommentOut = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      const ulong orderTicket = (ulong)HistoryDealGetInteger(dealTicket, DEAL_ORDER);
      if(orderTicket != 0 && HistoryOrderSelect(orderTicket))
      {
         orderCommentOut = HistoryOrderGetString((long)orderTicket, ORDER_COMMENT);
         orderTypeOut    = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(orderTicket, ORDER_TYPE);
      }
      else
      {
         orderTypeOut = (ENUM_ORDER_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      }
      return true;
   }
   return false;
}

bool GetPositionOpeningComments(const ulong positionTicket, string &dealCommentOut, string &orderCommentOut)
{
   ENUM_ORDER_TYPE ot = ORDER_TYPE_BUY;
   return GetPositionOpeningInfo(positionTicket, ot, dealCommentOut, orderCommentOut);
}

bool WasOpenedAsGridLimit(const ulong positionTicket)
{
   if(IsForeignOrManualPosition(positionTicket))
      return false;
   CPositionInfo pos;
   if(pos.SelectByTicket(positionTicket))
   {
      if(IsGridPositionComment(pos.Comment()))
         return true;
      if(IsHedgePositionComment(pos.Comment()))
         return false;
   }
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   string dealComment = "";
   string orderComment = "";
   if(!GetPositionOpeningInfo(positionTicket, orderType, dealComment, orderComment))
   {
      if(pos.SelectByTicket(positionTicket) && !IsHedgePositionComment(pos.Comment()))
         return true;
      return false;
   }
   if(IsGridPositionComment(dealComment) || IsGridPositionComment(orderComment))
      return true;
   if(IsHedgePositionComment(dealComment) || IsHedgePositionComment(orderComment))
      return false;
   return (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
           orderType == ORDER_TYPE_BUY_STOP  || orderType == ORDER_TYPE_SELL_STOP);
}

bool WasOpenedAsMarketHedge(const ulong positionTicket)
{
   if(WasOpenedAsGridLimit(positionTicket))
      return false;
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   string dealComment = "";
   string orderComment = "";
   if(!GetPositionOpeningInfo(positionTicket, orderType, dealComment, orderComment))
      return false;
   if(IsHedgePositionComment(dealComment) || IsHedgePositionComment(orderComment))
      return true;
   return (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL);
}

ulong InferHedgeParentTicket(const ulong hedgeTicket)
{
   CPositionInfo hedge;
   if(!hedge.SelectByTicket(hedgeTicket))
      return 0;
   if(!IsOurBotMagicPosition(hedgeTicket))
      return 0;
   if(WasOpenedAsGridLimit(hedgeTicket))
      return 0;
   const ENUM_POSITION_TYPE parentType = (hedge.PositionType() == POSITION_TYPE_SELL)
                                         ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   const double hedgeVol = hedge.Volume();
   ulong   bestParent = 0;
   double  bestLoss   = -1.0;
   datetime bestOpen  = 0;
   CPositionInfo pos;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Ticket() == hedgeTicket)
         continue;
      if(!IsOurBotGridParent(pos.Ticket()))
         continue;
      if(pos.PositionType() != parentType)
         continue;
      if(MathAbs(pos.Volume() - hedgeVol) > 0.0001)
         continue;
      ulong linked = 0;
      if(GetLinkedHedgeTicket(pos.Ticket(), linked) && linked != hedgeTicket)
         continue;
      const double loss = GetPositionLossUSD(pos.Ticket());
      if(loss > bestLoss || (MathAbs(loss - bestLoss) < 1e-9 && pos.Time() > bestOpen))
      {
         bestLoss   = loss;
         bestParent = pos.Ticket();
         bestOpen   = pos.Time();
      }
   }
   return bestParent;
}

bool HasHedgeOpeningEvidence(const ulong ticket)
{
   string dealComment = "";
   string orderComment = "";
   if(!GetPositionOpeningComments(ticket, dealComment, orderComment))
      return false;
   if(IsHedgePositionComment(dealComment) || IsHedgePositionComment(orderComment))
      return true;
   return (ParseHedgeParentTicket(dealComment) > 0 || ParseHedgeParentTicket(orderComment) > 0);
}

ulong ResolveHedgeParentTicket(const ulong hedgeTicket, const string comment)
{
   ulong parentTicket = ParseHedgeParentTicket(comment);
   if(parentTicket == 0)
      parentTicket = FindParentForLinkedHedge(hedgeTicket);
   if(parentTicket == 0)
   {
      string dealComment = "";
      string orderComment = "";
      if(GetPositionOpeningComments(hedgeTicket, dealComment, orderComment))
      {
         parentTicket = ParseHedgeParentTicket(dealComment);
         if(parentTicket == 0)
            parentTicket = ParseHedgeParentTicket(orderComment);
      }
   }
   if(parentTicket == 0)
      parentTicket = InferHedgeParentTicket(hedgeTicket);
   if(parentTicket > 0 && !IsOurBotGridParent(parentTicket))
      return 0;
   return parentTicket;
}

bool GetLinkedHedgeTicket(const ulong parentTicket, ulong &hedgeTicketOut)
{
   const string key = PositionHedgeLinkKey(parentTicket);
   if(!GlobalVariableCheck(key))
      return false;
   hedgeTicketOut = (ulong)GlobalVariableGet(key);
   CPositionInfo pos;
   if(!pos.SelectByTicket(hedgeTicketOut))
   {
      GlobalVariableDel(key);
      return false;
   }
   return true;
}

void ClearLinkedHedgeTicket(const ulong parentTicket)
{
   const string key = PositionHedgeLinkKey(parentTicket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

string PositionHedgeCooldownKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeCD_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       parentTicket);
}

void ApplyHedgeRecycleCooldown(const ulong parentTicket, const int lifeSec)
{
   if(InpHedgeRearmMinSec <= 0)
   {
      const string key = PositionHedgeCooldownKey(parentTicket);
      if(GlobalVariableCheck(key))
         GlobalVariableDel(key);
      return;
   }
   GlobalVariableSet(PositionHedgeCooldownKey(parentTicket),
                     (double)(TimeCurrent() + InpHedgeRearmMinSec));
}

ulong FindParentForLinkedHedge(const ulong hedgeTicket)
{
   const string prefix = StringFormat("TGM_Hedge_%I64u_%s_",
                                      (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                      _Symbol);
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      const string name = GlobalVariableName(i);
      if(StringFind(name, prefix) != 0)
         continue;
      if((ulong)GlobalVariableGet(name) != hedgeTicket)
         continue;
      const string parentStr = StringSubstr(name, StringLen(prefix));
      return (ulong)StringToInteger(parentStr);
   }
   return 0;
}

double GetTicketLossPoints(const ulong ticket, const double point)
{
   const double profitPts = GetTicketProfitPoints(ticket, point);
   return (profitPts < 0.0) ? -profitPts : 0.0;
}

double GetPositionProfitUSD(const ulong ticket)
{
   CPositionInfo p;
   if(!p.SelectByTicket(ticket))
      return 0.0;
   const double open = p.PriceOpen();
   if(p.PositionType() == POSITION_TYPE_BUY)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID) - open;
   if(p.PositionType() == POSITION_TYPE_SELL)
      return open - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return 0.0;
}

double GetPositionLossUSD(const ulong ticket)
{
   const double pl = GetPositionProfitUSD(ticket);
   return (pl < 0.0) ? -pl : 0.0;
}

double GetSymbolStopsPrice()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const long stopsLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long level = (stopsLevel > freezeLevel ? stopsLevel : freezeLevel);
   return (double)level * point;
}

string PositionHedgeRearmKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeRearm_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       parentTicket);
}

string PositionHedgeTriggerReadyKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeTrigReady_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       parentTicket);
}

string PositionHedgeLiveKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeLive_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       parentTicket);
}

string PositionHedgeOpenTimeKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeOpen_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       parentTicket);
}

string PositionHedgeBEArmedKey(const ulong hedgeTicket)
{
   return StringFormat("TGM_HBE_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       hedgeTicket);
}

void ClearHedgeBreakEvenArmed(const ulong hedgeTicket)
{
   const string key = PositionHedgeBEArmedKey(hedgeTicket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

string PositionHedgeReturnArmedKey(const ulong hedgeTicket)
{
   return StringFormat("TGM_HRet_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       hedgeTicket);
}

void ClearHedgeReturnArmed(const ulong hedgeTicket)
{
   const string key = PositionHedgeReturnArmedKey(hedgeTicket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

void ClearHedgeRearmState(const ulong parentTicket)
{
   const string key = PositionHedgeRearmKey(parentTicket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

void SetHedgeTriggerReady(const ulong parentTicket, const bool ready)
{
   GlobalVariableSet(PositionHedgeTriggerReadyKey(parentTicket), ready ? 1.0 : 0.0);
}

void SeedHedgeMonitorForParent(const ulong parentTicket)
{
   if(parentTicket == 0)
      return;
   if(GlobalVariableCheck(PositionHedgeTriggerReadyKey(parentTicket)))
      return;
   CPositionInfo pos;
   if(!pos.SelectByTicket(parentTicket))
      return;
   const double parentLoss = GetPositionLossUSD(parentTicket);
   SetHedgeTriggerReady(parentTicket, true);
   ClearHedgeRearmState(parentTicket);
   if(parentLoss >= GetActiveHedgeTriggerUSD())
   {
      PrintFormat("TGM [HEDGE]: Parent #%I64u at loss $%.2f >= $%.2f - hedge armed.",
                  parentTicket, parentLoss, GetActiveHedgeTriggerUSD());
   }
}

void ClearHedgeLive(const ulong parentTicket)
{
   const string key = PositionHedgeLiveKey(parentTicket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

string HedgeChopNextIdxKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeChopIdx_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string HedgeChopDeathTimeKey(const ulong parentTicket, const int slot)
{
   return StringFormat("TGM_HedgeChopT_%I64u_%s_%I64u_%d",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket, slot);
}

string HedgeChopDeathPriceKey(const ulong parentTicket, const int slot)
{
   return StringFormat("TGM_HedgeChopP_%I64u_%s_%I64u_%d",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket, slot);
}

string HedgeChopDeathRapidKey(const ulong parentTicket, const int slot)
{
   return StringFormat("TGM_HedgeChopR_%I64u_%s_%I64u_%d",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket, slot);
}

string HedgeChopFreezeStartKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeChopFrz_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string HedgeChopCenterKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeChopCtr_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string HedgeChopHalfRangeKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeChopRad_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

void ClearHedgeChopState(const ulong parentTicket)
{
   const string frzKey = HedgeChopFreezeStartKey(parentTicket);
   const string ctrKey = HedgeChopCenterKey(parentTicket);
   const string radKey = HedgeChopHalfRangeKey(parentTicket);
   const string idxKey = HedgeChopNextIdxKey(parentTicket);
   if(GlobalVariableCheck(frzKey)) GlobalVariableDel(frzKey);
   if(GlobalVariableCheck(ctrKey)) GlobalVariableDel(ctrKey);
   if(GlobalVariableCheck(radKey)) GlobalVariableDel(radKey);
   if(GlobalVariableCheck(idxKey)) GlobalVariableDel(idxKey);
   for(int s = 0; s < TGM_HEDGE_CHOP_MAX_EVENTS; s++)
   {
      const string tKey = HedgeChopDeathTimeKey(parentTicket, s);
      const string pKey = HedgeChopDeathPriceKey(parentTicket, s);
      const string rKey = HedgeChopDeathRapidKey(parentTicket, s);
      if(GlobalVariableCheck(tKey)) GlobalVariableDel(tKey);
      if(GlobalVariableCheck(pKey)) GlobalVariableDel(pKey);
      if(GlobalVariableCheck(rKey)) GlobalVariableDel(rKey);
   }
}

string PositionProfitArmedKey(const ulong ticket)
{
   return StringFormat("TGM_Armed_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       ticket);
}

string PositionPartialClosedBeRunnerKey(const ulong ticket)
{
   return StringFormat("TGM_P28A_Runner_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       ticket);
}

bool IsProfitEngineArmed(const ulong ticket)
{
   return GlobalVariableCheck(PositionProfitArmedKey(ticket)) || IsPartialClosedBeRunner(ticket);
}

bool IsPartialClosedBeRunner(const ulong ticket)
{
   return (GlobalVariableCheck(PositionPartialClosedBeRunnerKey(ticket)) &&
           GlobalVariableGet(PositionPartialClosedBeRunnerKey(ticket)) > 0.5);
}

void LogPhase28A(const string eventName, const ulong ticket, const string detail)
{
   PrintFormat("TGM [P28A]: %s | ticket=%I64u | %s", eventName, ticket, detail);
}

double GetBotFloatingPL()
{
   CPositionInfo pos;
   double pl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      pl += pos.Profit() + pos.Swap() + pos.Commission();
   }
   return pl;
}

double GetFloatingDrawdownPercent()
{
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return 0.0;
   const double botPL = GetBotFloatingPL();
   const double loss  = (botPL < 0.0) ? -botPL : 0.0;
   return (loss > 0.0) ? (loss / balance * 100.0) : 0.0;
}

void LogProtectionAlert(const string message)
{
   const datetime now = TimeCurrent();
   if((now - g_lastProtectionAlertTime) < TGM_PROTECTION_ALERT_INTERVAL_SEC)
      return;
   g_lastProtectionAlertTime = now;
   Print("TGM [PROTECTION ALERT]: ", message);
}

int CountOpenBotPositions()
{
   int count = 0;
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      count++;
   }
   return count;
}

int CountBotPendings()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != (ulong)EXPERT_MAGIC)
         continue;
      count++;
   }
   return count;
}

bool LiveSafeAllowsNewPending(const int levelIndex)
{
   if(!Enable_GapFreeze_Hardening)
      return true;
   if(g_forceFlattenActive || IsKillSwitchActiveToday())
      return false;
   if(Live_MaxPendingLevels > 0 && levelIndex >= Live_MaxPendingLevels)
      return false;
   if(Live_MaxOpenBotPositions > 0 && CountOpenBotPositions() >= Live_MaxOpenBotPositions)
      return false;
   return true;
}

void RetryForceFlattenUntilFlat()
{
   if(!g_forceFlattenActive && !IsKillSwitchActiveToday())
      return;
   const datetime now = TimeCurrent();
   if(g_lastFlattenRetryTime != 0 && (now - g_lastFlattenRetryTime) < 1)
      return;
   g_lastFlattenRetryTime = now;
   if(g_serverTradePausedUntil > now)
   {
      g_serverTradePausedUntil = 0;
      g_lastServerPauseReason = "";
   }
   EnsureAllBotPendingDeletedForced();
   if(HasOpenBotPositions())
      CloseAllBotPositionsForced("ForceFlattenRetry");
   EnsureAllBotPendingDeletedForced();
   if(!HasOpenBotPositions() && CountBotPendings() == 0)
   {
      if(g_forceFlattenActive)
      {
         g_forceFlattenActive = false;
         Print("TGM [R440]: Force-flatten complete — bot flat.");
      }
   }
   else
   {
      LogProtectionAlert(StringFormat("Force-flatten retry — open=%d pending=%d (freeze/gap recovery)",
                                      CountOpenBotPositions(), CountBotPendings()));
   }
}

void MonitorLiveGapFreezeGuards()
{
   if(!Enable_GapFreeze_Hardening || !Enable_Account_Protection)
      return;
   if(IsKillSwitchActiveToday())
      return;
   const double pip = Phase17_GetPipSize();
   if(pip <= 0.0)
      return;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && Live_MaxSpreadPips > 0.0)
   {
      const double spreadPips = (ask - bid) / pip;
      if(spreadPips >= Live_MaxSpreadPips && CountBotPendings() > 0)
      {
         EnsureAllBotPendingDeletedForced();
         LogProtectionAlert(StringFormat("GapGuard: spread %.1fpip >= %.1f — pendings cancelled",
                                         spreadPips, Live_MaxSpreadPips));
      }
   }
   const double ddPct = GetFloatingDrawdownPercent();
   if(PendingCancel_DD_Percent > 0.0 && ddPct >= PendingCancel_DD_Percent && CountBotPendings() > 0)
   {
      EnsureAllBotPendingDeletedForced();
      LogProtectionAlert(StringFormat("GapGuard: floating DD %.1f%% >= %.1f%% — ALL pendings cancelled",
                                      ddPct, PendingCancel_DD_Percent));
   }
   if(MaxLossMultipleOfPlannedSL <= 1.0)
      return;
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      if(!IsOurBotGridParent(pos.Ticket()))
         continue;
      const double entry = pos.PriceOpen();
      const double sl = pos.StopLoss();
      if(entry <= 0.0 || sl <= 0.0)
         continue;
      const double plannedSlDist = MathAbs(entry - sl);
      if(plannedSlDist <= 0.0)
         continue;
      const double cur = (pos.PositionType() == POSITION_TYPE_BUY) ? bid : ask;
      if(cur <= 0.0)
         continue;
      double adverse = 0.0;
      if(pos.PositionType() == POSITION_TYPE_BUY)
         adverse = entry - cur;
      else
         adverse = cur - entry;
      if(adverse < plannedSlDist * MaxLossMultipleOfPlannedSL)
         continue;
      const ulong ticket = pos.Ticket();
      PrintFormat("TGM [R440 GapGuard]: #%I64u adverse=%.3f > SL*%.2f (%.3f) — EmergencyClose",
                  ticket, adverse, MaxLossMultipleOfPlannedSL, plannedSlDist * MaxLossMultipleOfPlannedSL);
      g_forceFlattenActive = true;
      EnsureAllBotPendingDeletedForced();
      if(!ExecuteTradeOp("GapGuardClose", g_trade.PositionClose(ticket),
                         StringFormat("ticket=%I64u reason=SL_MULTIPLE_BREACH", ticket)))
      {
      }
   }
}

void MonitorAccountDrawdownProtection()
{
   if(!Enable_Account_Protection)
   {
      g_accountProtectionActive = false;
      g_accountProtectionReason = "";
      return;
   }
   const double ddPct = GetFloatingDrawdownPercent();
   if(ddPct >= Max_Floating_DD_Percent)
   {
      g_accountProtectionActive = true;
      g_accountProtectionReason = StringFormat("Bot floating DD %.1f%% >= limit %.1f%% - same-H4 NEW arm blocked (R444 keeps existing pendings)",
                                               ddPct, Max_Floating_DD_Percent);
      LogProtectionAlert(g_accountProtectionReason);
   }
   else
   {
      g_accountProtectionActive = false;
      g_accountProtectionReason = "";
   }
}

bool IsGridPlacementAllowed(const bool freshH4Cycle = false)
{
   if(IsKillSwitchActiveToday())
      return false;
   if(!IsGridOpsAllowed())
      return false;
   if(freshH4Cycle)
      return Phase17_AllowFreshH4GridPlacement("H4FreshGrid");
   if(!Phase17_AllowNewExposureSimple("GridPlacement"))
      return false;
   if(Enable_Account_Protection && g_accountProtectionActive)
      return false;
   return true;
}

string KillSwitchDayKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return StringFormat("TGM_KillDay_%04d%02d%02d_%I64u_%s",
                       dt.year, dt.mon, dt.day,
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol);
}

string DayStartBalanceKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return StringFormat("TGM_DayBal_%04d%02d%02d_%I64u",
                       dt.year, dt.mon, dt.day,
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN));
}

bool IsKillSwitchActiveToday()
{
   return IsEmergencyLockThisH4();
}

double GetDayStartBalance()
{
   const string key = DayStartBalanceKey();
   if(!GlobalVariableCheck(key))
   {
      const double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      GlobalVariableSet(key, bal);
      return bal;
   }
   return GlobalVariableGet(key);
}

double GetDailyLossPercent()
{
   const double dayStart = GetDayStartBalance();
   if(dayStart <= 0.0)
      return 0.0;
   const double botPL = GetBotFloatingPL();
   const double loss  = (botPL < 0.0) ? -botPL : 0.0;
   return (loss > 0.0) ? (loss / dayStart * 100.0) : 0.0;
}

void ActivateEmergencyKillSwitch(const string reason)
{
   Print("TGM [KILL SWITCH LAYER 3]: ", reason, " - flatten bot now; lock THIS H4 only (next H4 OK).");
   g_forceFlattenActive = true;
   EnsureAllBotPendingDeletedForced();
   CloseAllBotPositionsForced("KillSwitch");
   EnsureAllBotPendingDeletedForced();
   SetEmergencyLockThisH4(reason);
   LogProtectionAlert("LAYER 3: " + reason + " | Flatten ON | H4 locked — next candle can trade.");
}

void MonitorLayer3HardKillSwitch()
{
   if(!Enable_Triple_Protection || !Enable_Account_Protection)
      return;
   if(IsKillSwitchActiveToday())
      return;
   const double floatDD = GetFloatingDrawdownPercent();
   if(floatDD >= Emergency_Close_DD_Percent)
   {
      ActivateEmergencyKillSwitch(StringFormat("Floating DD %.1f%% >= emergency %.1f%%",
                                               floatDD, Emergency_Close_DD_Percent));
      return;
   }
   const double dailyLoss = GetDailyLossPercent();
   if(dailyLoss >= Max_Daily_Loss_Percent)
   {
      ActivateEmergencyKillSwitch(StringFormat("Daily loss %.1f%% >= limit %.1f%%",
                                               dailyLoss, Max_Daily_Loss_Percent));
   }
}

string PositionHedgeBarLockKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeBar_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string PositionHedgeCycleH4Key(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeCyc_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string PositionHedgeRetryKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeRetry_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string PositionHedgeLossGateKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeGate_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

void ClearHedgeProtectionState(const ulong parentTicket)
{
   const string k0 = PositionHedgeBarLockKey(parentTicket);
   const string k1 = PositionHedgeCycleH4Key(parentTicket);
   const string k2 = PositionHedgeRetryKey(parentTicket);
   const string k3 = PositionHedgeLossGateKey(parentTicket);
   const string k4 = PositionHedgeCycleCountKey(parentTicket);
   const string k5 = PositionHedgeCycleBarKey(parentTicket);
   const string k6 = PositionHedgeRearmKey(parentTicket);
   const string k7 = PositionHedgeLiveKey(parentTicket);
   const string k8 = PositionHedgeOpenTimeKey(parentTicket);
   const string k9 = PositionHedgeTriggerReadyKey(parentTicket);
   if(GlobalVariableCheck(k0)) GlobalVariableDel(k0);
   if(GlobalVariableCheck(k1)) GlobalVariableDel(k1);
   if(GlobalVariableCheck(k2)) GlobalVariableDel(k2);
   if(GlobalVariableCheck(k3)) GlobalVariableDel(k3);
   if(GlobalVariableCheck(k4)) GlobalVariableDel(k4);
   if(GlobalVariableCheck(k5)) GlobalVariableDel(k5);
   if(GlobalVariableCheck(k6)) GlobalVariableDel(k6);
   if(GlobalVariableCheck(k7)) GlobalVariableDel(k7);
   if(GlobalVariableCheck(k8)) GlobalVariableDel(k8);
   if(GlobalVariableCheck(k9)) GlobalVariableDel(k9);
   ClearLinkedHedgeTicket(parentTicket);
   const string cdKey = PositionHedgeCooldownKey(parentTicket);
   if(GlobalVariableCheck(cdKey))
      GlobalVariableDel(cdKey);
   ClearHedgeChopState(parentTicket);
}

string PositionHedgeCycleCountKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeCnt_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

string PositionHedgeCycleBarKey(const ulong parentTicket)
{
   return StringFormat("TGM_HedgeCycBar_%I64u_%s_%I64u",
                       (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, parentTicket);
}

void ScheduleHedgeRetry(const ulong parentTicket)
{
   GlobalVariableSet(PositionHedgeRetryKey(parentTicket), (double)(TimeCurrent() + Hedge_Retry_Seconds));
}

void RunAccountProtectionEngine()
{
   if(Enable_GapFreeze_Hardening)
      MonitorLiveGapFreezeGuards();
   if(g_forceFlattenActive || IsKillSwitchActiveToday())
   {
      RetryForceFlattenUntilFlat();
      if(IsKillSwitchActiveToday() && !HasOpenBotPositions() && CountBotPendings() == 0)
         return;
      if(IsKillSwitchActiveToday())
         return;
   }
   MonitorLayer3HardKillSwitch();
   if(IsKillSwitchActiveToday())
   {
      RetryForceFlattenUntilFlat();
      return;
   }
   MonitorAccountDrawdownProtection();
   CloseStrayHedgesInFixedSlMode();
   CPositionInfo posB;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!posB.SelectByIndex(i))
         continue;
      if(posB.Symbol() != _Symbol || posB.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      if(!IsOurBotGridParent(posB.Ticket()))
         continue;
      EnsureModeBFixedBrokerSL(posB.Ticket());
   }
}

bool CloseHedgePosition(const ulong hedgeTicket, const string reason)
{
   if(!PreProtectionTradeGuard("HedgeClose"))
      return false;
   CPositionInfo pos;
   if(!pos.SelectByTicket(hedgeTicket))
      return false;
   const ulong parentTicket = ResolveHedgeParentTicket(hedgeTicket, pos.Comment());
   double parentLossAtClose = 0.0;
   if(parentTicket > 0)
   {
      CPositionInfo parent;
      if(parent.SelectByTicket(parentTicket))
      {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         parentLossAtClose = GetTicketLossPoints(parentTicket, point);
      }
   }
   if(!ExecuteTradeOp("HedgeClose", g_trade.PositionClose(hedgeTicket),
                      StringFormat("ticket=%I64u reason=%s", hedgeTicket, reason)))
      return false;
   ClearHedgePeakProfitPoints(hedgeTicket);
   ClearHedgeBreakEvenArmed(hedgeTicket);
   ClearHedgeReturnArmed(hedgeTicket);
   if(parentTicket > 0)
   {
      ulong linked = 0;
      if(GetLinkedHedgeTicket(parentTicket, linked) && linked == hedgeTicket)
         ClearLinkedHedgeTicket(parentTicket);
      if(reason == "ParentClosed")
         ClearHedgeProtectionState(parentTicket);
      else if(reason == "DuplicateCleanup")
      {
      }
      else
      {
         ClearHedgeLive(parentTicket);
         ClearHedgeRearmState(parentTicket);
         ApplyHedgeRecycleCooldown(parentTicket, 0);
         SetHedgeTriggerReady(parentTicket, true);
         if(reason == "HedgeLoss100")
            ScheduleHedgeRetry(parentTicket);
      }
   }
   PrintFormat("TGM [HEDGE]: Closed hedge #%I64u for parent #%I64u (%s).", hedgeTicket, parentTicket, reason);
   return true;
}

void CleanDeadGlobalVariables()
{
   const string partPrefix = StringFormat("TGM_Part_%I64u_%s_",
                                          (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                          _Symbol);
   const string peakPrefix = StringFormat("TGM_Peak_%I64u_%s_",
                                          (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                          _Symbol);
   const string hedgePrefix = StringFormat("TGM_Hedge_%I64u_%s_",
                                           (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                           _Symbol);
   const string bePendingPrefix = StringFormat("TGM_BEPend_%I64u_%s_",
                                               (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                               _Symbol);
   const string hedgePeakPrefix = StringFormat("TGM_HedgePk_%I64u_%s_",
                                               (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                               _Symbol);
   const string armedPrefix = StringFormat("TGM_Armed_%I64u_%s_",
                                           (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                           _Symbol);
   const string runnerPrefix = StringFormat("TGM_P28A_Runner_%I64u_%s_",
                                            (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                            _Symbol);
   const string hedgeRearmPrefix = StringFormat("TGM_HedgeRearm_%I64u_%s_",
                                                (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                                _Symbol);
   const string hedgeLivePrefix = StringFormat("TGM_HedgeLive_%I64u_%s_",
                                               (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                               _Symbol);
   const string hedgeTrigReadyPrefix = StringFormat("TGM_HedgeTrigReady_%I64u_%s_",
                                                    (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                                    _Symbol);
   const string hedgeBEPrefix = StringFormat("TGM_HBE_%I64u_%s_",
                                             (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                             _Symbol);
   const string hedgeRetPrefix = StringFormat("TGM_HRet_%I64u_%s_",
                                              (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                              _Symbol);
   const string gridStatePrefix = StringFormat("TGM_GridState_%I64u_%s_",
                                               (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                               _Symbol);
   const string gridTicketPrefix = StringFormat("TGM_GridTicket_%I64u_%s_",
                                                (ulong)AccountInfoInteger(ACCOUNT_LOGIN),
                                                _Symbol);
   CPositionInfo pos;
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      bool isPart = (StringFind(name, partPrefix) == 0);
      bool isPeak = (StringFind(name, peakPrefix) == 0);
      bool isHedge = (StringFind(name, hedgePrefix) == 0);
      bool isBePending = (StringFind(name, bePendingPrefix) == 0);
      bool isHedgePeak = (StringFind(name, hedgePeakPrefix) == 0);
      bool isArmed = (StringFind(name, armedPrefix) == 0);
      bool isRunner = (StringFind(name, runnerPrefix) == 0);
      bool isHedgeRearm = (StringFind(name, hedgeRearmPrefix) == 0);
      bool isHedgeLive = (StringFind(name, hedgeLivePrefix) == 0);
      bool isHedgeTrigReady = (StringFind(name, hedgeTrigReadyPrefix) == 0);
      bool isHedgeBE = (StringFind(name, hedgeBEPrefix) == 0);
      bool isHedgeRet = (StringFind(name, hedgeRetPrefix) == 0);
      bool isGridState = (StringFind(name, gridStatePrefix) == 0);
      bool isGridTicket = (StringFind(name, gridTicketPrefix) == 0);
      if(!isPart && !isPeak && !isHedge && !isBePending && !isHedgePeak && !isArmed && !isRunner &&
         !isHedgeRearm && !isHedgeLive && !isHedgeTrigReady && !isHedgeBE && !isHedgeRet && !isGridState && !isGridTicket)
         continue;
      int prefixLen = 0;
      if(isPart) prefixLen = StringLen(partPrefix);
      else if(isPeak) prefixLen = StringLen(peakPrefix);
      else if(isBePending) prefixLen = StringLen(bePendingPrefix);
      else if(isHedgePeak) prefixLen = StringLen(hedgePeakPrefix);
      else if(isArmed) prefixLen = StringLen(armedPrefix);
      else if(isRunner) prefixLen = StringLen(runnerPrefix);
      else if(isHedgeRearm) prefixLen = StringLen(hedgeRearmPrefix);
      else if(isHedgeLive) prefixLen = StringLen(hedgeLivePrefix);
      else if(isHedgeTrigReady) prefixLen = StringLen(hedgeTrigReadyPrefix);
      else if(isHedgeBE) prefixLen = StringLen(hedgeBEPrefix);
      else if(isHedgeRet) prefixLen = StringLen(hedgeRetPrefix);
      else if(isGridState) prefixLen = StringLen(gridStatePrefix);
      else if(isGridTicket) prefixLen = StringLen(gridTicketPrefix);
      else prefixLen = StringLen(hedgePrefix);
      if(isGridState)
         continue;
      if(isGridTicket)
      {
         const ulong trackedTicket = (ulong)GlobalVariableGet(name);
         if(trackedTicket == 0 || (!OrderSelect(trackedTicket) && !pos.SelectByTicket(trackedTicket)))
            GlobalVariableDel(name);
         continue;
      }
      const string ticketStr = StringSubstr(name, prefixLen);
      const ulong ticket = (ulong)StringToInteger(ticketStr);
      if(ticket == 0)
      {
         GlobalVariableDel(name);
         continue;
      }
      if(isHedge)
      {
         const ulong hedgeTicket = (ulong)GlobalVariableGet(name);
         CPositionInfo hedgePos;
         if(!pos.SelectByTicket(ticket) || !hedgePos.SelectByTicket(hedgeTicket))
            GlobalVariableDel(name);
         continue;
      }
      if(!pos.SelectByTicket(ticket))
         GlobalVariableDel(name);
   }
}

bool IsDashboardSymbolMatch(const string dealSymbol)
{
   if(dealSymbol == _Symbol)
      return true;
   const int chartLen = StringLen(_Symbol);
   const int dealLen  = StringLen(dealSymbol);
   if(chartLen > 1 && dealLen > 1)
   {
      const string chartTrim = StringSubstr(_Symbol, 0, chartLen - 1);
      const string dealTrim  = StringSubstr(dealSymbol, 0, dealLen - 1);
      if(chartTrim == dealTrim && StringLen(chartTrim) >= 3)
         return true;
   }
   return false;
}

bool IsPositionIdentifierStillOpen(const long positionId)
{
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      if((long)pos.Identifier() == positionId)
         return true;
   }
   return false;
}

double GetDashboardDealNetProfit(const ulong ticket)
{
   return HistoryDealGetDouble(ticket, DEAL_PROFIT)
          + HistoryDealGetDouble(ticket, DEAL_SWAP)
          + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
}

bool GetDashboardDayWindow(datetime &fromOut, datetime &toOut)
{
   fromOut = iTime(_Symbol, PERIOD_D1, 0);
   if(fromOut <= 0)
   {
      MqlDateTime dt;
      TimeToStruct(TimeTradeServer(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      fromOut = StructToTime(dt);
   }
   toOut = TimeTradeServer();
   return (fromOut > 0 && toOut >= fromOut);
}

bool AddUniquePositionId(const long positionId, long &ids[])
{
   if(positionId == 0)
      return false;
   for(int i = 0; i < ArraySize(ids); i++)
   {
      if(ids[i] == positionId)
         return false;
   }
   const int n = ArraySize(ids);
   ArrayResize(ids, n + 1);
   ids[n] = positionId;
   return true;
}

void CollectDashboardTradeStats(double &sessionProfit, int &openGridTrades, int &openHedgeTrades, int &sessionOpenedGrid, int &sessionClosedTotal, int &sessionClosedWins, int &sessionClosedLosses)
{
   sessionProfit        = 0.0;
   openGridTrades       = 0;
   openHedgeTrades      = 0;
   sessionOpenedGrid    = 0;
   sessionClosedTotal   = 0;
   sessionClosedWins    = 0;
   sessionClosedLosses  = 0;
   datetime dayFrom = 0, dayTo = 0;
   if(!GetDashboardDayWindow(dayFrom, dayTo))
      return;
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i))
         continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC)
         continue;
      if(IsBotHedgePosition(pos.Ticket(), pos.Comment()))
      {
         openHedgeTrades++;
         continue;
      }
      sessionProfit += pos.Profit() + pos.Swap();
      openGridTrades++;
   }
   if(!HistorySelect(dayFrom, dayTo))
      return;
   long   dPos[];
   double dNet[];
   long   dEntry[];
   string dComment[];
   long   dOrder[];
   long   dMagic[];
   ArrayResize(dPos, 0); ArrayResize(dNet, 0); ArrayResize(dEntry, 0);
   ArrayResize(dComment, 0); ArrayResize(dOrder, 0); ArrayResize(dMagic, 0);
   const int dealsTotal = HistoryDealsTotal();
   for(int d = 0; d < dealsTotal; d++)
   {
      const ulong dealTicket = HistoryDealGetTicket(d);
      if(dealTicket == 0)
         continue;
      if(!IsDashboardSymbolMatch(HistoryDealGetString(dealTicket, DEAL_SYMBOL)))
         continue;
      const long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT &&
         entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      const datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      if(dealTime < dayFrom || dealTime > dayTo)
         continue;
      const int n = ArraySize(dPos);
      ArrayResize(dPos, n + 1);   ArrayResize(dNet, n + 1);   ArrayResize(dEntry, n + 1);
      ArrayResize(dComment, n + 1); ArrayResize(dOrder, n + 1); ArrayResize(dMagic, n + 1);
      dPos[n]     = (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      dNet[n]     = GetDashboardDealNetProfit(dealTicket);
      dEntry[n]   = entry;
      dComment[n] = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      dOrder[n]   = (long)HistoryDealGetInteger(dealTicket, DEAL_ORDER);
      dMagic[n]   = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   }
   long uniquePos[];
   ArrayResize(uniquePos, 0);
   const int capturedDeals = ArraySize(dPos);
   for(int i = 0; i < capturedDeals; i++)
      AddUniquePositionId(dPos[i], uniquePos);
   const int posCount = ArraySize(uniquePos);
   for(int u = 0; u < posCount; u++)
   {
      const long posId = uniquePos[u];
      bool   isGrid     = false;
      bool   isHedge    = false;
      bool   hasIn      = false;
      bool   hasOut     = false;
      bool   hasEaMagic = false;
      double net        = 0.0;
      long   anyOrder   = 0;
      for(int i = 0; i < capturedDeals; i++)
      {
         if(dPos[i] != posId)
            continue;
         net += dNet[i];
         if(dEntry[i] == DEAL_ENTRY_IN || dEntry[i] == DEAL_ENTRY_INOUT)
            hasIn = true;
         if(dEntry[i] == DEAL_ENTRY_OUT || dEntry[i] == DEAL_ENTRY_OUT_BY)
            hasOut = true;
         if(dMagic[i] == EXPERT_MAGIC)
            hasEaMagic = true;
         if(IsHedgePositionComment(dComment[i]))
            isHedge = true;
         else if(IsGridPositionComment(dComment[i]))
            isGrid = true;
         if(dOrder[i] != 0)
            anyOrder = dOrder[i];
      }
      if(!isGrid && !isHedge && anyOrder != 0 && HistoryOrderSelect((ulong)anyOrder))
      {
         const string oc = HistoryOrderGetString((long)anyOrder, ORDER_COMMENT);
         if(IsHedgePositionComment(oc))
            isHedge = true;
         else if(IsGridPositionComment(oc))
            isGrid = true;
      }
      if(!hasEaMagic || !isGrid || isHedge)
         continue;
      if(hasIn)
         sessionOpenedGrid++;
      if(hasOut && !IsPositionIdentifierStillOpen(posId))
      {
         sessionClosedTotal++;
         sessionProfit += net;
         if(net > TGM_DASHBOARD_BE_EPSILON)
            sessionClosedWins++;
         else if(net < -TGM_DASHBOARD_BE_EPSILON)
            sessionClosedLosses++;
      }
   }
}

string FormatDashboardMoney(const double value)
{
   return StringFormat("$%.2f", value);
}

color GetDailyProfitColor(const double dailyProfit)
{
   if(dailyProfit > 0.0) return clrLime;
   if(dailyProfit < 0.0) return clrRed;
   return clrWhite;
}

void SetUILabelColor(const string name, const color textColor)
{
   const long chartId = ChartID();
   const string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) >= 0)
      ObjectSetInteger(chartId, objName, OBJPROP_COLOR, textColor);
}

void InitDashboard()
{
   g_uiMinimized = false;
   const color labelColor = C'180,165,120';
   CreateUIBackground("PanelBG", C'8,6,4', C'255,215,0');
   CreateUIBackground("PanelHeader", C'20,16,8', C'20,16,8');
   CreateUILabel("Title", "RTAS GOLD MIND", C'255,235,150', 13, "Arial Bold");
   CreateUILabel("Tagline", "Mind The Market - Mine The Gold", C'198,168,86', 7, "Arial");
   CreateUIMinButton("BtnMin", "[-]");
   RemoveLogoFrame();
   RemoveDashboardDragHandle();
   CreateUILogoFrame();
   if(!LoadDashboardLogo())
      CreateUILabel("Logo", "GM", clrGold, 10, "Arial Bold");
   CreateUISeparator("Sep0");
   CreateUILabel("LblAcc",   "Account", labelColor, 9, "Arial");
   CreateUILabel("LblRisk",  "Risk", labelColor, 9, "Arial");
   CreateUILabel("LblPos",   "Running", labelColor, 9, "Arial");
   CreateUILabel("LblDirection", "Trade Direction", labelColor, 9, "Arial");
   CreateUILabel("LblTrail", "Method / Engine", labelColor, 9, "Arial");
   CreateUISeparator("Sep1");
   CreateUILabel("LblLic",   "Market Status", labelColor, 9, "Arial");
   CreateUISeparator("Sep2");
   CreateUILabel("LblDaily",       "Today P/L", labelColor, 9, "Arial");
   CreateUILabel("LblSessionOpen", "Today Opened", labelColor, 9, "Arial");
   CreateUILabel("LblTotalTrades", "Still Open", labelColor, 9, "Arial");
   CreateUILabel("LblWinLoss",     "Today Closed", labelColor, 9, "Arial");
   CreateUILabel("ValAcc",   "---", clrLightSkyBlue, 9, "Arial Bold");
   CreateUILabel("ValRisk",  "---", clrGold, 9, "Arial Bold");
   CreateUILabel("ValPos",   "---", clrLime, 9, "Arial Bold");
   CreateUILabel("ValDirection", "---", C'255,235,120', 10, "Arial Bold");
   CreateUILabel("ValTrail", "---", C'120,210,150', 9, "Arial Bold");
   CreateUILabel("ValLic",   "CHECKING", clrLightGray, 9, "Arial Bold");
   CreateUILabel("ValDaily",       "---", clrWhite, 10, "Arial Bold");
   CreateUILabel("ValSessionOpen", "---", clrWhite, 9, "Arial Bold");
   CreateUILabel("ValTotalTrades", "---", clrWhite, 9, "Arial Bold");
   CreateUILabel("ValWinLoss",     "---", clrWhite, 9, "Arial Bold");
   RenderDashboardLayout();
   UpdateDashboard(true);
}

void RenderDashboardLayout()
{
   const long chartId = ChartID();
   const int width  = TGM_PANEL_WIDTH;
   const int height = g_uiMinimized ? TGM_PANEL_HEIGHT_MIN : 290;
   const long visibilityState = g_uiMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_XDISTANCE, g_uiX);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_YDISTANCE, g_uiY);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_YSIZE, height);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_BACK, false);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelBG", OBJPROP_ZORDER, TGM_UI_Z_PANEL);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelHeader", OBJPROP_XDISTANCE, g_uiX);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelHeader", OBJPROP_YDISTANCE, g_uiY);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelHeader", OBJPROP_XSIZE, width);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelHeader", OBJPROP_YSIZE, TGM_HEADER_H);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelHeader", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, UI_PREFIX + "PanelHeader", OBJPROP_ZORDER, TGM_UI_Z_PANEL + 1);
   ObjectSetInteger(chartId, UI_PREFIX + "LogoFrame", OBJPROP_XDISTANCE, g_uiX + TGM_LOGO_X_OFFSET - 2);
   ObjectSetInteger(chartId, UI_PREFIX + "LogoFrame", OBJPROP_YDISTANCE, g_uiY + TGM_LOGO_Y_OFFSET - 2);
   ObjectSetInteger(chartId, UI_PREFIX + "LogoFrame", OBJPROP_XSIZE, TGM_LOGO_W + 4);
   ObjectSetInteger(chartId, UI_PREFIX + "LogoFrame", OBJPROP_YSIZE, TGM_LOGO_H + 4);
   ObjectSetInteger(chartId, UI_PREFIX + "LogoFrame", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, UI_PREFIX + "LogoFrame", OBJPROP_ZORDER, 2);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_XDISTANCE, g_uiX + TGM_LOGO_X_OFFSET);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_YDISTANCE, g_uiY + TGM_LOGO_Y_OFFSET);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_XSIZE, TGM_LOGO_W);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_YSIZE, TGM_LOGO_H);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_BACK, false);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_ZORDER, TGM_UI_Z_LOGO);
   ObjectSetString(chartId, UI_PREFIX + "Logo", OBJPROP_BMPFILE, 0, ActiveLogoResource());
   ObjectSetString(chartId, UI_PREFIX + "Logo", OBJPROP_BMPFILE, 1, ActiveLogoResource());
   ObjectSetInteger(chartId, UI_PREFIX + "Logo", OBJPROP_STATE, false);
   ObjectSetInteger(chartId, UI_PREFIX + "Title", OBJPROP_XDISTANCE, g_uiX + TGM_TITLE_X_OFFSET);
   ObjectSetInteger(chartId, UI_PREFIX + "Title", OBJPROP_YDISTANCE, g_uiY + TGM_TITLE_Y_OFFSET);
   ObjectSetInteger(chartId, UI_PREFIX + "Title", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, UI_PREFIX + "Tagline", OBJPROP_XDISTANCE, g_uiX + TGM_TITLE_X_OFFSET);
   ObjectSetInteger(chartId, UI_PREFIX + "Tagline", OBJPROP_YDISTANCE, g_uiY + TGM_TAGLINE_Y_OFFSET);
   ObjectSetInteger(chartId, UI_PREFIX + "Tagline", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, UI_PREFIX + "BtnMin", OBJPROP_XDISTANCE, g_uiX + width - 30);
   ObjectSetInteger(chartId, UI_PREFIX + "BtnMin", OBJPROP_YDISTANCE, g_uiY + 6);
   ObjectSetString(chartId, UI_PREFIX + "BtnMin", OBJPROP_TEXT, g_uiMinimized ? "[+]" : "[-]");
   ObjectSetInteger(chartId, UI_PREFIX + "BtnMin", OBJPROP_COLOR, g_uiMinimized ? clrLime : clrSilver);
   ObjectSetInteger(chartId, UI_PREFIX + "BtnMin", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   string internalLabels[] = {"Sep0",
                              "LblAcc", "ValAcc", "LblRisk", "ValRisk", "LblPos", "ValPos",
                              "LblDirection", "ValDirection",
                              "LblTrail", "ValTrail",
                              "Sep1", "LblLic", "ValLic",
                              "Sep2",
                              "LblDaily", "ValDaily", "LblSessionOpen", "ValSessionOpen",
                              "LblTotalTrades", "ValTotalTrades",
                              "LblWinLoss", "ValWinLoss"};
   int internalOffsetsY[] = {52,
                             60, 60, 82, 82, 104, 104,
                             126, 126,
                             148, 148,
                             172,
                             180, 180,
                             204,
                             212, 212, 234, 234,
                             256, 256,
                             278, 278};
   int internalOffsetsX[] = {12,
                             15, 140, 15, 140, 15, 140,
                             15, 140,
                             15, 140,
                             12,
                             15, 140,
                             12,
                             15, 140, 15, 140,
                             15, 140,
                             15, 140};
   int totalElements = ArraySize(internalLabels);
   for(int i = 0; i < totalElements; i++)
   {
      string objName = UI_PREFIX + internalLabels[i];
      ObjectSetInteger(chartId, objName, OBJPROP_XDISTANCE, g_uiX + internalOffsetsX[i]);
      ObjectSetInteger(chartId, objName, OBJPROP_YDISTANCE, g_uiY + internalOffsetsY[i]);
      ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, visibilityState);
   }
   ChartRedraw(chartId);
}

void EnsureDashboardPresent()
{
   if(!ShouldRenderUI() || ObjectFind(ChartID(), UI_PREFIX + "PanelBG") >= 0)
      return;
   Print("The Gold Mind: Dashboard missing - rebuilding.");
   g_uiMinimized = false;
   InitDashboard();
   EnableDashboardChartEvents();
}

void EnableDashboardChartEvents()
{
   const long chartId = ChartID();
   ChartSetInteger(chartId, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(chartId, CHART_FOREGROUND, false);
}

bool IsPointInsideMinButton(const int mouseX, const int mouseY)
{
   const int btnX = g_uiX + TGM_PANEL_WIDTH - 30;
   const int btnY = g_uiY + 4;
   return (mouseX >= btnX && mouseX <= btnX + 28 &&
           mouseY >= btnY && mouseY <= btnY + 22);
}

bool IsPointInsideDashboardHeader(const int mouseX, const int mouseY)
{
   const int headerWidth  = TGM_PANEL_WIDTH;
   const int headerHeight = TGM_HEADER_H;
   return (mouseX >= g_uiX && mouseX <= g_uiX + headerWidth &&
           mouseY >= g_uiY && mouseY <= g_uiY + headerHeight);
}

void UpdateDashboard(const bool forceUpdate)
{
   if(!ShouldRenderUI()) return;
   datetime now = TimeCurrent();
   if(!forceUpdate && now - g_lastDashboardUpdate < 1 && !g_isDragging) return;
   g_lastDashboardUpdate = now;
   string accNum   = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string riskStr  = (g_effectiveRiskMode == RISK_AUTO_3_PERCENT_EQUITY)
                     ? StringFormat("Auto %.0f%% Equity", (InpRiskPercent/100.0) * 100.0)
                     : "Manual Lot";
   string trailStatus = "OFF";
   if(g_unifiedRouter.HasLock())
   {
      const STgmRouterDecision rd = g_lastRouterDecision;
      if(rd.status == TGM_ROUTER_ACTIVE)
         trailStatus = (rd.methodLabel != "" ? rd.methodLabel : rd.marketModeLabel);
      else if(rd.status == TGM_ROUTER_NO_TRADE_GAP)
         trailStatus = StringFormat("GAP %.0f-%.0f", SmallRangePips, LargeRangePips);
      else if(rd.status == TGM_ROUTER_WAIT_WEAK_PULLBACK)
         trailStatus = "WEAK PULLBACK";
      else
         trailStatus = rd.trendState;
   }
   else
      trailStatus = "DIR FILTER";
   string marketState = GetDashboardMarketStatus();
   double sessionProfit = 0.0;
   int openGridTrades = 0, openHedgeTrades = 0, sessionOpenedGrid = 0;
   int sessionClosedTotal = 0, sessionClosedWins = 0, sessionClosedLosses = 0;
   CollectDashboardTradeStats(sessionProfit, openGridTrades, openHedgeTrades, sessionOpenedGrid, sessionClosedTotal, sessionClosedWins, sessionClosedLosses);
   SetUILabelText("ValAcc", accNum);
   SetUILabelText("ValRisk", riskStr);
   SetUILabelText("ValPos", IntegerToString(openGridTrades));
   string dirStr = "Both";
   if(TradeDirection == DIR_BUY) dirStr = "Buy Only";
   else if(TradeDirection == DIR_SELL) dirStr = "Sell Only";
   SetUILabelText("ValDirection", dirStr);
   SetUILabelText("ValTrail", trailStatus);
   SetUILabelText("ValLic", marketState);
   SetUILabelColor("ValLic", GetMarketStatusColor(marketState));
   SetUILabelText("ValDaily", FormatDashboardMoney(sessionProfit));
   SetUILabelColor("ValDaily", GetDailyProfitColor(sessionProfit));
   SetUILabelText("ValSessionOpen", IntegerToString(sessionOpenedGrid));
   SetUILabelText("ValTotalTrades", IntegerToString(openGridTrades + openHedgeTrades));
   SetUILabelText("ValWinLoss", IntegerToString(sessionClosedTotal) + " (" +
                  IntegerToString(sessionClosedWins) + "W / " +
                  IntegerToString(sessionClosedLosses) + "L)");
   GmP11B_UpdatePanel(g_uiX, g_uiY);
   if(g_isDragging) RenderDashboardLayout();
}

string GetDashboardMarketStatus()
{
   if(g_emergencyKillSwitchActive || IsKillSwitchActiveToday())
      return "H4 LOCK";
   if(g_accountProtectionActive)
      return "DD PROTECT";
   if(!IsStrategyTester() && IsDashboardMarketClosed())
      return GetDashboardClosedStatusLabel();
   if(IsPositionMgmtAllowed() && !IsServerTradePaused())
      return "OPEN";
   if(IsWeekendOrMarketClosed())
      return GetDashboardClosedStatusLabel();
   if(IsServerTradePaused())
      return "BROKER HALT";
   const string reason = GetAutoTradeBlockReason();
   if(reason != "")
      return "BLOCKED";
   return "PAUSED";
}

color GetMarketStatusColor(const string status)
{
   if(status == "OPEN")
      return clrLimeGreen;
   if(status == "DD PROTECT")
      return clrGold;
   if(status == "H4 LOCK" || status == "KILL SWITCH")
      return clrRed;
   if(status == "CLOSED" || status == "WEEKEND")
      return clrOrange;
   if(status == "BROKER HALT" || status == "BLOCKED")
      return clrTomato;
   return clrLightGray;
}

void RemoveLogoFrame()
{
   const long chartId = ChartID();
   const string objName = UI_PREFIX + "LogoFrame";
   if(ObjectFind(chartId, objName) >= 0)
      ObjectDelete(chartId, objName);
}

string ActiveLogoResource()
{
   return (g_logoFitOk ? LOGO_FIT_RESOURCE : LOGO_RESOURCE_PATH);
}

bool BuildScaledLogoResource(const string srcResource, const int dstW, const int dstH)
{
   g_logoFitOk = false;
   if(dstW <= 0 || dstH <= 0) return false;
   uint src[]; uint sw = 0, sh = 0;
   if(!ResourceReadImage(srcResource, src, sw, sh))
   { PrintFormat("TGM [LOGO]: read FAILED err=%d", GetLastError()); return false; }
   if(sw == 0 || sh == 0 || ArraySize(src) < (int)(sw*sh)) return false;
   uint dst[]; const int total = dstW*dstH;
   if(ArrayResize(dst, total) != total) return false;
   for(int i = 0; i < total; i++) dst[i] = 0x00FFFFFF;
   const double sc = MathMin((double)dstW/(double)sw, (double)dstH/(double)sh);
   int dw = (int)MathMax(1.0, MathRound(sw*sc));
   int dh = (int)MathMax(1.0, MathRound(sh*sc));
   if(dw > dstW) dw = dstW;
   if(dh > dstH) dh = dstH;
   const int ox = (dstW-dw)/2, oy = (dstH-dh)/2;
   for(int y = 0; y < dh; y++)
   {
      int sy = (int)((double)y*sh/dh); if(sy >= (int)sh) sy = (int)sh-1;
      for(int x = 0; x < dw; x++)
      {
         int sx = (int)((double)x*sw/dw); if(sx >= (int)sw) sx = (int)sw-1;
         dst[(oy+y)*dstW + (ox+x)] = (src[sy*(int)sw+sx] & 0x00FFFFFF);
      }
   }
   if(!ResourceCreate(LOGO_FIT_RESOURCE, dst, dstW, dstH, 0, 0, dstW, COLOR_FORMAT_XRGB_NOALPHA))
   { PrintFormat("TGM [LOGO]: create FAILED err=%d", GetLastError()); return false; }
   g_logoFitOk = true;
   PrintFormat("TGM [LOGO]: %ux%u -> %dx%d OK", sw, sh, dstW, dstH);
   return true;
}

bool LoadDashboardLogo()
{
   if(BuildScaledLogoResource(LOGO_RESOURCE_PATH, TGM_LOGO_W, TGM_LOGO_H) &&
      CreateUIBitmap("Logo", LOGO_FIT_RESOURCE))
   { Print("The Gold Mind: Logo auto-fitted OK."); return true; }
   if(CreateUIBitmap("Logo", LOGO_RESOURCE_PATH))
   { Print("The Gold Mind: Logo loaded (raw)."); return true; }
   Print("The Gold Mind: Logo failed - GM text badge.");
   return false;
}

void DestroyAllChartDashboardUI()
{
   const long chartId = ChartID();
   const string prefixes[] = {UI_PREFIX, UI_LEGACY_PREFIX_LOCK, UI_LEGACY_PREFIX_RTAS};
   for(int pass = 0; pass < 2; pass++)
   {
      const long targetChart = (pass == 0 ? chartId : 0);
      for(int i = ObjectsTotal(targetChart, 0, -1) - 1; i >= 0; i--)
      {
         const string name = ObjectName(targetChart, i, 0, -1);
         for(int p = 0; p < ArraySize(prefixes); p++)
         {
            if(StringFind(name, prefixes[p]) == 0)
            {
               ObjectDelete(targetChart, name);
               break;
            }
         }
      }
   }
   ChartRedraw(chartId);
}

void CreateUIBackground(string name, color bg_color, color border_color)
{
   const long chartId = ChartID();
   string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) >= 0) ObjectDelete(chartId, objName);
   if(!ObjectCreate(chartId, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("The Gold Mind: UI PanelBG create failed err=%d", GetLastError());
      return;
   }
   ObjectSetInteger(chartId, objName, OBJPROP_XDISTANCE, g_uiX);
   ObjectSetInteger(chartId, objName, OBJPROP_YDISTANCE, g_uiY);
   ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, TGM_PANEL_WIDTH);
   ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, TGM_PANEL_HEIGHT_FULL);
   ObjectSetInteger(chartId, objName, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_COLOR, border_color);
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, TGM_UI_Z_PANEL);
}

void CreateUILogoFrame()
{
   const long chartId = ChartID();
   const string objName = UI_PREFIX + "LogoFrame";
   if(ObjectFind(chartId, objName) >= 0) ObjectDelete(chartId, objName);
   if(!ObjectCreate(chartId, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("The Gold Mind: LogoFrame create failed err=%d", GetLastError());
      return;
   }
   ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, TGM_LOGO_W + 4);
   ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, TGM_LOGO_H + 4);
   ObjectSetInteger(chartId, objName, OBJPROP_BGCOLOR, clrNONE);
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_COLOR, C'198,168,86');
   ObjectSetInteger(chartId, objName, OBJPROP_COLOR, C'198,168,86');
   ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, 2);
}

void CreateUISeparator(string name)
{
   const long chartId = ChartID();
   const string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) >= 0) ObjectDelete(chartId, objName);
   if(!ObjectCreate(chartId, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("The Gold Mind: UI separator create failed (%s) err=%d", name, GetLastError());
      return;
   }
   ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, TGM_PANEL_WIDTH - 24);
   ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, 1);
   ObjectSetInteger(chartId, objName, OBJPROP_BGCOLOR, C'255,215,0');
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_COLOR, C'212,175,55');
   ObjectSetInteger(chartId, objName, OBJPROP_COLOR, C'212,175,55');
   ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, TGM_UI_Z_LABELS);
}

bool CreateUIBitmap(string name, string bmp_path)
{
   const long chartId = ChartID();
   string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) >= 0) ObjectDelete(chartId, objName);
   ResetLastError();
   if(!ObjectCreate(chartId, objName, OBJ_BITMAP_LABEL, 0, 0, 0))
   {
      PrintFormat("The Gold Mind: Bitmap create failed for %s err=%d", bmp_path, GetLastError());
      return false;
   }
   ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_XDISTANCE, g_uiX + TGM_LOGO_X_OFFSET);
   ObjectSetInteger(chartId, objName, OBJPROP_YDISTANCE, g_uiY + TGM_LOGO_Y_OFFSET);
   ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, TGM_LOGO_W);
   ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, TGM_LOGO_H);
   ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, TGM_UI_Z_LOGO);
   ObjectSetString(chartId, objName, OBJPROP_BMPFILE, 0, bmp_path);
   ObjectSetString(chartId, objName, OBJPROP_BMPFILE, 1, bmp_path);
   ObjectSetInteger(chartId, objName, OBJPROP_STATE, false);
   ChartRedraw(chartId);
   return (ObjectFind(chartId, objName) >= 0);
}

void CreateUIMinButton(string name, string text)
{
   const long chartId = ChartID();
   string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) >= 0) ObjectDelete(chartId, objName);
   if(!ObjectCreate(chartId, objName, OBJ_BUTTON, 0, 0, 0))
   {
      PrintFormat("The Gold Mind: UI BtnMin create failed err=%d", GetLastError());
      return;
   }
   ObjectSetString(chartId, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, 28);
   ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, 22);
   ObjectSetInteger(chartId, objName, OBJPROP_BGCOLOR, C'45,38,22');
   ObjectSetInteger(chartId, objName, OBJPROP_BORDER_COLOR, C'198,168,86');
   ObjectSetInteger(chartId, objName, OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(chartId, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(chartId, objName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_STATE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, TGM_UI_Z_BUTTON);
}

void RemoveDashboardDragHandle()
{
   const long chartId = ChartID();
   const string objName = UI_PREFIX + "DragHdr";
   if(ObjectFind(chartId, objName) >= 0)
      ObjectDelete(chartId, objName);
}

void CreateUILabel(string name, string text, color text_color, int font_size, string font_name="Arial")
{
   const long chartId = ChartID();
   string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) >= 0) ObjectDelete(chartId, objName);
   if(!ObjectCreate(chartId, objName, OBJ_LABEL, 0, 0, 0))
   {
      PrintFormat("The Gold Mind: UI label create failed (%s) err=%d", name, GetLastError());
      return;
   }
   ObjectSetString(chartId, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(chartId, objName, OBJPROP_COLOR, text_color);
   ObjectSetInteger(chartId, objName, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(chartId, objName, OBJPROP_FONT, font_name);
   ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
   ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chartId, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, TGM_UI_Z_LABELS);
}

void SetUILabelText(string name, string text)
{
   const long chartId = ChartID();
   string objName = UI_PREFIX + name;
   if(ObjectFind(chartId, objName) < 0)
      return;
   ObjectSetString(chartId, objName, OBJPROP_TEXT, text);
}

void SendDataToWebsite()
{
   string url = "https://the-gold-mind-ai-v2-professional.vercel.app/api/trading/master-sync";
   string headers = "Content-Type: application/json\r\n";
   string json_trades = "[";
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(count > 0) json_trades += ",";
         string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "buy" : "sell";
         json_trades += StringFormat("{\"ticket\":\"%I64u\",\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.2f,\"open_price\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"profit\":%.2f,\"status\":\"open\",\"open_time\":\"%s\"}",
                                     PositionGetInteger(POSITION_TICKET),
                                     PositionGetString(POSITION_SYMBOL),
                                     type,
                                     PositionGetDouble(POSITION_VOLUME),
                                     PositionGetDouble(POSITION_PRICE_OPEN),
                                     PositionGetDouble(POSITION_SL),
                                     PositionGetDouble(POSITION_TP),
                                     PositionGetDouble(POSITION_PROFIT),
                                     TimeToString(PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_MINUTES));
         count++;
      }
   }
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderGetTicket(i) > 0)
      {
         if(count > 0) json_trades += ",";
         string type = "pending";
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) type = "buy_limit";
         else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT) type = "sell_limit";
         else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) type = "buy_stop";
         else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) type = "sell_stop";
         json_trades += StringFormat("{\"ticket\":\"%I64u\",\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.2f,\"open_price\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"profit\":0.0,\"status\":\"pending\",\"open_time\":\"%s\"}",
                                     OrderGetInteger(ORDER_TICKET),
                                     OrderGetString(ORDER_SYMBOL),
                                     type,
                                     OrderGetDouble(ORDER_VOLUME_INITIAL),
                                     OrderGetDouble(ORDER_PRICE_OPEN),
                                     OrderGetDouble(ORDER_SL),
                                     OrderGetDouble(ORDER_TP),
                                     TimeToString(OrderGetInteger(ORDER_TIME_SETUP), TIME_DATE|TIME_MINUTES));
         count++;
      }
   }
   json_trades += "]";
   string payload = StringFormat("{\"trades\": %s, \"signals\": []}", json_trades);
   char post_data[];
   char result_data[];
   string result_headers;
   StringToCharArray(payload, post_data, 0, StringLen(payload), CP_UTF8);
   int res = WebRequest("POST", url, headers, 5000, post_data, result_data, result_headers);
   if(res == 200)
   {
      Print("✅ Data sent to website!");
   }
   else
   {
      int error_code = GetLastError();
      Print("❌ WebRequest failed. Error: ", error_code, " | HTTP: ", res);
   }
}

void ManageProfitRunners()
{
   const double pip = Phase17_GetPipSize();
   if(pip <= 0.0) return;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) return;
   const long stopsPts = (long)MathMax((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                       (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   const double stops = (double)stopsPts * point;
   CPositionInfo pos;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != (ulong)EXPERT_MAGIC) continue;
      if(!IsOurBotGridParent(pos.Ticket())) continue;
      const ulong ticket = pos.Ticket();
      const bool isBuy = (pos.PositionType() == POSITION_TYPE_BUY);
      const double entry = pos.PriceOpen();
      const double curSL = pos.StopLoss();
      const double curTP = pos.TakeProfit();
      const double cur = (isBuy ? bid : ask);
      const double pips = (isBuy ? (cur - entry) : (entry - cur)) / pip;
      const string beKey = StringFormat("TGM_BE_%I64u_%s_%I64u",
                                        (ulong)AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ticket);
      const bool beApplied = GlobalVariableCheck(beKey);
      if(!beApplied && pips >= 50.0)
      {
         const double beSL = NormalizeDouble(entry, digits);
         const bool okBE = (isBuy ? (beSL < bid - stops) : (beSL > ask + stops));
         if(okBE)
         {
            if(SafePositionModify(ticket, beSL, curTP, "BE-Trail-BE"))
            {
               GlobalVariableSet(beKey, 1.0);
               PrintFormat("TGM [BE-TRAIL]: #%I64u BE applied @ %.5f (pips=%.1f)",
                           ticket, beSL, pips);
            }
         }
         continue;
      }
      if(beApplied && pips >= 130.0)
      {
         const double gap = 50.0 * pip;
         double target = (isBuy ? NormalizeDouble(cur - gap, digits)
                                : NormalizeDouble(cur + gap, digits));
         if(isBuy)
         {
            const double maxValid = NormalizeDouble(bid - stops - point, digits);
            if(target > maxValid) target = maxValid;
            if(target >= bid) continue;
            if(curSL > 0.0 && target <= curSL + point * 0.5) continue;
         }
         else
         {
            const double minValid = NormalizeDouble(ask + stops + point, digits);
            if(target < minValid) target = minValid;
            if(target <= ask) continue;
            if(curSL > 0.0 && target >= curSL - point * 0.5) continue;
         }
         SafePositionModify(ticket, target, curTP, "BE-Trail-Trail");
      }
   }
}