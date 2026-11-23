F = "RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
s = open(F, encoding="utf-8").read()

# BuyStop: entry must be ABOVE ask  -> skip when entry <= ask
old_buy = "if(isBuy  && ask <= entry) continue;   // BuyStop ke liye ask > entry chahiye"
new_buy = "if(isBuy  && entry <= ask) continue;   // FIX: BuyStop needs entry ABOVE ask"
# SellStop: entry must be BELOW bid -> skip when entry >= bid
old_sell = "if(!isBuy && bid >= entry) continue;   // SellStop ke liye bid < entry chahiye"
new_sell = "if(!isBuy && entry >= bid) continue;   // FIX: SellStop needs entry BELOW bid"

n = 0
if old_buy in s: s = s.replace(old_buy, new_buy, 1); n += 1
if old_sell in s: s = s.replace(old_sell, new_sell, 1); n += 1

open(F, "w", encoding="utf-8").write(s)
print(f"[fix] re-arm guard corrected ({n} lines). Ab MetaEditor mein F7 compile karein.")