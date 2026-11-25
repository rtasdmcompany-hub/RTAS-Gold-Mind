"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";

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

  // Admin button sirf admin role par dikhe
  const isAdmin = role === "admin" || role === "support";

  return (
    <>
      <style>{`
        .ai-widget-container {
          position: fixed;
          right: 20px;
          bottom: 20px;
          z-index: 9999;
        }
        .ai-robot-logo {
          width: 70px;
          height: 70px;
          border-radius: 50%;
          overflow: hidden;
          border: 2px solid #f5c542;
          box-shadow: 0 4px 20px rgba(245, 197, 66, 0.5);
          animation: tgmFloat 3s ease-in-out infinite;
          background: #0a0a0a;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .ai-robot-logo img {
          width: 100%;
          height: 100%;
          object-fit: cover;
          display: block;
        }
        .ai-trigger-btn {
          background: linear-gradient(135deg, #f5c542, #c9971f);
          color: #0a0a0a;
          border: none;
          border-radius: 10px;
          padding: 10px 16px;
          font-weight: 800;
          font-size: 13px;
          cursor: pointer;
          box-shadow: 0 4px 18px rgba(245, 197, 66, 0.35);
          animation: tgmPulse 2s ease-in-out infinite;
        }
        .ai-panel {
          position: fixed;
          right: 20px;
          bottom: 20px;
          width: 380px;
          max-width: 92vw;
          height: 500px;
          background: #0a0a0a;
          border: 1px solid #c9971f;
          border-radius: 12px;
          display: flex;
          flex-direction: column;
          box-shadow: 0 12px 40px rgba(0, 0, 0, 0.7);
          overflow: hidden;
          transition: all 0.3s ease;
          z-index: 9999;
        }
        .ai-panel.minimized {
          width: 280px;
          height: 60px;
        }
        .ai-panel-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 10px 12px;
          border-bottom: 1px solid #2a2a38;
          background: linear-gradient(180deg, #1a1a24, #0a0a0a);
        }
        .ai-panel-header-logo {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          border: 1px solid #f5c542;
          object-fit: cover;
        }
        .ai-panel-body {
          flex: 1;
          overflow-y: auto;
          padding: 12px 12px 4px;
        }
        .ai-msg {
          display: flex;
          margin-bottom: 10px;
        }
        .ai-msg.user {
          justify-content: flex-end;
        }
        .ai-msg.assistant {
          justify-content: flex-start;
        }
        .ai-msg-bubble {
          max-width: 88%;
          font-size: 13px;
          line-height: 1.6;
          padding: 8px 12px;
          white-space: pre-wrap;
          word-break: break-word;
        }
        .ai-msg-bubble.user {
          border-radius: 14px 14px 4px 14px;
          color: #ffe9a8;
          background: rgba(245, 197, 66, 0.15);
          border: 1px solid rgba(245, 197, 66, 0.35);
        }
        .ai-msg-bubble.assistant {
          border-radius: 14px 14px 14px 4px;
          color: #f4f1e8;
          background: #16161d;
          border: 1px solid #2a2a38;
        }
        .ai-quick-btn {
          background: #16161d;
          border: 1px solid #2a2a38;
          color: #9a95a8;
          border-radius: 99px;
          padding: 5px 10px;
          font-size: 11px;
          cursor: pointer;
        }
        .ai-input {
          flex: 1;
          background: #1b1b26;
          border: 1px solid #2a2a38;
          border-radius: 8px;
          color: #f4f1e8;
          padding: 9px 11px;
          font-size: 13px;
          outline: none;
        }
        .ai-send-btn {
          background: linear-gradient(135deg, #f5c542, #c9971f);
          color: #0a0a0a;
          border: none;
          border-radius: 8px;
          padding: 9px 14px;
          font-weight: 800;
          cursor: pointer;
        }
        .ai-send-btn:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }
        .ai-icon-btn {
          background: transparent;
          border: 1px solid #333;
          color: #ccc;
          border-radius: 6px;
          width: 26px;
          height: 26px;
          cursor: pointer;
          font-size: 12px;
          display: grid;
          place-items: center;
        }
        .ai-mobile-overlay {
          position: fixed;
          inset: 0;
          background: rgba(0, 0, 0, 0.5);
          z-index: 9998;
        }
        .admin-float-btn {
          position: fixed;
          left: 20px;
          bottom: 20px;
          z-index: 9999;
          display: inline-flex;
          align-items: center;
          gap: 6px;
          background: linear-gradient(135deg, #f5c542, #c9971f);
          color: #0a0a0a;
          border-radius: 10px;
          padding: 10px 16px;
          font-weight: 800;
          font-size: 13px;
          text-decoration: none;
          box-shadow: 0 4px 18px rgba(245, 197, 66, 0.35);
          animation: adminPulse 2s ease-in-out infinite;
        }
        @keyframes adminPulse {
          0%, 100% { box-shadow: 0 4px 18px rgba(245, 197, 66, 0.35); }
          50% { box-shadow: 0 4px 30px rgba(245, 197, 66, 0.7); }
        }
        @keyframes tgmBounce {
          0%, 80%, 100% { transform: translateY(0); opacity: 0.4; }
          40% { transform: translateY(-5px); opacity: 1; }
        }
        @keyframes tgmPulse {
          0%, 100% { box-shadow: 0 4px 18px rgba(245, 197, 66, 0.35); }
          50% { box-shadow: 0 4px 30px rgba(245, 197, 66, 0.7); }
        }
        @keyframes tgmFloat {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-6px); }
        }
        @media (max-width: 767px) {
          .ai-widget-container {
            right: 10px;
            bottom: 10px;
          }
          .ai-robot-logo {
            width: 50px;
            height: 50px;
          }
          .ai-trigger-btn {
            padding: 8px 12px;
            font-size: 12px;
          }
          .ai-panel {
            position: fixed;
            left: 0;
            right: 0;
            bottom: 0;
            width: 100%;
            max-width: 100%;
            height: 85vh;
            border-radius: 16px 16px 0 0;
            border: none;
            border-top: 1px solid #c9971f;
          }
          .ai-panel.minimized {
            width: 100%;
            height: 60px;
          }
          .admin-float-btn {
            left: 10px;
            bottom: 10px;
            padding: 8px 12px;
            font-size: 12px;
          }
        }
      `}</style>

      {/* Admin Only button - left bottom, sirf admin/support role par */}
      {isAdmin && (
        <Link href="/portal/admin" className="admin-float-btn" aria-label="Admin Only">
          ◆ Admin Only
        </Link>
      )}

      <div className="ai-widget-container">
        {!open && (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
            <div className="ai-robot-logo">
              <img src={ROBOT_LOGO} alt="RTAS AI" />
            </div>
            <button
              type="button"
              className="ai-trigger-btn"
              onClick={() => {
                setOpen(true);
                setMinimized(false);
              }}
            >
              ◆ {title}
            </button>
          </div>
        )}

        {open && (
          <>
            {/* Mobile overlay */}
            <div
              className="ai-mobile-overlay"
              style={{ display: typeof window !== "undefined" && window.innerWidth < 768 ? "block" : "none" }}
              onClick={() => setOpen(false)}
            />

            <div className={`ai-panel${minimized ? " minimized" : ""}`}>
              <div className="ai-panel-header">
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <img src={ROBOT_LOGO} alt="AI" className="ai-panel-header-logo" />
                  <div>
                    <strong style={{ color: "#f5c542", fontSize: 13 }}>{title}</strong>
                    <div style={{ color: "#777", fontSize: 9 }}>RTAS AI · Support only</div>
                  </div>
                </div>
                <div style={{ display: "flex", gap: 4 }}>
                  <button
                    type="button"
                    className="ai-icon-btn"
                    onClick={() => setMinimized(!minimized)}
                    title={minimized ? "Maximize" : "Minimize"}
                    style={{ display: typeof window !== "undefined" && window.innerWidth < 768 ? "none" : "grid" }}
                  >
                    {minimized ? "⬜" : "—"}
                  </button>
                  <button
                    type="button"
                    className="ai-icon-btn"
                    onClick={() => setOpen(false)}
                    title="Close"
                  >
                    ✕
                  </button>
                </div>
              </div>

              {!minimized && (
                <>
                  <div className="ai-panel-body">
                    {msgs.map((m, i) => (
                      <div key={i} className={`ai-msg ${m.role}`}>
                        <div className={`ai-msg-bubble ${m.role}`}>{m.content}</div>
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
                          className="ai-quick-btn"
                          onClick={() => void send(q)}
                          disabled={busy}
                        >
                          {q}
                        </button>
                      ))}
                    </div>
                  )}

                  <div style={{ borderTop: "1px solid #2a2a38", padding: 10 }}>
                    <div style={{ display: "flex", gap: 8 }}>
                      <input
                        className="ai-input"
                        value={input}
                        onChange={(e) => setInput(e.target.value.slice(0, 2000))}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") void send();
                        }}
                        placeholder="Sawaal likhein…"
                        aria-label="AI message"
                      />
                      <button
                        type="button"
                        className="ai-send-btn"
                        onClick={() => void send()}
                        disabled={busy || !input.trim()}
                      >
                        Send
                      </button>
                    </div>
                  </div>
                </>
              )}
            </div>
          </>
        )}
      </div>
    </>
  );
}