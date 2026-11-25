import Link from "next/link";
import { BrandLogo } from "@/components/BrandLogo";

export function EnterpriseFooter() {
  return (
    <footer
      style={{
        background: "#0a0a0a",
        borderTop: "1px solid #2a2a38",
        padding: "32px 24px 20px",
      }}
    >
      <div
        style={{
          maxWidth: 1200,
          margin: "0 auto",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 20,
        }}
      >
        {/* Sirf 1 Gold Mind logo */}
        <BrandLogo variant="footer" href="/" />

        {/* Compact links — sirf 4 zaroori */}
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            justifyContent: "center",
            gap: 20,
          }}
        >
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

        {/* Copyright */}
        <div
          style={{
            color: "#555",
            fontSize: 11,
            textAlign: "center",
            borderTop: "1px solid #1a1a24",
            paddingTop: 16,
            width: "100%",
          }}
        >
          © {new Date().getFullYear()} RTAS Gold Mind AI Professional. All rights reserved.
        </div>
      </div>
    </footer>
  );
}