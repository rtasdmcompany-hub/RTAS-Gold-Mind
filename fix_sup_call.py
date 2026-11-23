import os, shutil, sys, re

CAND = ["Experts/RTAS_Gold_Mind_Experiment_v2.mq5",
        "RTAS_Gold_Mind_Experiment_v2.mq5",
        "MQL5/Experts/RTAS_Gold_Mind_Experiment_v2.mq5"]
F = next((p for p in CAND if os.path.exists(p)), None)
if not F:
    print("❌ File nahi mili. Current folder:", os.getcwd())
    for root,_,fs in os.walk('.'):
        for f in fs:
            if 'Experiment_v2' in f and f.endswith('.mq5'):
                print("   MILI:", os.path.join(root,f))
    input(); sys.exit(1)

shutil.copy(F, F+".bak_supfix")
L = open(F, encoding="utf-8").read().splitlines()
print(f"✅ {F}\n📦 Backup: {F}.bak_supfix\n📄 {len(L)} lines\n")

# ---- 1. Saari stray SupervisorOnTick(); lines hatao ----
before = len(L)
L = [l for l in L if l.strip() != "SupervisorOnTick();"]
print(f"[1] ✅ Stray call lines hatayi: {before-len(L)}")

# ---- 2. OnTick function dhundho ----
ot = next((i for i,l in enumerate(L) if l.strip().startswith("void OnTick()")), -1)
if ot < 0:
    print("❌ OnTick nahi mila"); shutil.copy(F+".bak_supfix",F); input(); sys.exit(1)
print(f"[2] OnTick line {ot+1}")

# ---- 3. OnTick ke ANDAR asli ManageProfitRunners(); call ----
idx = -1
for i in range(ot+1, len(L)):
    if L[i].strip() == "ManageProfitRunners();":
        idx = i; break
if idx < 0:
    print("❌ OnTick mein ManageProfitRunners() call nahi mila")
    shutil.copy(F+".bak_supfix",F); input(); sys.exit(1)

indent = L[idx][:len(L[idx]) - len(L[idx].lstrip())]
L.insert(idx+1, indent + "SupervisorOnTick();")
print(f"[3] ✅ Call OnTick ke andar line {idx+2} par lagi (indent={len(indent)})")

# ---- 4. Brace-depth verify: insertion function ke andar hai? ----
def strip_code(s):
    s = re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)
    return re.sub(r'//.*', '', s)

depth = 0
for i in range(0, idx+2):
    for ch in strip_code(L[i]):
        if ch=='{': depth+=1
        elif ch=='}': depth-=1
print(f"[4] Brace depth at call = {depth}  {'✅ INSIDE function' if depth>0 else '❌ GLOBAL'}")
if depth <= 0:
    print("❌ Restore"); shutil.copy(F+".bak_supfix",F); input(); sys.exit(1)

# ---- 5. Engine definition exactly once? ----
ndef = sum(1 for l in L if l.strip().startswith("void SupervisorOnTick()"))
print(f"[5] SupervisorOnTick definition count = {ndef} {'✅' if ndef==1 else '❌'}")
if ndef != 1:
    print("❌ Restore"); shutil.copy(F+".bak_supfix",F); input(); sys.exit(1)

# ---- 6. Total brace balance ----
code = "\n".join(L)
clean = re.sub(r'"(?:[^"\\]|\\.)*"','""',code)
clean = re.sub(r'//.*','',clean)
bal = clean.count("{") - clean.count("}")
print(f"[6] Total brace balance = {bal} {'✅' if bal==0 else '❌'}")
if bal != 0:
    print("❌ Restore"); shutil.copy(F+".bak_supfix",F); input(); sys.exit(1)

open(F,"w",encoding="utf-8").write(code+"\n")
print("\n🎉 FIX COMPLETE — MetaEditor: File > Reload → F7")
input("Press Enter...")