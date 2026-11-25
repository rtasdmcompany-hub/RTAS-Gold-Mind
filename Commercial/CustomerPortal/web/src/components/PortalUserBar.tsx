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
  // Sirf first name lo
  const firstName = (name || "User").split(/\s+/)[0];

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 12,
        padding: "10px 20px",
        background: "#0a0a0a",
        borderBottom: "1px solid #2a2a38",
      }}
    >
      {/* Left: Avatar + First Name */}
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <UserAvatar name={name} image={image} size={32} />
        <span
          style={{
            color: "#f4f1e8",
            fontSize: 14,
            fontWeight: 600,
            whiteSpace: "nowrap",
          }}
        >
          {firstName}
        </span>
      </div>

      {/* Right: Icon Buttons */}
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
            background: "transparent",
            border: "1px solid #2a2a38",
            fontSize: 16,
            transition: "all 0.2s ease",
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
            background: "linear-gradient(135deg, #f5c542, #c9971f)",
            fontSize: 16,
            transition: "all 0.2s ease",
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
          ⏻
        </Link>
      </div>
    </div>
  );
}