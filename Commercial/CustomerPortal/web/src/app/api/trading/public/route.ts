import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  // Placeholder - return empty data for now
  return NextResponse.json({
    ok: true,
    trades: [],
    signals: [],
    message: "Live trading data not available yet",
  });
}