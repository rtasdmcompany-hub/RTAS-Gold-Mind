import re, os

F = "Experts/RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
if not os.path.exists(F):
    print("❌ .mq5 file not found")
    input("Press Enter...")
    exit()

s = open(F, encoding="utf-8").read()
changes = 0

# ============================================================
# FIX 1: Duplicate LblDirection remove karein
# ============================================================
# Pattern: LblDirection line 2 baar aayi hai consecutively
dup_pattern = r'CreateUILabel\("LblDirection",\s*"Trade Direction",\s*labelColor,\s*9,\s*"Arial"\);\s*\n\s*CreateUILabel\("LblDirection",\s*"Trade Direction",\s*labelColor,\s*9,\s*"Arial"\);'
dup_replacement = 'CreateUILabel("LblDirection", "Trade Direction", labelColor, 9, "Arial");'

if re.search(dup_pattern, s):
    s = re.sub(dup_pattern, dup_replacement, s, count=1)
    changes += 1
    print("[1] ✅ Duplicate LblDirection removed")
else:
    print("[1] ⚠️ Duplicate not found")

# ============================================================
# FIX 2: internalLabels array — Hedge ko Direction se replace karein
# ============================================================
# Pattern: "LblTrail", "ValTrail", ke baad "LblHedge", "ValHedge" hai
# Hum isay "LblDirection", "ValDirection" se replace karenge
labels_pattern = r'"LblTrail",\s*"ValTrail",\s*\n\s*"Sep1"'
labels_replacement = '"LblDirection", "ValDirection",\n"LblTrail", "ValTrail",\n"Sep1"'

if re.search(labels_pattern, s) and '"LblDirection"' not in s.split('"LblTrail"')[0]:
    s = re.sub(labels_pattern, labels_replacement, s, count=1)
    changes += 1
    print("[2a] ✅ LblDirection added before LblTrail")
else:
    print("[2a] ⚠️ Direction add pattern not found")

# Ab Hedge ko remove karein
hedge_pattern = r'"LblTotalTrades",\s*"ValTotalTrades",\s*"LblHedge",\s*"ValHedge",\s*\n\s*"LblWinLoss"'
hedge_replacement = '"LblTotalTrades", "ValTotalTrades",\n"LblWinLoss"'

if re.search(hedge_pattern, s):
    s = re.sub(hedge_pattern, hedge_replacement, s, count=1)
    changes += 1
    print("[2b] ✅ LblHedge/ValHedge removed")
else:
    print("[2b] ⚠️ Hedge removal pattern not found")

# ============================================================
# FIX 3: Y-offsets update karein
# ============================================================
# Pattern: 126, 126, ke baad 150, 158, 158 hai
# Hum isay 126, 126, 148, 148, 172, 180, 180, 204, se replace karenge
offsets_pattern = r'126,\s*126,\s*\n\s*150,\s*158,\s*158,\s*\n\s*182,'
offsets_replacement = '126, 126,\n148, 148,\n172, 180, 180,\n204,'

if re.search(offsets_pattern, s):
    s = re.sub(offsets_pattern, offsets_replacement, s, count=1)
    changes += 1
    print("[3] ✅ Y-offsets updated")
else:
    print("[3] ⚠️ Offsets pattern not found")

# ============================================================
# SAVE
# ============================================================
if changes > 0:
    open(F, "w", encoding="utf-8").write(s)
    print(f"\n🎉 {changes} changes applied!")
    print("   Ab MetaEditor mein F7 compile karein")
    print("   Chart par EA reload karein")
else:
    print("\n⚠️ No changes made")

input("\nPress Enter to exit...")