import re

FILENAME = "RTAS_Gold_Mind_Automatic_Trading_Software.mq5"

print(f"📂 Reading {FILENAME}...")
with open(FILENAME, "r", encoding="utf-8") as f:
    code = f.read()

# Find the 3 lines using regex (handles any whitespace)
# Pattern: const double rangePips = (h1 - l1) / pip;
#          if(rangePips > SmallRangePips)
#          return;   // sirf chhoti range = LIMIT mode
pattern = r'const\s+double\s+rangePips\s*=\s*\(h1\s*-\s*l1\)\s*/\s*pip\s*;\s*\n\s*if\s*\(\s*rangePips\s*>\s*SmallRangePips\s*\)\s*\n\s*return\s*;\s*//\s*sirf\s+chhoti\s+range\s*=\s*LIMIT\s+mode'

match = re.search(pattern, code)

if match:
    # Replace with comment
    replacement = "// CHANGED: Removed range check so L2 Re-Arm works for ALL ranges"
    code = code[:match.start()] + replacement + code[match.end():]
    
    with open(FILENAME, "w", encoding="utf-8") as f:
        f.write(code)
    
    print("✅ L2 Re-Arm Fix Applied: Removed range check - now works for ALL ranges")
    print("   Ye 3 lines delete ho gayi:")
    print("   - const double rangePips = (h1 - l1) / pip;")
    print("   - if(rangePips > SmallRangePips)")
    print("   - return;   // sirf chhoti range = LIMIT mode")
else:
    print("⚠️  Could not find the exact pattern.")
    print("   Checking if it's already fixed...")
    
    if "// CHANGED: Removed range check" in code:
        print("✅ Already fixed! No changes needed.")
    else:
        print("❌ Pattern not found. Please check the code manually.")
        print("   Looking for: 'rangePips > SmallRangePips'")
        if "rangePips > SmallRangePips" in code:
            print("   Found 'rangePips > SmallRangePips' - manual fix needed")
        else:
            print("   'rangePips > SmallRangePips' not found at all")

print("\nPress Enter to exit...")
input()