import os

# Yahan apni .mq5 file ka naam likhein. Agar naam alag hai to change kar lein.
FILENAME = "RTAS_Gold_Mind_Automatic_Trading_Software.mq5" 

if not os.path.exists(FILENAME):
    print(f"❌ Error: '{FILENAME}' file is not found in this folder.")
    print("Please make sure this script and your .mq5 file are in the same folder.")
    input("Press Enter to exit...")
    exit()

print(f"📂 Reading {FILENAME}...")
with open(FILENAME, "r", encoding="utf-8") as f:
    code = f.read()

changes_made = 0

# --- CHANGE 1: Partial Close 50% -> 70% ---
old_1 = "input double InpPartialPercent     = 50.0;"
new_1 = "input double InpPartialPercent     = 70.0;  // CHANGED: 50% -> 70%"
if old_1 in code:
    code = code.replace(old_1, new_1)
    print("✅ Change 1 Applied: Partial close updated to 70%")
    changes_made += 1
else:
    print("⚠️ Warning: Could not find exact string for Change 1.")

# --- CHANGE 2: 300+ pip = LIMIT (No Breakout) ---
old_2 = "return g_dirBreakoutPlacement; // R448: router decides limits (small range) vs stops (large range)"
new_2 = "return false; // CHANGED: ALWAYS use LIMIT orders (mean reversion) for ALL ranges"
if old_2 in code:
    code = code.replace(old_2, new_2)
    print("✅ Change 2 Applied: 300+ pip range now uses LIMIT orders (no breakout)")
    changes_made += 1
else:
    print("⚠️ Warning: Could not find exact string for Change 2.")

# --- CHANGE 3: L2 Re-Arm Fix (Remove range check) ---
# Hum wo 3 lines delete kar rahe hain jo sirf chhoti range check karti thin
old_3 = """const double rangePips = (h1 - l1) / pip;
if(rangePips > SmallRangePips)
return;   // sirf chhoti range = LIMIT mode"""

new_3 = "// CHANGED: Removed range check so L2 Re-Arm works for ALL ranges"
if old_3 in code:
    code = code.replace(old_3, new_3)
    print("✅ Change 3 Applied: L2 Re-Arm now works for ALL ranges (removed small range limit)")
    changes_made += 1
else:
    print("⚠️ Warning: Could not find exact string for Change 3.")

# --- Save the updated file ---
if changes_made > 0:
    with open(FILENAME, "w", encoding="utf-8") as f:
        f.write(code)
    print(f"\n🎉 SUCCESS! {changes_made} changes applied to {FILENAME}.")
    print("Ab aap is file ko MetaEditor mein khol kar Compile (F7) kar sakte hain.")
else:
    print("\n❌ No changes were made. Please check if the file content matches.")

input("\nPress Enter to exit...")