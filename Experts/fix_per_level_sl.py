import os

F = "Experts/RTAS_Gold_Mind_Experiment_v2.mq5"
if not os.path.exists(F):
    print("❌ File nahi mili"); input(); exit()

lines = open(F, encoding="utf-8").read().splitlines()
print(f"📄 {len(lines)} lines\n")

# Fix 1: RESEARCH_INV_TP_L1_PIPS 100 → 300
for i, l in enumerate(lines):
    if 'input double RESEARCH_INV_TP_L1_PIPS' in l and '=' in l:
        lines[i] = 'input double RESEARCH_INV_TP_L1_PIPS  = 300.0; // L1 SL pips (TP = SL×RR)'
        print(f"[1] ✅ L1 SL: 100 → 300 pip (line {i+1})")
        break

# Fix 2: RESEARCH_INV_TP_L2_PIPS 100 → 300
for i, l in enumerate(lines):
    if 'input double RESEARCH_INV_TP_L2_PIPS' in l and '=' in l:
        lines[i] = 'input double RESEARCH_INV_TP_L2_PIPS  = 300.0; // L2 SL pips (TP = SL×RR)'
        print(f"[2] ✅ L2 SL: 100 → 300 pip (line {i+1})")
        break

# Fix 3: RESEARCH_INV_TP_L3_PIPS 100 → 300
for i, l in enumerate(lines):
    if 'input double RESEARCH_INV_TP_L3_PIPS' in l and '=' in l:
        lines[i] = 'input double RESEARCH_INV_TP_L3_PIPS  = 300.0; // L3 SL pips (TP = SL×RR)'
        print(f"[3] ✅ L3 SL: 100 → 300 pip (line {i+1})")
        break

# Fix 4: RESEARCH_RR_TP_MULT 2.0 → 1.6667 (300 × 1.6667 = 500 pip TP)
for i, l in enumerate(lines):
    if 'input double RESEARCH_RR_TP_MULT' in l and '=' in l:
        lines[i] = 'input double RESEARCH_RR_TP_MULT      = 1.6667; // TP = SL × 1.6667 (500 pip)'
        print(f"[4] ✅ TP multiplier: 2.0 → 1.6667 (line {i+1})")
        break

# Fix 5: RESEARCH_FIX_SL_PIPS bhi 300 karein (fallback)
for i, l in enumerate(lines):
    if 'input double RESEARCH_FIX_SL_PIPS' in l and '=' in l:
        lines[i] = 'input double RESEARCH_FIX_SL_PIPS     = 300.0; // SL 300 pip'
        print(f"[5] ✅ Fallback SL: 100 → 300 pip (line {i+1})")
        break

open(F, "w", encoding="utf-8").write("\n".join(lines))
print("\n🎉 Sab fix ho gaya!")
print("   Ab MetaEditor: File > Reload → F7 → EA reload karein")
input("Press Enter...")