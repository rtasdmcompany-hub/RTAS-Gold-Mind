# RTAS Gold Mind EA - Update Log (Version 2.220 / Build 448)

**Date:** November 17, 2026  
**File:** `RTAS_Gold_Mind_Automatic_Trading_Software.mq5`  
**Status:** ✅ Live Tested & Verified on XAUUSD (H4)

---

## 📋 Summary of Changes (Khulasa)

Is update mein hum ne EA ki 3 sab se bari logic ko fix aur optimize kiya hai taake wo live market mein behtar perform kare.

### 1️⃣ Partial Close 50% se barha kar 70% kar diya (R449 Profit Formula)
- **Pehle:** Jab trade +50 pips profit mein jata tha, to 50% lot close hota tha.
- **Ab:** +50 pips par **70% lot** book ho jata hai, aur baqi 30% runner ban kar 30 pip gap se trail karta hai.
- **Faida:** Profit jaldi lock hota hai aur risk kam ho jata hai.
- **Code Location:** `input double InpPartialPercent = 70.0;`

### 2️⃣ 300+ Pip Range (Bari Candle) par bhi LIMIT Orders (R445 Range Router)
- **Pehle:** Jab H4 candle 300 pips se bari hoti thi, to EA "Breakout Mode" mein chala jata tha aur STOP orders lagata tha.
- **Ab:** Ab har range (chhoti ya bari) mein EA **LIMIT orders** (Mean Reversion) use karta hai. Yani Low ke neeche BuyLimit aur High ke upar SellLimit.
- **Faida:** Market ke fake breakouts se bachao aur consistent grid placement.
- **Code Location:** `bool ResearchInvertedUsesBreakoutPlacement()` function ab hamesha `return false;` karta hai.

### 3️⃣ Level 2 (L2) Re-Arm Ab Sab Ranges Mein Kaam Karega (R450 Fix)
- **Masla:** Pehle L2 ka Re-Arm (SL hit hone par 5 min baad 1 baar wapis order lagana) sirf chhoti range (≤250 pips) mein kaam karta tha. Bari range mein L2 SL hit hone par level hamesha ke liye SPENT ho jata tha.
- **Fix:** `ManageL2ReArm()` function se `if(rangePips > SmallRangePips) return;` wali line delete kar di gayi.
- **Ab:** L2 SL hit hone par, chahe range koi bhi ho, 5 minute baad ek STOP order se re-arm hoga. Agar wo bhi hit ho jaye, to level agle H4 tak ke liye permanently close ho jayega.
- **Faida:** Market ke whipsaw (jhatkon) se bachne ka ek aur mauqa milta hai.

---

## 🧪 Live Testing Verification (17-Nov-2026)

Aaj live market (XAUUSD) mein in changes ko test kiya gaya:
- ✅ **365 Pip Range:** Bari candle par bhi `BuyLimit` aur `SellLimit` orders place hue (Breakout nahi hua).
- ✅ **L2 Re-Arm:** 365 pip range mein bhi `GM_SL2` close hone par 5 min baad STOP re-arm trigger hua (jo pehle nahi hota tha).
- ✅ **Fixed SL/TP:** Har level par 100 pip SL aur 200 pip TP verified.
- ✅ **Risk:** 3% Equity compounding lot sizing sahi kaam kar rahi hai.

---

## ⏳ Pending / Agla Qadam

1. **Partial Close (70%) Verification:** Abhi pending orders fill hone ka intezar hai. Jab pehla trade +50 pips par pahunchega, journal mein `TGM [R449]: ... 0.22 lots booked (70%)` ka log check karna hai.
2. **AI Agent Update:** Jab 70% partial close bhi verify ho jaye, to hum `RTAS-AI-Agent` project ki `data/knowledge.json` file ko update karenge taake AI agent clients ko yehi **sahi aur verified strategy** bataye.

---

## ⚠️ Important Notes for Future Development

- **Secret Multipliers:** Grid levels `0.20`, `0.58`, aur `0.92` ke multipliers se calculate hote hain. Ye proprietary hain.
- **No ATR for SL:** SL aur TP ab ATR par depend nahi karte. Ye fixed 100/200 pips hain.
- **EMA/ADX:** Router mein EMA 50/200 aur ADX 20/25 mojood hain, lekin wo sirf **logging** ke liye hain. Wo grid placement ko block NAHI karte ("direction never gates").

---
*Documented by: RTAS AI Development Team*