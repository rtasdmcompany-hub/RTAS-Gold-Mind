import re, os
P = "Experts/TheGoldMindAI_Research_BE50Trail_CLEAN.mq5"
L = open(P, encoding="utf-8", errors="replace").read().splitlines()

print("=== INCLUDE CHECK ===")
for m in re.finditer(r'#include\s+[<"]([^>"]+)[>"]', "\n".join(L)):
    inc = m.group(1).replace("\\", "/")
    if inc.startswith("AI/"):
        p = os.path.join("Include", inc)
        print(("OK      " if os.path.exists(p) else "MISSING ") + inc)
    else:
        print("STD     " + inc)

print("\n=== ROUTER USAGE ===")
hits = set()
for i, l in enumerate(L):
    if re.search(r'g_unifiedRouter|STgmRouterDecision|TGM_ROUTER_|g_lastRouterDecision|\brd\s*\.', l):
        for j in range(i, min(i + 5, len(L))):
            hits.add(j)
prev = -2
for j in sorted(hits):
    if j != prev + 1:
        print("   ...")
    print(f"{j+1}: {L[j]}")
    prev = j
print("\n=== DONE ===")