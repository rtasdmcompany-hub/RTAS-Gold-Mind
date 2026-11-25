"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, useEffect } from "react";
import { BrandLogo } from "@/components/BrandLogo";

const NAV_LINKS = [
  { href: "/", label: "Home" },
  { href: "/about", label: "About" },
  { href: "/pricing", label: "Pricing" },
  { href: "/docs", label: "Docs" },
  { href: "/download", label: "Download" },
  { href: "/contact", label: "Contact" },
];

export function SiteNav() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  // Jab route change ho, menu band karo
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  // Body scroll lock jab menu open ho
  useEffect(() => {
    if (mobileOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [mobileOpen]);

  return (
    <>
      {/* Desktop Navigation */}
      <nav
        style={{
          display: isMobile ? "none" : "flex",
          alignItems: "center",
          gap: 8,
        }}
      >
        {NAV_LINKS.map((link) => {
          const isActive = pathname === link.href;
          return (
            <Link
              key={link.href}
              href={link.href}
              style={{
                padding: "8px 16px",
                borderRadius: 8,
                textDecoration: "none",
                color: isActive ? "#f5c542" : "#d4d4d8",
                background: isActive ? "rgba(245, 197, 66, 0.1)" : "transparent",
                border: isActive ? "1px solid rgba(245, 197, 66, 0.3)" : "1px solid transparent",
                fontSize: 14,
                fontWeight: 500,
                transition: "all 0.2s ease",
              }}
              onMouseEnter={(e) => {
                if (!isActive) {
                  e.currentTarget.style.background = "rgba(255, 255, 255, 0.05)";
                  e.currentTarget.style.color = "#f5c542";
                }
              }}
              onMouseLeave={(e) => {
                if (!isActive) {
                  e.currentTarget.style.background = "transparent";
                  e.currentTarget.style.color = "#d4d4d8";
                }
              }}
            >
              {link.label}
            </Link>
          );
        })}

        <Link
          href="/register"
          style={{
            padding: "8px 16px",
            borderRadius: 8,
            textDecoration: "none",
            color: "#0a0a0a",
            background: "linear-gradient(135deg, #f5c542, #c9971f)",
            fontSize: 14,
            fontWeight: 700,
            marginLeft: 8,
          }}
        >
          Register
        </Link>

        <Link
          href="/portal"
          style={{
            padding: "8px 16px",
            borderRadius: 8,
            textDecoration: "none",
            color: "#0a0a0a",
            background: "linear-gradient(135deg, #f5c542, #c9971f)",
            fontSize: 14,
            fontWeight: 700,
          }}
        >
          User Portal
        </Link>
      </nav>

      {/* Mobile Hamburger Button */}
      {isMobile && (
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          aria-label="Open menu"
          style={{
            background: "transparent",
            border: "1px solid #c9971f",
            color: "#f5c542",
            borderRadius: 8,
            width: 44,
            height: 44,
            cursor: "pointer",
            fontSize: 22,
            display: "grid",
            placeItems: "center",
          }}
        >
          ☰
        </button>
      )}

      {/* Mobile Menu Overlay */}
      {mobileOpen && isMobile && (
        <div
          onClick={() => setMobileOpen(false)}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0, 0, 0, 0.7)",
            zIndex: 9998,
            backdropFilter: "blur(4px)",
          }}
        />
      )}

      {/* Mobile Menu Drawer */}
      {isMobile && (
        <div
          style={{
            position: "fixed",
            top: 0,
            right: 0,
            bottom: 0,
            width: "85%",
            maxWidth: 320,
            background: "#0a0a0a",
            borderLeft: "1px solid #c9971f",
            zIndex: 9999,
            padding: "20px",
            overflowY: "auto",
            transform: mobileOpen ? "translateX(0)" : "translateX(100%)",
            transition: "transform 0.3s ease",
          }}
        >
          {/* Header with close button */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              marginBottom: 24,
              paddingBottom: 16,
              borderBottom: "1px solid #2a2a38",
            }}
          >
            <BrandLogo variant="nav" href="/" priority />
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              aria-label="Close menu"
              style={{
                background: "transparent",
                border: "1px solid #333",
                color: "#ccc",
                borderRadius: 6,
                width: 36,
                height: 36,
                cursor: "pointer",
                fontSize: 18,
                display: "grid",
                placeItems: "center",
              }}
            >
              ✕
            </button>
          </div>

          {/* Navigation Links */}
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            {NAV_LINKS.map((link) => {
              const isActive = pathname === link.href;
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  style={{
                    padding: "14px 16px",
                    borderRadius: 8,
                    textDecoration: "none",
                    color: isActive ? "#f5c542" : "#d4d4d8",
                    background: isActive ? "rgba(245, 197, 66, 0.1)" : "transparent",
                    border: isActive ? "1px solid rgba(245, 197, 66, 0.3)" : "1px solid transparent",
                    fontSize: 16,
                    fontWeight: 500,
                    transition: "all 0.2s ease",
                  }}
                >
                  {link.label}
                </Link>
              );
            })}
          </div>

          {/* Divider */}
          <div style={{ margin: "20px 0", borderBottom: "1px solid #2a2a38" }} />

          {/* Action Buttons */}
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            <Link
              href="/register"
              style={{
                padding: "14px 16px",
                borderRadius: 8,
                textDecoration: "none",
                color: "#0a0a0a",
                background: "linear-gradient(135deg, #f5c542, #c9971f)",
                fontSize: 16,
                fontWeight: 700,
                textAlign: "center",
              }}
            >
              Register
            </Link>

            <Link
              href="/portal"
              style={{
                padding: "14px 16px",
                borderRadius: 8,
                textDecoration: "none",
                color: "#f5c542",
                background: "transparent",
                border: "1px solid #c9971f",
                fontSize: 16,
                fontWeight: 700,
                textAlign: "center",
              }}
            >
              User Portal
            </Link>
          </div>

          {/* Footer */}
          <div
            style={{
              marginTop: 32,
              paddingTop: 16,
              borderTop: "1px solid #2a2a38",
              textAlign: "center",
              color: "#777",
              fontSize: 12,
            }}
          >
            RTAS Gold Mind AI Professional
          </div>
        </div>
      )}
    </>
  );
}