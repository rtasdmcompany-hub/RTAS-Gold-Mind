import os
import sys

# File ko dhundho - multiple locations try karo
possible_paths = [
    "Experts/RTAS_Gold_Mind_Experiment_v2.mq5",
    "RTAS_Gold_Mind_Experiment_v2.mq5",
    "MQL5/Experts/RTAS_Gold_Mind_Experiment_v2.mq5",
]

F = None
for path in possible_paths:
    if os.path.exists(path):
        F = path
        break

if F is None:
    print("❌ File nahi mili! Current directory:", os.getcwd())
    print("\nAvailable files:")
    for root, dirs, files in os.walk('.'):
        for f in files:
            if 'Experiment_v2' in f and f.endswith('.mq5'):
                print(f"  Found: {os.path.join(root, f)}")
    input("\nPress Enter...")
    sys.exit(1)

print(f"✅ File mili: {F}")
print(f"📦 Backup ban raha hai...")

# Backup
import shutil
backup = F + ".backup_before_fix"
shutil.copy(F, backup)
print(f"📦 Backup: {backup}")

# File read karo
with open(F, 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
print(f"📄 Total lines: {len(lines)}\n")

changes = []

# ============================================================
# 1. SL 100 → 300 pip
# ============================================================
for i, line in enumerate(lines):
    if 'input double RESEARCH_FIX_SL_PIPS' in line and '=' in line:
        lines[i] = 'input double RESEARCH_FIX_SL_PIPS     = 300.0; // SL 300 pip'
        changes.append("SL: 100 → 300 pip")
        print(f"[1] ✅ SL updated (line {i+1})")
        break

# ============================================================
# 2. TP multiplier 2.0 → 1.6667 (500 pip)
# ============================================================
for i, line in enumerate(lines):
    if 'input double RESEARCH_RR_TP_MULT' in line and '=' in line:
        lines[i] = 'input double RESEARCH_RR_TP_MULT      = 1.6667; // TP = SL × 1.6667 (500 pip)'
        changes.append("TP: 200 → 500 pip")
        print(f"[2] ✅ TP updated (line {i+1})")
        break

# ============================================================
# 3. Risk 3% → 1%
# ============================================================
for i, line in enumerate(lines):
    if 'input double InpRiskPercent' in line and '=' in line and 'EXPERIMENT' not in line:
        lines[i] = 'input double InpRiskPercent = 1.0;   // Risk % of EQUITY per trade (EXPERIMENT: 1% safe)'
        changes.append("Risk: 3% → 1%")
        print(f"[3] ✅ Risk updated (line {i+1})")
        break

# ============================================================
# 4. Partial % 70 → 0 (band)
# ============================================================
for i, line in enumerate(lines):
    if 'input double InpPartialPercent' in line and '=' in line:
        lines[i] = 'input double InpPartialPercent     = 0.0;   // CHANGED: 70% -> 0% (NO partial - BE+Trail only)'
        changes.append("Partial: 70% → 0%")
        print(f"[4] ✅ Partial % updated (line {i+1})")
        break

# ============================================================
# 5. Trail gap 30 → 50 pip
# ============================================================
for i, line in enumerate(lines):
    if 'input double InpRunnerTrailPips' in line and '=' in line:
        lines[i] = 'input double InpRunnerTrailPips    = 50.0;  // runner ka trailing gap (pip) - CHANGED 30→50'
        changes.append("Trail gap: 30 → 50 pip")
        print(f"[5] ✅ Trail gap updated (line {i+1})")
        break

# ============================================================
# 6. Description update
# ============================================================
for i, line in enumerate(lines):
    if '+50 pip: 50% book' in line:
        lines[i] = '#property description "+50 pip: BE | +130 pip: trail 50 pip | TP 500 pip | SL 300 pip | 1% risk | inverted 300+ pip"'
        changes.append("Description updated")
        print(f"[6] ✅ Description updated (line {i+1})")
        break

# ============================================================
# 7. R450 Section POORA DELETE (file ke end se)
# ============================================================
r450_start = -1
for i, line in enumerate(lines):
    if 'input group "--- R450 Level-2 Re-Arm' in line:
        r450_start = i
        break

if r450_start >= 0:
    # Comment block se pehle tak jao
    start = r450_start
    while start > 0 and lines[start-1].strip().startswith('//'):
        start -= 1
    while start > 0 and lines[start-1].strip() == '':
        start -= 1
    
    removed = len(lines) - start
    lines = lines[:start]
    changes.append(f"R450 removed ({removed} lines)")
    print(f"[7] ✅ R450 section removed ({removed} lines)")
else:
    print("[7] ⚠️ R450 section nahi mila (pehle hi remove tha)")

# ============================================================
# 8. ManageL2ReArm references remove
# ============================================================
n = 0
new_lines = []
for line in lines:
    s = line.strip()
    if s == "void ManageL2ReArm();":
        n += 1
        continue
    if s == "ManageL2ReArm();":
        n += 1
        continue
    new_lines.append(line)
lines = new_lines
if n > 0:
    changes.append(f"ManageL2ReArm refs removed ({n})")
    print(f"[8] ✅ ManageL2ReArm references removed ({n})")

# ============================================================
# 9. ManageProfitRunners REPLACE with BE+Trail (50/130/50)
# ============================================================
si = -1
for i, line in enumerate(lines):
    if line.strip().startswith("void ManageProfitRunners()"):
        si = i
        break

if si >= 0:
    # Find end of function
    depth = 0
    ei = si
    started = False
    for i in range(si, len(lines)):
        depth += lines[i].count('{') - lines[i].count('}')
        if '{' in lines[i]:
            started = True
        if started and depth == 0:
            ei = i
            break
    
    new_runner = '''void ManageProfitRunners()
{
   // BE + TRAIL (50/130/50): NO partial close. Full position stays.
   // Stage 1: +50 pip -> SL moves to BE (entry)
   // Stage 2: +130 pip -> 50 pip trailing until TP (500 pip) or trail SL
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

      // Stage 2: BE applied -> wait for +130 pip, then 50 pip trailing
      if(beApplied && pips >= 130.0)
      {
         const double gap = 50.0 * pip;  // 50 pip trail gap
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
    
    lines[si:ei+1] = new_runner.split('\n')
    changes.append("ManageProfitRunners → BE+Trail (50/130/50)")
    print(f"[9] ✅ ManageProfitRunners replaced (lines {si+1}-{ei+1})")

# ============================================================
# SAVE
# ============================================================
with open(F, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print("\n" + "="*60)
print("🎉 COMPLETE FIX APPLIED")
print("="*60)
print(f"File: {F}")
print(f"Changes: {len(changes)}")
for c in changes:
    print(f"  ✅ {c}")
print("\nAgla qadam:")
print("1. MetaEditor: File > Reload")
print("2. F7 compile (0 errors)")
print("3. EA chart par attach karein")
print("4. Inputs tab mein check karein - sab naye values dikhengi")
input("\nPress Enter...")