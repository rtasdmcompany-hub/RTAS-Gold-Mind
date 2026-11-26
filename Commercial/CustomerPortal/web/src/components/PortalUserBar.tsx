"use client";

import Link from "next/link";
import { useState } from "react";
import { signOut } from "next-auth/react";
import { UserAvatar } from "@/components/BrandLogo";

export function PortalUserBar({
  name,
  email,
  image,
  role,
}: {
  name?: string | null;
  email?: string | null;
  image?: string | null;
  role?: string;
}) {
  const firstName = (name || "User").split(/\s+/)[0];
  const isAdmin = [
    "super_admin", "admin", "owner", "administrator",
    "commercial_manager", "support_agent", "support",
    "finance_manager", "qa_manager", "auditor",
  ].includes((role || "").toLowerCase());

  const [confirmOpen, setConfirmOpen] = useState(false);

  return (
    <>
      <div
        style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          gap: 12, padding: "10px 20px", background: "#111118",
          borderBottom: "1px solid #2a2a38", flexWrap: "wrap",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <UserAvatar name={name} image={image} size={32} />
          <span style={{ color: "#f4f1e8", fontSize: 14, fontWeight: 600, whiteSpace: "nowrap" }}>
            {firstName}
          </span>
          {isAdmin && (
            <span style={{ color: "#f5c542", fontSize: 10, fontWeight: 700, border: "1px solid rgba(245,197,66,.4)", borderRadius: 99, padding: "2px 8px", letterSpacing: 0.5 }}>
              ADMIN
            </span>
          )}
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Link
            href="/"
            title="Website Home"
            aria-label="Website Home"
            style={{
              width: 36, height: 36, borderRadius: 8, display: "grid", placeItems: "center",
              textDecoration: "none", color: "#d4d4d8", border: "1px solid #2a2a38",
            }}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
              <polyline points="9 22 9 12 15 12 15 22" />
            </svg>
          </Link>

          <button
            type="button"
            onClick={() => setConfirmOpen(true)}
            title="Sign out"
            aria-label="Sign out"
            style={{
              width: 36, height: 36, borderRadius: 8, display: "grid", placeItems: "center",
              color: "#0a0a0a", background: "linear-gradient(135deg,#f5c542,#c9971f)",
              border: "none", cursor: "pointer",
            }}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </div>

      {/* Confirm popup */}
      {confirmOpen && (
        <>
          <div
            onClick={() => setConfirmOpen(false)}
            style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.7)", zIndex: 10002, backdropFilter: "blur(3px)" }}
          />
          <div
            style={{
              position: "fixed", top: "50%", left: "50%", transform: "translate(-50%,-50%)",
              width: 340, maxWidth: "90vw", background: "#111118",
              border: "1px solid #c9971f", borderRadius: 14, padding: 24, zIndex: 10003,
              boxShadow: "0 16px 50px rgba(0,0,0,0.8)",
            }}
          >
            <h3 style={{ color: "#f5c542", fontSize: 17, margin: "0 0 8px" }}>Sign out?</h3>
            <p style={{ color: "#9a95a8", fontSize: 13, margin: "0 0 20px", lineHeight: 1.5 }}>
              Aap {firstName} ke account se logout ho jayenge. Website aur portal access karne ke liye dobara login karna hoga.
            </p>
            <div style={{ display: "flex", gap: 10 }}>
              <button
                type="button"
                onClick={() => setConfirmOpen(false)}
                style={{
                  flex: 1, padding: "10px 14px", borderRadius: 8, cursor: "pointer",
                  background: "transparent", border: "1px solid #2a2a38", color: "#d4d4d8",
                  fontSize: 14, fontWeight: 600,
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => {
                  setConfirmOpen(false);
                  void signOut({ callbackUrl: "/login" });
                }}
                style={{
                  flex: 1, padding: "10px 14px", borderRadius: 8, cursor: "pointer",
                  background: "linear-gradient(135deg,#f5c542,#c9971f)", border: "none",
                  color: "#0a0a0a", fontSize: 14, fontWeight: 800,
                }}
              >
                Yes, Sign out
              </button>
            </div>
          </div>
        </>
      )}
    </>
  );
}