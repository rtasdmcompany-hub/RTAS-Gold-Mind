import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const AGENT = (process.env.RENDER_AGENT_URL ?? "https://rtas-ai-agent.onrender.com").replace(/\/+$/, "");

function pick(d: unknown): string {
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

/** POST /api/ai/render-chat  →  Render agent /chat */
export async function POST(req: NextRequest) {
  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const message = String(body.message ?? "").trim().slice(0, 2000);
    
    if (!message) {
      return NextResponse.json({ ok: false, error: "Message khali hai" }, { status: 400 });
    }

    const history = Array.isArray(body.history) 
      ? (body.history as Record<string, unknown>[]) 
      : [];

    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 55000);
    let r: Response;
    
    try {
      r = await fetch(`${AGENT}/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ message, history }),
        signal: ctrl.signal,
        cache: "no-store",
      });
    } finally {
      clearTimeout(timer);
    }

    const raw = await r.text();
    let data: unknown = raw;
    try {
      data = JSON.parse(raw);
    } catch {
      /* plain text */
    }

    if (!r.ok) {
      return NextResponse.json(
        {
          ok: false,
          error: `Agent HTTP ${r.status}`,
          detail: typeof data === "string" ? data.slice(0, 200) : data,
        },
        { status: 502 }
      );
    }

    const reply = pick(data).trim();
    if (!reply) {
      return NextResponse.json({ ok: false, error: "Agent ne khali jawab diya", raw: data }, { status: 502 });
    }

    return NextResponse.json({ ok: true, reply });
  } catch (e: unknown) {
    const err = e as Error;
    const cold = err?.name === "AbortError";
    return NextResponse.json(
      {
        ok: false,
        retry: true,
        error: cold ? "Agent jaag raha hai (cold start)" : "Agent tak pohanch namumkin",
      },
      { status: 503 }
    );
  }
}

/** GET /api/ai/render-chat → health check */
export async function GET() {
  try {
    const r = await fetch(`${AGENT}/openapi.json`, { cache: "no-store" });
    const j = await r.json().catch(() => null);
    return NextResponse.json({ ok: r.ok, agent: j });
  } catch {
    return NextResponse.json({ ok: false, agent: null }, { status: 503 });
  }
}