FILENAME = "RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
print(f"Reading {FILENAME}...")
s = open(FILENAME, encoding="utf-8").read()

# 1) rangePips declaration wapas add karo (ManageL2ReArm ke andar)
#    Insert after the R450 fix comment line, before 'const datetime h4'
anchor = "// CHANGED: Removed range check so L2 Re-Arm works for ALL ranges"
decl = ("// CHANGED: Removed range check so L2 Re-Arm works for ALL ranges\n"
        "    const double rangePips = (h1 - l1) / pip;")

if anchor in s and "const double rangePips = (h1 - l1) / pip;" not in s.split("ManageL2ReArm")[1]:
    s = s.replace(anchor, decl, 1)
    print("[1] rangePips declaration restored (log ke liye)")
elif "const double rangePips = (h1 - l1) / pip;" in s.split("ManageL2ReArm")[1]:
    print("[1] rangePips already declared - OK")
else:
    print("[1] WARNING: anchor not found; trying alt")
    # alt: insert right before 'const datetime h4 = GetCurrentH4BarOpenTime();'
    # inside ManageL2ReArm only
    idx = s.find("void ManageL2ReArm()")
    sub = s[idx:]
    if "const double rangePips" not in sub.split("void ")[0]:
        sub2 = sub.replace("const datetime h4 = GetCurrentH4BarOpenTime();",
                           "const double rangePips = (h1 - l1) / pip;\n    const datetime h4 = GetCurrentH4BarOpenTime();", 1)
        s = s[:idx] + sub2
        print("[1] alt: rangePips declared before h4")

# 2) Confirm karo ke 'if(rangePips > SmallRangePips) return;' wapas NAHI aaya
if "if(rangePips > SmallRangePips)" in s:
    s = s.replace("if(rangePips > SmallRangePips)\n        return;   // sirf chhoti range = LIMIT mode",
                  "// (range check removed - L2 re-arm works for ALL ranges)")
    print("[2] range check removed (if it re-appeared)")
else:
    print("[2] No range check present - correct")

open(FILENAME, "w", encoding="utf-8").write(s)
print("\nDone. Ab MetaEditor mein F7 (Compile) karein.")