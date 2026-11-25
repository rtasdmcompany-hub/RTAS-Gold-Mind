"use client";

import Link from "next/link";
import Image from "next/image";

export function EnterpriseFooter() {
  return (
    <footer
      style={{
        background: "#0a0a0a",
        borderTop: "1px solid #2a2a38",
        padding: "20px 24px 16px",
      }}
    >
      {/* Main row: Logos | Admin | Links */}
      <div
        style={{
          maxWidth: 1200,
          margin: "0 auto",
          display: "flex",
          flexWrap: "wrap",
          alignItems: "center",
          justifyContent: "center",
          gap: 20,
        }}
      >
        {/* 3 Logos in a row */}
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <Image
            src="/brand/footer-gold-mind.png"
            alt="RTAS Gold Mind"
            width={110}
            height={32}
            style={{ objectFit: "contain" }}
            unoptimized
          />
          <span style={{ color: "#333", fontSize: 14 }}>·</span>
          <Image
            src="/brand/footer-rtas-digital.png"
            alt="RTAS Digital Marketing"
            width={110}
            height={32}
            style={{ objectFit: "contain" }}
            unoptimized
          />
          <span style={{ color: "#333", fontSize: 14 }}>·</span>
          <Image
            src="/brand/footer-rtas-group.png"
            alt="RTAS Group"
            width={110}
            height={32}
            style={{ objectFit: "contain" }}
            unoptimized
          />
        </div>

        {/* Vertical divider */}
        <div
          style={{
            width: 1,
            height: 28,
            background: "#2a2a38",
            display: "inline-block",
          }}
        />

        {/* Admin Only button */}
        <Link
          href="/portal/admin"
          style={{
            padding: "7px 14px",
            borderRadius: 6,
            textDecoration: "none",
            color: "#0a0a0a",
            background: "linear-gradient(135deg, #f5c542, #c9971f)",
            fontSize: 12,
            fontWeight: 700,
            whiteSpace: "nowrap",
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
          Admin Only
        </Link>

        {/* Vertical divider */}
        <div
          style={{
            width: 1,
            height: 28,
            background: "#2a2a38",
            display: "inline-block",
          }}
        />

        {/* Links */}
        <div style={{ display: "flex", flexWrap: "wrap", gap: 16 }}>
          <Link
            href="/privacy"
            style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}
          >
            Privacy
          </Link>
          <Link
            href="/terms"
            style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}
          >
            Terms
          </Link>
          <Link
            href="/contact"
            style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}
          >
            Contact
          </Link>
          <Link
            href="/refund"
            style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}
          >
            Refunds
          </Link>
        </div>
      </div>

      {/* Copyright line */}
      <div
        style={{
          color: "#555",
          fontSize: 11,
          textAlign: "center",
          marginTop: 14,
          paddingTop: 12,
          borderTop: "1px solid #1a1a24",
        }}
      >
        © {new Date().getFullYear()} RTAS Gold Mind AI Professional. All rights reserved.
      </div>
    </footer>
  );
}