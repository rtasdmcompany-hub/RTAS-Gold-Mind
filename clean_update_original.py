#!/usr/bin/env python3
"""
RTAS Gold Mind - ORIGINAL EA Update
File 1 (original clean) se shuru karta hai.
Changes:
  1. TP 200 -> 300 (RESEARCH_RR_TP_MULT 2.0 -> 3.0)
  2. ManageProfitRunners -> BE + Trail (80/30)
  3. R450 section REMOVE
  4. R449RunnerKey REMOVE
  5. Description update
  6. Magic 112234 REHNE DO (original)
"""
import os, shutil, sys

# Original clean file (File 1)
SRC = "Experts/RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
if not os.path.exists(SRC):
    print(f"❌ Original file nahi mili: {SRC}")
    print("   Pehle original file restore karein (backup se ya File 1 se)")
    input("Press Enter..."); sys.exit(1)

# Backup
backup = SRC + ".bak_clean_update"
if not os.path.exists(backup):
    shutil.copy(SRC, backup)
    print(f"📦 Backup: {backup}")

lines = open(SRC, encoding="utf-8").read().splitlines()
print(f"📄 {len(lines)} lines loaded\n")
log = []

# ============================================================
# 1. TP 200 -> 300
# ============================================================
for i, l in enumerate(lines):
    if 'input double RESEARCH_RR_TP_MULT' in l and '=' in l:
        lines[i] = 'input double RESEARCH_RR_TP_MULT      = 3.0;   // TP = SL × this (1:3)'
        log.append("TP 200 -> 300")
        print("[1] ✅ TP multiplier: 2.0 → 3.0")
        break

# ============================================================
# 2. R450 Section REMOVE (file ke end se)
# ============================================================
r450_start = -1
for i, l in enumerate(lines):
    if 'input group "--- R450 Level-2 Re-Arm' in l:
        r450_start = i
        break

if r450_start >= 0:
    # Find the comment block before it
    start = r450_start
    while start > 0 and lines[start-1].strip().startswith('//'):
        start -= 1
    while start > 0 and lines[start-1].strip() == '':
        start -= 1
    
    removed = len(lines) - start
    lines = lines[:start]
    log.append(f"R450 removed ({removed} lines)")
    print(f"[2] ✅ R450 section removed ({removed} lines)")
else:
    print("[2] ⚠️ R450 section nahi mila (pehle hi remove tha)")

# ============================================================
# 3. ManageL2ReArm forward declaration REMOVE (OnTick se)
# ============================================================
n = 0
out = []
for l in lines:
    s = l.strip()
    if s == "void ManageL2ReArm();":
        n += 1
        continue
    if s == "ManageL2ReArm();":
        n += 1
        continue
    out.append(l)
lines = out
if n > 0:
    log.append(f"ManageL2ReArm refs removed ({n})")
    print(f"[3] ✅ ManageL2ReArm references removed ({n})")

# ============================================================
# 4. ManageProfitRunners REPLACE with BE+Trail (80/30)
# ============================================================
si = -1
for i, l in enumerate(lines):
    if l.strip().startswith("void ManageProfitRunners()"):
        si = i
        break

if si < 0:
    print("❌ ManageProfitRunners() nahi mila")
    input("Press Enter..."); sys.exit(1)

# Find end
depth = 0
ei = si
started = False
for i in range(si, len(lines)):
    depth += lines[i].count("{") - lines[i].count("}")
    if "{" in lines[i]:
        started = True
    if started and depth == 0:
        ei = i
        break

print(f"[4] ManageProfitRunners() lines {si+1}..{ei+1} replace ho raha hai")

NEW_RUNNER = r'''void ManageProfitRunners()
{
   // BE + TRAIL (80/30): NO partial close. Full position stays.
   // Stage 1: +50 pip -> SL moves to BE (entry)
   // Stage 2: +80 pip -> 30 pip trailing until TP (300 pip) or trail SL
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

      // Stage 1: +50 pip -> SL to BE (no partial)
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

      // Stage 2: BE applied -> wait for +80 pip, then 30 pip trailing
      if(beApplied && pips >= 80.0)
      {
         const double gap = 30.0 * pip;
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
}'''

lines[si:ei+1] = NEW_RUNNER.splitlines()
log.append("ManageProfitRunners -> BE+Trail (80/30)")
print("   ✅ ManageProfitRunners() replaced")

# ============================================================
# 5. R449RunnerKey REMOVE
# ============================================================
for i, l in enumerate(lines):
    if 'string R449RunnerKey(' in l:
        si2 = i
        depth = 0
        ei2 = si2
        started = False
        for j in range(si2, len(lines)):
            depth += lines[j].count("{") - lines[j].count("}")
            if "{" in lines[j]:
                started = True
            if started and depth == 0:
                ei2 = j
                break
        lines[si2:ei2+1] = ['// R449RunnerKey removed (BE+Trail does not need it)']
        log.append("R449RunnerKey removed")
        print("[5] ✅ R449RunnerKey() removed")
        break

# ============================================================
# 6. Description update
# ============================================================
for i, l in enumerate(lines):
    if '+50 pip: 50% book' in l:
        lines[i] = '#property description "+50 pip: BE | +80 pip: trail 30 pip | TP 300 pip (1:3) | equity compounding lots."'
        log.append("Description updated")
        print("[6] ✅ Description updated")
        break

# ============================================================
# 7. Version update
# ============================================================
for i, l in enumerate(lines):
    if l.strip().startswith("#property version"):
        lines[i] = '#property version   "2.221"'
        log.append("Version 2.220 -> 2.221")
        print("[7] ✅ Version: 2.220 → 2.221")
        break

# ============================================================
# SAVE
# ============================================================
open(SRC, "w", encoding="utf-8").write("\n".join(lines) + "\n")

print("\n" + "="*60)
print("🎉 ORIGINAL EA UPDATE COMPLETE")
print("="*60)
print(f"   File: {SRC}")
print(f"   Backup: {backup}")
print(f"   Applied: {len(log)} changes")
for c in log:
    print(f"   ✅ {c}")
print("\n   Agla qadam:")
print("   1. MetaEditor: File > Reload")
print("   2. F7 compile (0 errors expected)")
print("   3. Strategy Tester mein ORIGINAL EA select karein")
print("   4. Backtest chalayein")
input("\nPress Enter...")