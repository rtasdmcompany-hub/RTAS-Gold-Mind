import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const AGENT_BASE = (
  process.env.RENDER_AGENT_URL ?? "https://rtas-ai-agent.onrender.com"
).replace(/\/+$/, "");

function pickReply(d: unknown): string {
  if (typeof d === "string") return d;
  if (!d || typeof d !== "object") return "";
  const obj = d as Record<string, unknown>;
  const keys = ["reply", "response", "answer", "text", "message", "output", "result"];
  for (const k of keys) {
    const v = obj[k];
    if (typeof v === "string" && v.trim()) return v;
  }
  const ch = obj.choices;
  if (Array.isArray(ch) && ch.length) {
    const first = ch[0] as Record<string, unknown> | undefined;
    const msg = first?.message as Record<string, unknown> | undefined;
    if (typeof msg?.content === "string") return msg.content;
  }
  return "";
}

async function tryEndpoint(
  path: string,
  body: Record<string, unknown>,
  ms: number
): Promise<Response | null> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    const r = await fetch(`${AGENT_BASE}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
      signal: ctrl.signal,
      cache: "no-store",
    });
    return r;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const message = String(body.message ?? "").trim().slice(0, 2000);
    if (!message)
      return NextResponse.json({ ok: false, error: "Message khali hai" }, { status: 400 });

    const history = Array.isArray(body.history)
      ? (body.history as Record<string, unknown>[])
      : [];
    const payload = { message, history };

    // Try multiple possible endpoints in order
    const endpoints = ["/chat", "/api/chat", "/ask", "/api/ask", "/v1/chat/completions"];
    let lastError = "";
    let lastStatus = 0;

    for (const ep of endpoints) {
      const r = await tryEndpoint(ep, payload, 30000);
      if (!r) {
        lastError = "timeout";
        continue;
      }
      lastStatus = r.status;
      // 200-299 = success
      if (r.ok) {
        const raw = await r.text();
        let data: unknown = raw;
        try { data = JSON.parse(raw); } catch { /* plain text */ }
        const reply = pickReply(data).trim();
        if (reply) return NextResponse.json({ ok: true, reply });
        lastError = "empty reply";
        continue;
      }
      // 404 = endpoint doesn't exist, try next
      if (r.status === 404) {
        lastError = `404 on ${ep}`;
        continue;
      }
      // Other error
      lastError = `HTTP ${r.status} on ${ep}`;
    }

    // All endpoints failed — try wake-up then retry once
    await fetch(`${AGENT_BASE}/`, { cache: "no-store" }).catch(() => {});
    await new Promise((res) => setTimeout(res, 8000));

    const r2 = await tryEndpoint("/chat", payload, 60000);
    if (r2 && r2.ok) {
      const raw = await r2.text();
      let data: unknown = raw;
      try { data = JSON.parse(raw); } catch { /* plain text */ }
      const reply = pickReply(data).trim();
      if (reply) return NextResponse.json({ ok: true, reply });
    }

    return NextResponse.json(
      {
        ok: false,
        retry: true,
        error: `Agent jawab nahi de raha (last: ${lastError || lastStatus})`,
      },
      { status: 502 }
    );
  } catch {
    return NextResponse.json(
      { ok: false, retry: true, error: "Agent tak pohanch namumkin" },
      { status: 503 }
    );
  }
}

export async function GET() {
  try {
    const r = await fetch(`${AGENT_BASE}/`, { cache: "no-store" });
    return NextResponse.json({ ok: r.ok, status: r.status });
  } catch {
    return NextResponse.json({ ok: false }, { status: 503 });
  }
}