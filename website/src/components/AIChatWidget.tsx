import { useState } from "react";

export default function AIChatWidget() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        style={{
          position: "fixed",
          right: 0,
          top: "50%",
          transform: "translateY(-50%)",
          zIndex: 9998,
          writingMode: "vertical-rl",
          background: "#0a0a0a",
          color: "#f5c542",
          border: "1px solid #c9971f",
          borderRight: "none",
          borderRadius: "12px 0 0 12px",
          padding: "18px 11px",
          fontSize: 13,
          fontWeight: 800,
          letterSpacing: 2,
          cursor: "pointer",
        }}
      >
        ASK AI
      </button>

      {open && (
        <div style={{ position: "fixed", inset: 0, zIndex: 9999 }}>
          <div
            onClick={() => setOpen(false)}
            style={{
              position: "absolute",
              inset: 0,
              background: "rgba(0,0,0,0.7)",
            }}
          />
          <div
            style={{
              position: "absolute",
              right: 0,
              top: 0,
              height: "100%",
              width: "min(440px, 100%)",
              background: "#0a0a0a",
              borderLeft: "1px solid #c9971f",
              display: "flex",
              flexDirection: "column",
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
              <div style={{ color: "#f5c542", fontWeight: 800, fontSize: 14 }}>
                RTAS Gold Mind AI
              </div>
              <button
                onClick={() => setOpen(false)}
                style={{
                  background: "transparent",
                  border: "1px solid #333",
                  color: "#ccc",
                  borderRadius: 6,
                  width: 30,
                  height: 30,
                  cursor: "pointer",
                  fontSize: 15,
                }}
              >
                X
              </button>
            </div>

            <iframe
              src="https://rtas-ai-agent.onrender.com/"
              title="RTAS AI Assistant"
              style={{
                width: "100%",
                height: "100%",
                border: "none",
                background: "#0a0a0a",
              }}
            />
          </div>
        </div>
      )}
    </>
  );
}