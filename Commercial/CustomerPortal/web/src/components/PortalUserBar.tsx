"use client";

import Link from "next/link";
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
  const isAdmin = ["super_admin", "admin", "owner", "administrator", "commercial_manager", "support_agent", "support", "finance_manager", "qa_manager", "auditor"].includes((role || "").toLowerCase());

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 12,
        padding: "10px 20px",
        background: "#111118",
        borderBottom: "1px solid #2a2a38",
        flexWrap: "wrap",
      }}
    >
      {/* Left: avatar + first name */}
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <UserAvatar name={name} image={image} size={32} />
        <span style={{ color: "#f4f1e8", fontSize: 14, fontWeight: 600, whiteSpace: "nowrap" }}>
          {firstName}
        </span>
        {isAdmin && (
          <span
            style={{
              color: "#f5c542",
              fontSize: 10,
              fontWeight: 700,
              border: "1px solid rgba(245,197,66,.4)",
              borderRadius: 99,
              padding: "2px 8px",
              letterSpacing: 0.5,
            }}
          >
            ADMIN
          </span>
        )}
      </div>

      {/* Right: icon buttons */}
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <Link
          href="/"
          title="Website Home"
          aria-label="Website Home"
          style={{
            width: 36,
            height: 36,
            borderRadius: 8,
            display: "grid",
            placeItems: "center",
            textDecoration: "none",
            color: "#d4d4d8",
            border: "1px solid #2a2a38",
            fontSize: 16,
          }}
        >
          🏠
        </Link>

        <Link
          href="/api/auth/signout"
          title="Sign out"
          aria-label="Sign out"
          style={{
            width: 36,
            height: 36,
            borderRadius: 8,
            display: "grid",
            placeItems: "center",
            textDecoration: "none",
            color: "#0a0a0a",
            background: "linear-gradient(135deg,#f5c542,#c9971f)",
            fontSize: 16,
            fontWeight: 800,
          }}
        >
          ⏻
        </Link>
      </div>
    </div>
  );
}