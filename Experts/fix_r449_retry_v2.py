import os, re

F = "RTAS_Gold_Mind_Automatic_Trading_Software.mq5"
if not os.path.exists(F):
    print("❌ File not found! Make sure you are in the Experts folder.")
    input("Press Enter...")
    exit()

s = open(F, encoding="utf-8").read()

old_pattern = r'if\(g_trade\.PositionClosePartial\(ticket, closeVol\)\)\s*\{\s*booked = true;\s*PrintFormat\("TGM \[R449\]: #%I64u \+%.1fpip -> %.2f lots booked \(%\.0f%%\)\.",\s*ticket, pips, closeVol, InpPartialPercent\);\s*\}\s*else\s*PrintFormat\("TGM \[R449\]: #%I64u partial FAILED retcode=%u", ticket, g_trade\.ResultRetcode\(\)\);'

new_block = """// Retry logic for partial close (fixes retcode 10009 requote)
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
        if(retry < 2) Sleep(500);
    }
}
if(partialSuccess) booked = true;
else PrintFormat("TGM [R449]: #%I64u partial FAILED after 3 retries", ticket);"""

if re.search(old_pattern, s):
    s = re.sub(old_pattern, new_block, s, count=1)
    open(F, "w", encoding="utf-8").write(s)
    print("✅ R449 retry logic applied successfully!")
    print("   Ab 3 baar retry karega agar broker requote (10009) de.")
else:
    print("⚠️ Code block not found. Check if it was already updated.")

input("Press Enter to exit...")