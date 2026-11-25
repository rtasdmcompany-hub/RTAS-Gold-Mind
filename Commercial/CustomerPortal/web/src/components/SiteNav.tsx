"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, useEffect } from "react";

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
    const check = () => {
      const mobile = window.innerWidth < 768;
      setIsMobile(mobile);
      if (!mobile) setMobileOpen(false);
    };
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  return (
    <>
      {/* Desktop Navigation */}
      {!isMobile && (
        <nav style={{ display: "flex", alignItems: "center", gap: 8 }}>
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
      )}

      {/* Mobile Hamburger Button */}
      {isMobile && !mobileOpen && (
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          aria-label="Open menu"
          style={{
            background: "#0a0a0a",
            border: "2px solid #f5c542",
            color: "#f5c542",
            borderRadius: 8,
            width: 48,
            height: 48,
            cursor: "pointer",
            fontSize: 24,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0 4px 12px rgba(245, 197, 66, 0.3)",
          }}
        >
          ☰
        </button>
      )}

      {/* Mobile Menu - Full Screen Overlay */}
      {isMobile && mobileOpen && (
        <>
          {/* Dark Overlay */}
          <div
            onClick={() => setMobileOpen(false)}
            style={{
              position: "fixed",
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background: "rgba(0, 0, 0, 0.85)",
              zIndex: 9998,
            }}
          />

          {/* Menu Drawer */}
          <div
            style={{
              position: "fixed",
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background: "#0a0a0a",
              zIndex: 9999,
              padding: "24px",
              overflowY: "auto",
              animation: "slideIn 0.3s ease",
            }}
          >
            {/* Header */}
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                marginBottom: 32,
                paddingBottom: 16,
                borderBottom: "2px solid #f5c542",
              }}
            >
              <div style={{ color: "#f5c542", fontSize: 18, fontWeight: 700 }}>
                RTAS Gold Mind
              </div>
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                aria-label="Close menu"
                style={{
                  background: "#f5c542",
                  border: "none",
                  color: "#0a0a0a",
                  borderRadius: 8,
                  width: 40,
                  height: 40,
                  cursor: "pointer",
                  fontSize: 20,
                  fontWeight: 700,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                ✕
              </button>
            </div>

            {/* Navigation Links */}
            <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              {NAV_LINKS.map((link) => {
                const isActive = pathname === link.href;
                return (
                  <Link
                    key={link.href}
                    href={link.href}
                    style={{
                      padding: "16px 20px",
                      borderRadius: 8,
                      textDecoration: "none",
                      color: isActive ? "#0a0a0a" : "#d4d4d8",
                      background: isActive ? "#f5c542" : "transparent",
                      border: isActive ? "2px solid #f5c542" : "2px solid #2a2a38",
                      fontSize: 18,
                      fontWeight: isActive ? 700 : 500,
                      transition: "all 0.2s ease",
                    }}
                  >
                    {link.label}
                  </Link>
                );
              })}
            </div>

            {/* Divider */}
            <div style={{ margin: "24px 0", borderBottom: "1px solid #2a2a38" }} />

            {/* Action Buttons */}
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <Link
                href="/register"
                style={{
                  padding: "16px",
                  borderRadius: 8,
                  textDecoration: "none",
                  color: "#0a0a0a",
                  background: "linear-gradient(135deg, #f5c542, #c9971f)",
                  fontSize: 18,
                  fontWeight: 700,
                  textAlign: "center",
                  border: "2px solid #f5c542",
                }}
              >
                Register
              </Link>

              <Link
                href="/portal"
                style={{
                  padding: "16px",
                  borderRadius: 8,
                  textDecoration: "none",
                  color: "#f5c542",
                  background: "transparent",
                  fontSize: 18,
                  fontWeight: 700,
                  textAlign: "center",
                  border: "2px solid #f5c542",
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
              RTAS Gold Mind Automatic Trading Software         </div>
          </div>

          <style>{`
            @keyframes slideIn {
              from {
                opacity: 0;
                transform: scale(0.95);
              }
              to {
                opacity: 1;
                transform: scale(1);
              }
            }
          `}</style>
        </>
      )}
    </>
  );
}