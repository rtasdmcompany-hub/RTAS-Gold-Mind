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
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 16,
        padding: "12px 24px",
        background: "#0a0a0a",
        borderBottom: "1px solid #2a2a38",
        flexWrap: "wrap",
      }}
    >
      {/* Left: User info */}
      <div style={{ display: "flex", alignItems: "center", gap: 12, flex: 1, minWidth: 200 }}>
        <UserAvatar name={name} image={image} size={40} />
        <div style={{ display: "flex", flexDirection: "column" }}>
          <span style={{ color: "#f4f1e8", fontSize: 14, fontWeight: 600 }}>
            {name || "Customer"}
          </span>
          <span style={{ color: "#f5c542", fontSize: 11, textTransform: "uppercase", letterSpacing: 0.5 }}>
            {role || "CUSTOMER"}
          </span>
        </div>
      </div>

      {/* Right: Actions */}
      <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
        <Link
          href="/"
          style={{
            padding: "8px 16px",
            borderRadius: 6,
            textDecoration: "none",
            color: "#d4d4d8",
            background: "transparent",
            border: "1px solid #2a2a38",
            fontSize: 13,
            fontWeight: 500,
            transition: "all 0.2s ease",
            whiteSpace: "nowrap",
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.borderColor = "#f5c542";
            e.currentTarget.style.color = "#f5c542";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.borderColor = "#2a2a38";
            e.currentTarget.style.color = "#d4d4d8";
          }}
        >
          ← Website Home
        </Link>

        <Link
          href="/api/auth/signout"
          style={{
            padding: "8px 16px",
            borderRadius: 6,
            textDecoration: "none",
            color: "#0a0a0a",
            background: "linear-gradient(135deg, #f5c542, #c9971f)",
            fontSize: 13,
            fontWeight: 700,
            transition: "all 0.2s ease",
            whiteSpace: "nowrap",
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.transform = "translateY(-1px)";
            e.currentTarget.style.boxShadow = "0 4px 12px rgba(245, 197, 66, 0.4)";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.transform = "translateY(0)";
            e.currentTarget.style.boxShadow = "none";
          }}
        >
          Sign out
        </Link>
      </div>
    </div>
  );
}