"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, useEffect } from "react";
import { betaNavItem, customerNav, partnerNavItem } from "@/lib/nav";
import { BrandLogo } from "@/components/BrandLogo";

export function PortalNav({
  showAdmin = false,
  showBeta = false,
  showPartner = false,
}: {
  showAdmin?: boolean;
  showBeta?: boolean;
  showPartner?: boolean;
}) {
  const pathname = usePathname();
  const [mounted, setMounted] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    setMounted(true);
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  const items = [
    ...customerNav,
    ...(showBeta ? [betaNavItem] : []),
    ...(showPartner ? [partnerNavItem] : []),
    ...(showAdmin ? [{ href: "/portal/admin", label: "Admin Console" }] : []),
  ];

  // Desktop sidebar
  const desktopSidebarStyle: React.CSSProperties = {
    width: 260,
    minWidth: 260,
    background: "#0a0a0a",
    borderRight: "1px solid #2a2a38",
    padding: "24px 16px",
    overflowY: "auto",
    height: "100%",
  };

  // Mobile drawer
  const mobileDrawerStyle: React.CSSProperties = mounted && isMobile
    ? {
        position: "fixed",
        top: 0,
        left: 0,
        bottom: 0,
        width: "85%",
        maxWidth: 300,
        background: "#0a0a0a",
        borderRight: "1px solid #c9971f",
        zIndex: 200,
        padding: "16px",
        overflowY: "auto",
        transform: mobileOpen ? "translateX(0)" : "translateX(-100%)",
        transition: "transform 0.3s ease",
      }
    : { display: "none" };

  return (
    <>
      {/* Mobile hamburger button */}
      {mounted && isMobile && (
        <button
          type="button"
          onClick={() => setMobileOpen(!mobileOpen)}
          aria-label="Toggle menu"
          style={{
            position: "fixed",
            top: 80,
            left: 16,
            zIndex: 100,
            background: "#0a0a0a",
            border: "2px solid #f5c542",
            borderRadius: 8,
            width: 44,
            height: 44,
            cursor: "pointer",
            fontSize: 20,
            display: "grid",
            placeItems: "center",
            color: "#f5c542",
          }}
        >
          {mobileOpen ? "✕" : "☰"}
        </button>
      )}

      {/* Mobile overlay */}
      {mounted && isMobile && mobileOpen && (
        <div
          onClick={() => setMobileOpen(false)}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0,0,0,0.6)",
            zIndex: 150,
          }}
        />
      )}

      {/* Desktop sidebar */}
      {!(mounted && isMobile) && (
        <aside style={desktopSidebarStyle}>
          <div style={{ marginBottom: 24 }}>
            <BrandLogo variant="nav" href="/" priority />
            <p style={{ color: "#777", fontSize: 11, margin: "8px 0 0" }}>Customer Portal</p>
          </div>

          <nav style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            {items.map((item) => {
              const active =
                item.href === "/portal"
                  ? pathname === "/portal"
                  : pathname === item.href || pathname.startsWith(item.href + "/");
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  style={{
                    padding: "12px 16px",
                    borderRadius: 8,
                    textDecoration: "none",
                    color: active ? "#f5c542" : "#d4d4d8",
                    background: active ? "rgba(245, 197, 66, 0.1)" : "transparent",
                    border: active ? "1px solid rgba(245, 197, 66, 0.3)" : "1px solid transparent",
                    fontSize: 14,
                    fontWeight: 500,
                    transition: "all 0.2s ease",
                  }}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <div style={{ marginTop: "auto", paddingTop: 16, borderTop: "1px solid #2a2a38" }}>
            <Link
              href="/"
              style={{
                padding: "12px 16px",
                borderRadius: 8,
                textDecoration: "none",
                color: "#d4d4d8",
                fontSize: 14,
                display: "block",
              }}
            >
              ← Official Website
            </Link>
          </div>
        </aside>
      )}

      {/* Mobile drawer */}
      <aside style={mobileDrawerStyle}>
        <div style={{ marginBottom: 24 }}>
          <BrandLogo variant="nav" href="/" priority />
          <p style={{ color: "#777", fontSize: 11, margin: "8px 0 0" }}>Customer Portal</p>
        </div>

        <nav style={{ display: "flex", flexDirection: "column", gap: 4 }}>
          {items.map((item) => {
            const active =
              item.href === "/portal"
                ? pathname === "/portal"
                : pathname === item.href || pathname.startsWith(item.href + "/");
            return (
              <Link
                key={item.href}
                href={item.href}
                style={{
                  padding: "14px 16px",
                  borderRadius: 8,
                  textDecoration: "none",
                  color: active ? "#0a0a0a" : "#d4d4d8",
                  background: active ? "#f5c542" : "transparent",
                  border: active ? "2px solid #f5c542" : "2px solid #2a2a38",
                  fontSize: 16,
                  fontWeight: active ? 700 : 500,
                }}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div style={{ marginTop: 24, paddingTop: 16, borderTop: "1px solid #2a2a38" }}>
          <Link
            href="/"
            style={{
              padding: "14px 16px",
              borderRadius: 8,
              textDecoration: "none",
              color: "#d4d4d8",
              fontSize: 16,
              display: "block",
            }}
          >
            ← Official Website
          </Link>
        </div>
      </aside>
    </>
  );
}