F = "RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
s = open(F, encoding="utf-8").read()

# Current code mein ye line hai:
# if(g_trade.PositionClosePartial(ticket, closeVol))
# Iske baad retry logic add karna hai

old_code = """if(g_trade.PositionClosePartial(ticket, closeVol))
{
booked = true;
PrintFormat("TGM [R449]: #%I64u +%.1fpip -> %.2f lots booked (%.0f%%).",
ticket, pips, closeVol, InpPartialPercent);
}
else
PrintFormat("TGM [R449]: #%I64u partial FAILED retcode=%u", ticket, g_trade.ResultRetcode());"""

new_code = """// Retry logic: 3 baar try karo with increasing slippage
bool partialSuccess = false;
for(int retry = 0; retry < 3; retry++)
{
g_trade.SetDeviationInPoints((ulong)(TGM_BASE_DEVIATION_PTS * (retry + 1)));
if(g_trade.PositionClosePartial(ticket, closeVol))
{
partialSuccess = true;
PrintFormat("TGM [R449]: #%I64u +%.1fpip -> %.2f lots booked (%.0f%%) [retry %d].",
ticket, pips, closeVol, InpPartialPercent, retry + 1);
break;
}
else
{
PrintFormat("TGM [R449]: #%I64u partial attempt %d FAILED retcode=%u", 
ticket, retry + 1, g_trade.ResultRetcode());
if(retry < 2) Sleep(500); // 500ms wait before retry
}
}
if(partialSuccess) booked = true;
else PrintFormat("TGM [R449]: #%I64u partial FAILED after 3 retries", ticket);"""

if old_code in s:
    s = s.replace(old_code, new_code, 1)
    print("✅ R449 retry logic added (3 attempts with slippage tolerance)")
else:
    print("⚠️ Could not find exact code block")

open(F, "w", encoding="utf-8").write(s)
print("Done. MetaEditor mein F7 compile karein.")