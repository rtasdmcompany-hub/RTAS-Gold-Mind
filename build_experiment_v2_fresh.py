import os, shutil

SRC = "Experts/RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
DST = "Experts/RTAS_Gold_Mind_Experiment_v2.mq5"

if not os.path.exists(SRC):
    print(f"❌ Original file nahi mili: {SRC}")
    input("Press Enter..."); exit()

# Fresh copy
shutil.copy(SRC, DST)
print(f"📄 Fresh copy ban gayi: {DST}")

lines = open(DST, encoding="utf-8").read().splitlines()
print(f"📄 {len(lines)} lines\n")
log = []

# 1. Magic 112234 → 112299
for i, l in enumerate(lines):
    if '#define EXPERT_MAGIC' in l:
        lines[i] = '#define EXPERT_MAGIC              112299'
        log.append("Magic 112299")
        print("[1] ✅ Magic: 112234 → 112299")
        break

# 2. Version 2.220 → 2.222
for i, l in enumerate(lines):
    if l.strip().startswith("#property version"):
        lines[i] = '#property version   "2.222"'
        log.append("Version 2.222")
        print("[2] ✅ Version: 2.220 → 2.222")
        break

# 3. Description update
for i, l in enumerate(lines):
    if '+50 pip: 50% book' in l:
        lines[i] = '#property description "+50 pip: BE | +130 pip: trail 50 pip | TP 500 pip | SL 300 pip | 1% risk | inverted 300+ pip"'
        log.append("Description updated")
        print("[3] ✅ Description updated")
        break

# 4. Risk 3% → 1%
for i, l in enumerate(lines):
    if 'input double InpRiskPercent' in l and '=' in l:
        lines[i] = 'input double InpRiskPercent = 1.0;   // Risk % of EQUITY per trade (EXPERIMENT: 1% safe)'
        log.append("Risk 1%")
        print("[4] ✅ Risk: 3% → 1%")
        break

# 5. SL 100 → 300
for i, l in enumerate(lines):
    if 'input double RESEARCH_FIX_SL_PIPS' in l and '=' in l:
        lines[i] = 'input double RESEARCH_FIX_SL_PIPS     = 300.0; // SL 300 pip'
        log.append("SL 300 pip")
        print("[5] ✅ SL: 100 → 300 pip")
        break

# 6. TP 200 → 500 (multiplier 1.6667)
for i, l in enumerate(lines):
    if 'input double RESEARCH_RR_TP_MULT' in l and '=' in l:
        lines[i] = 'input double RESEARCH_RR_TP_MULT      = 1.6667; // TP = SL × 1.6667 (500 pip)'
        log.append("TP 500 pip")
        print("[6] ✅ TP: 200 → 500 pip (multiplier 1.6667)")
        break

# SAVE
open(DST, "w", encoding="utf-8").write("\n".join(lines) + "\n")

print("\n" + "="*60)
print("🎉 EXPERIMENT V2 BUILD COMPLETE")
print("="*60)
print(f"   File: {DST}")
print(f"   Applied: {len(log)} changes")
for c in log:
    print(f"   ✅ {c}")
print("\n   Agla qadam:")
print("   1. MetaEditor: File > Open > Experts/RTAS_Gold_Mind_Experiment_v2.mq5")
print("   2. F7 compile")
print("   3. H4 chart par attach karein")
input("\nPress Enter...")