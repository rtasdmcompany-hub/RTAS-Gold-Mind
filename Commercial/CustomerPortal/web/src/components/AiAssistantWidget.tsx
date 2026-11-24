"use client";

import { useEffect, useRef, useState } from "react";

type AiSurface =
  | "website"
  | "customer_portal"
  | "partner_portal"
  | "admin_portal"
  | "mobile"
  | "support_center";

type Msg = { role: "user" | "assistant"; content: string };

const QUICK = [
  "Active promotions",
  "How do I install?",
  "Activate my license",
  "Website vs MQL5 pricing",
  "Refund policy",
];

export function AiAssistantWidget({
  surface = "customer_portal",
  role = "customer",
  customerEmail,
  title = "AI Assistant",
}: {
  surface?: AiSurface;
  role?: "anonymous" | "customer" | "partner" | "admin" | "support";
  customerEmail?: string;
  title?: string;
}) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [input, setInput] = useState("");
  const [msgs, setMsgs] = useState<Msg[]>([
    {
      role: "assistant",
      content:
        "Assalam-o-Alaikum! Main RTAS Gold Mind AI Assistant hoon. Plans, installation, licensing aur refunds ke baare mein poochein. (Trading signals nahi deta.)",
    },
  ]);
  const endRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [msgs, busy, open]);

  // Panel khulte hi agent ko warm-up karo (taake pehla sawaal 50s na ruke)
  useEffect(() => {
    if (!open) return;
    void fetch("/api/ai/render-chat", { cache: "no-store" }).catch(() => {});
  }, [open]);

  async function send(text?: string, attempt = 0) {
    const q = (text ?? input).trim().slice(0, 2000);
    if (!q || busy) return;
    setInput("");
    const next: Msg[] = [...msgs, { role: "user", content: q }];
    setMsgs(next);
    setBusy(true);
    try {
      const res = await fetch("/api/ai/render-chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: q,
          history: next.slice(-10).map((m) => ({ role: m.role, content: m.content })),
          surface,
          role,
          customerEmail,
        }),
      });
      const json = await res.json();
      if (json.ok) {
        setMsgs([...next, { role: "assistant", content: String(json.reply) }]);
      } else if (json.retry && attempt === 0) {
        setMsgs([
          ...next,
          {
            role: "assistant",
            content: "⏳ " + (typeof json.error === "string" ? json.error : "Agent jaag raha hai… 20 second mein dobara koshish."),
          },
        ]);
        setTimeout(() => {
          setMsgs(next);
          void send(q, 1);
        }, 20000);
        return;
      } else {
        const e = json.error;
        const msg =
          typeof e === "string"
            ? e
            : e && typeof e === "object" && "message" in e
            ? String(e.message)
            : "Jawab nahi mila";
        setMsgs([...next, { role: "assistant", content: `⚠️ ${msg}` }]);
      }
    } catch {
      setMsgs([...next, { role: "assistant", content: "⚠️ Network error. Dobara try karein." }]);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ position: "fixed", right: 16, bottom: 16, zIndex: 50 }}>
      {!open && (
        <button
          type="button"
          onClick={() => setOpen(true)}
          style={{
            background: "linear-gradient(135deg,#f5c542,#c9971f)",
            color: "#0a0a0a",
            border: "none",
            borderRadius: 10,
            padding: "10px 16px",
            fontWeight: 800,
            cursor: "pointer",
            boxShadow: "0 4px 18px rgba(245,197,66,.35)",
          }}
        >
          ◆ {title}
        </button>
      )}

      {open && (
        <div
          style={{
            width: 360,
            maxWidth: "92vw",
            height: 460,
            background: "#0a0a0a",
            border: "1px solid #c9971f",
            borderRadius: 12,
            display: "flex",
            flexDirection: "column",
            boxShadow: "0 12px 40px rgba(0,0,0,.6)",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "12px 14px",
              borderBottom: "1px solid #2a2a38",
            }}
          >
            <div>
              <strong style={{ color: "#f5c542" }}>{title}</strong>
              <div style={{ color: "#777", fontSize: 10, marginTop: 2 }}>
                RTAS AI Agent · Support only · Not financial advice
              </div>
            </div>
            <button
              type="button"
              onClick={() => setOpen(false)}
              style={{
                background: "transparent",
                border: "1px solid #333",
                color: "#ccc",
                borderRadius: 6,
                width: 28,
                height: 28,
                cursor: "pointer",
              }}
            >
              ✕
            </button>
          </div>

          <div style={{ flex: 1, overflowY: "auto", padding: "12px 12px 4px" }}>
            {msgs.map((m, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  justifyContent: m.role === "user" ? "flex-end" : "flex-start",
                  marginBottom: 10,
                }}
              >
                <div
                  style={{
                    maxWidth: "88%",
                    fontSize: 13,
                    lineHeight: 1.6,
                    padding: "8px 12px",
                    borderRadius:
                      m.role === "user" ? "14px 14px 4px 14px" : "14px 14px 14px 4px",
                    color: m.role === "user" ? "#ffe9a8" : "#f4f1e8",
                    background:
                      m.role === "user" ? "rgba(245,197,66,.15)" : "#16161d",
                    border: `1px solid ${
                      m.role === "user" ? "rgba(245,197,66,.35)" : "#2a2a38"
                    }`,
                    whiteSpace: "pre-wrap",
                    wordBreak: "break-word",
                  }}
                >
                  {m.content}
                </div>
              </div>
            ))}

            {busy && (
              <div style={{ display: "flex", gap: 5, padding: "2px 6px 8px" }}>
                {[0, 1, 2].map((i) => (
                  <span
                    key={i}
                    style={{
                      width: 7,
                      height: 7,
                      borderRadius: 99,
                      background: "#f5c542",
                      animation: `tgmBounce 1.1s ${i * 0.14}s infinite`,
                    }}
                  />
                ))}
              </div>
            )}
            <div ref={endRef} />
          </div>

          {msgs.length <= 1 && (
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6, padding: "0 12px 8px" }}>
              {QUICK.map((q) => (
                <button
                  key={q}
                  type="button"
                  onClick={() => void send(q)}
                  disabled={busy}
                  style={{
                    background: "#16161d",
                    border: "1px solid #2a2a38",
                    color: "#9a95a8",
                    borderRadius: 99,
                    padding: "5px 10px",
                    fontSize: 11,
                    cursor: "pointer",
                  }}
                >
                  {q}
                </button>
              ))}
            </div>
          )}

          <div style={{ borderTop: "1px solid #2a2a38", padding: 10 }}>
            <div style={{ display: "flex", gap: 8 }}>
              <input
                value={input}
                onChange={(e) => setInput(e.target.value.slice(0, 2000))}
                onKeyDown={(e) => {
                  if (e.key === "Enter") void send();
                }}
                placeholder="Sawaal likhein…"
                aria-label="AI message"
                style={{
                  flex: 1,
                  background: "#1b1b26",
                  border: "1px solid #2a2a38",
                  borderRadius: 8,
                  color: "#f4f1e8",
                  padding: "9px 11px",
                  fontSize: 13,
                  outline: "none",
                }}
              />
              <button
                type="button"
                onClick={() => void send()}
                disabled={busy || !input.trim()}
                style={{
                  background: "linear-gradient(135deg,#f5c542,#c9971f)",
                  color: "#0a0a0a",
                  border: "none",
                  borderRadius: 8,
                  padding: "9px 14px",
                  fontWeight: 800,
                  cursor: busy || !input.trim() ? "not-allowed" : "pointer",
                  opacity: busy || !input.trim() ? 0.5 : 1,
                }}
              >
                Send
              </button>
            </div>
          </div>

          <style>{`@keyframes tgmBounce{0%,80%,100%{transform:translateY(0);opacity:.4}40%{transform:translateY(-5px);opacity:1}}`}</style>
        </div>
      )}
    </div>
  );
}