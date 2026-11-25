import Link from "next/link";
import Image from "next/image";

const BRANDS = [
  { src: "/brand/footer-gold-mind.png", name: "RTAS Gold Mind", alt: "RTAS Gold Mind" },
  { src: "/brand/footer-rtas-digital.png", name: "RTAS Digital Marketing", alt: "RTAS Digital Marketing Company" },
  { src: "/brand/footer-rtas-group.png", name: "RTAS Group", alt: "RTAS Group" },
];

export function EnterpriseFooter() {
  return (
    <footer
      style={{
        background: "#0a0a0a",
        borderTop: "1px solid #2a2a38",
        padding: "24px 24px 16px",
      }}
    >
      <div
        style={{
          maxWidth: 1200,
          margin: "0 auto",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 18,
        }}
      >
        {/* Brand logos with names */}
        <div
          style={{
            display: "flex",
            flexWrap: "wrap",
            justifyContent: "center",
            alignItems: "center",
            gap: 28,
          }}
        >
          {BRANDS.map((b, i) => (
            <div key={b.name} style={{ display: "flex", alignItems: "center", gap: 28 }}>
              <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                <Image
                  src={b.src}
                  alt={b.alt}
                  width={64}
                  height={40}
                  style={{ objectFit: "contain" }}
                  unoptimized
                />
                <span
                  style={{
                    color: "#9a95a8",
                    fontSize: 11,
                    fontWeight: 600,
                    letterSpacing: 0.4,
                    whiteSpace: "nowrap",
                  }}
                >
                  {b.name}
                </span>
              </div>
              {i < BRANDS.length - 1 && (
                <span style={{ color: "#333", fontSize: 16, marginBottom: 18 }}>·</span>
              )}
            </div>
          ))}
        </div>

        {/* Links */}
        <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: 18 }}>
          <Link href="/privacy" style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}>
            Privacy
          </Link>
          <Link href="/terms" style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}>
            Terms
          </Link>
          <Link href="/contact" style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}>
            Contact
          </Link>
          <Link href="/refund" style={{ color: "#9a95a8", textDecoration: "none", fontSize: 13 }}>
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
            paddingTop: 12,
            width: "100%",
          }}
        >
          © {new Date().getFullYear()} RTAS Gold Mind AI Professional. All rights reserved.
        </div>
      </div>
    </footer>
  );
}