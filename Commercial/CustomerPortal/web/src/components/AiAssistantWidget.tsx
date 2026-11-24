"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";

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

const ROBOT_LOGO = "/robot.png";

export function AiAssistantWidget({
  surface = "customer_portal",
  role = "customer",
  customerEmail,
  title = "May I help you?",
}: {
  surface?: AiSurface;
  role?: "anonymous" | "customer" | "partner" | "admin" | "support";
  customerEmail?: string;
  title?: string;
}) {
  const [open, setOpen] = useState(false);
  const [minimized, setMinimized] = useState(false);
  const [busy, setBusy] = useState(false);
  const [input, setInput] = useState("");
  const [isMobile, setIsMobile] = useState(false);
  const [msgs, setMsgs] = useState<Msg[]>([
    {
      role: "assistant",
      content:
        "May I help you? 👋\n\nMain RTAS Gold Mind AI Assistant hoon. Plans, installation, licensing aur refunds ke baare mein poochein. (Trading signals nahi deta.)",
    },
  ]);
  const endRef = useRef<HTMLDivElement | null>(null);
  const autoShowTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pageKeyRef = useRef<string>("");

  // Mobile detection
  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [msgs, busy, open, minimized]);

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (pageKeyRef.current && pageKeyRef.current !== currentPath) {
      setOpen(true);
      setMinimized(false);
    }
    pageKeyRef.current = currentPath;

    autoShowTimerRef.current = setTimeout(() => {
      if (!open || minimized) {
        setOpen(true);
        setMinimized(false);
      }
    }, 180000);

    return () => {
      if (autoShowTimerRef.current) clearTimeout(autoShowTimerRef.current);
    };
  }, [open, minimized]);

  async function send(text?: string) {
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
      } else if (json.retry) {
        setMsgs([
          ...next,
          {
            role: "assistant",
            content: "⏳ " + (typeof json.error === "string" ? json.error : "Agent jaag raha hai…"),
          },
        ]);
        setTimeout(() => {
          setMsgs(next);
          void send(q);
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

  // Mobile: widget full-screen bottom sheet
  const panelStyle = isMobile
    ? {
        position: "fixed" as const,
        left: 0,
        right: 0,
        bottom: 0,
        width: "100%",
        maxWidth: "100%",
        height: minimized ? 60 : "85vh",
        background: "#0a0a0a",
        borderTop: "1px solid #c9971f",
        borderBottom: "none",
        borderLeft: "none",
        borderRight: "none",
        borderRadius: "16px 16px 0 0",
        display: "flex",
        flexDirection: "column" as const,
        boxShadow: "0 -8px 40px rgba(0,0,0,.7)",
        overflow: "hidden",
        transition: "all 0.3s ease",
        zIndex: 9999,
      }
    : {
        position: "fixed" as const,
        right: 20,
        bottom: 20,
        width: minimized ? 280 : 380,
        maxWidth: "92vw",
        height: minimized ? 60 : 500,
        background: "#0a0a0a",
        border: "1px solid #c9971f",
        borderRadius: 12,
        display: "flex",
        flexDirection: "column" as const,
        boxShadow: "0 12px 40px rgba(0,0,0,.7)",
        overflow: "hidden",
        transition: "all 0.3s ease",
        zIndex: 9999,
      };

  return (
    <>
      {/* Mobile overlay jab widget open ho */}
      {open && isMobile && (
        <div
          onClick={() => setOpen(false)}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0,0,0,0.5)",
            zIndex: 9998,
          }}
        />
      )}

      <div style={{ position: "fixed", right: 20, bottom: 20, zIndex: 9999 }}>
        {!open && (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
            <div
              style={{
                width: isMobile ? 56 : 70,
                height: isMobile ? 56 : 70,
                borderRadius: "50%",
                overflow: "hidden",
                border: "2px solid #f5c542",
                boxShadow: "0 4px 20px rgba(245,197,66,.5)",
                animation: "tgmFloat 3s ease-in-out infinite",
                background: "#0a0a0a",
              }}
            >
              <Image
                src={ROBOT_LOGO}
                alt="RTAS AI"
                width={isMobile ? 56 : 70}
                height={isMobile ? 56 : 70}
                style={{ width: "100%", height: "100%", objectFit: "cover" }}
              />
            </div>
            <button
              type="button"
              onClick={() => {
                setOpen(true);
                setMinimized(false);
              }}
              style={{
                background: "linear-gradient(135deg,#f5c542,#c9971f)",
                color: "#0a0a0a",
                border: "none",
                borderRadius: 10,
                padding: isMobile ? "8px 12px" : "10px 16px",
                fontWeight: 800,
                fontSize: isMobile ? 12 : 13,
                cursor: "pointer",
                boxShadow: "0 4px 18px rgba(245,197,66,.35)",
                animation: "tgmPulse 2s ease-in-out infinite",
              }}
            >
              ◆ {title}
            </button>
          </div>
        )}

        {open && (
          <div style={panelStyle}>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "10px 12px",
                borderBottom: "1px solid #2a2a38",
                background: "linear-gradient(180deg,#1a1a24,#0a0a0a)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <Image
                  src={ROBOT_LOGO}
                  alt="AI"
                  width={32}
                  height={32}
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: "50%",
                    border: "1px solid #f5c542",
                    objectFit: "cover",
                  }}
                />
                <div>
                  <strong style={{ color: "#f5c542", fontSize: 13 }}>{title}</strong>
                  <div style={{ color: "#777", fontSize: 9 }}>RTAS AI · Support only</div>
                </div>
              </div>
              <div style={{ display: "flex", gap: 4 }}>
                {!isMobile && (
                  <button
                    type="button"
                    onClick={() => setMinimized(!minimized)}
                    title={minimized ? "Maximize" : "Minimize"}
                    style={{
                      background: "transparent",
                      border: "1px solid #333",
                      color: "#ccc",
                      borderRadius: 6,
                      width: 26,
                      height: 26,
                      cursor: "pointer",
                      fontSize: 12,
                      display: "grid",
                      placeItems: "center",
                    }}
                  >
                    {minimized ? "⬜" : "—"}
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  title="Close"
                  style={{
                    background: "transparent",
                    border: "1px solid #333",
                    color: "#ccc",
                    borderRadius: 6,
                    width: 26,
                    height: 26,
                    cursor: "pointer",
                    fontSize: 12,
                    display: "grid",
                    placeItems: "center",
                  }}
                >
                  ✕
                </button>
              </div>
            </div>

            {!minimized && (
              <>
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
              </>
            )}
          </div>
        )}
      </div>

      <style>{`
        @keyframes tgmBounce{0%,80%,100%{transform:translateY(0);opacity:.4}40%{transform:translateY(-5px);opacity:1}}
        @keyframes tgmPulse{0%,100%{box-shadow:0 4px 18px rgba(245,197,66,.35)}50%{box-shadow:0 4px 30px rgba(245,197,66,.7)}}
        @keyframes tgmFloat{0%,100%{transform:translateY(0)}50%{transform:translateY(-6px)}}
      `}</style>
    </>
  );
}