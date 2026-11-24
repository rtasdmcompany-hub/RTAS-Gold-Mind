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
  const [open, setOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  // Jab route change ho, menu band karo
  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  const items = [
    ...customerNav,
    ...(showBeta ? [betaNavItem] : []),
    ...(showPartner ? [partnerNavItem] : []),
    ...(showAdmin ? [{ href: "/portal/admin", label: "Admin Console" }] : []),
  ];

  return (
    <>
      {/* Mobile top bar */}
      {isMobile && (
        <div
          style={{
            position: "sticky",
            top: 0,
            zIndex: 100,
            background: "#0a0a0a",
            borderBottom: "1px solid #2a2a38",
            padding: "10px 14px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <Link href="/" style={{ textDecoration: "none" }}>
            <BrandLogo variant="nav" href="/" priority />
          </Link>
          <button
            type="button"
            onClick={() => setOpen(!open)}
            aria-label="Toggle menu"
            style={{
              background: "transparent",
              border: "1px solid #c9971f",
              color: "#f5c542",
              borderRadius: 6,
              width: 40,
              height: 40,
              cursor: "pointer",
              fontSize: 18,
              display: "grid",
              placeItems: "center",
            }}
          >
            {open ? "✕" : "☰"}
          </button>
        </div>
      )}

      {/* Sidebar (desktop) / Drawer (mobile) */}
      <aside
        className="nav"
        aria-label="Customer Portal"
        style={
          isMobile
            ? {
                position: "fixed",
                top: 0,
                left: 0,
                bottom: 0,
                width: "80%",
                maxWidth: 300,
                background: "#0a0a0a",
                borderRight: "1px solid #c9971f",
                zIndex: 200,
                padding: "16px",
                overflowY: "auto",
                transform: open ? "translateX(0)" : "translateX(-100%)",
                transition: "transform 0.3s ease",
              }
            : {}
        }
      >
        {!isMobile && (
          <div className="brand">
            <BrandLogo variant="nav" href="/" priority />
            <p className="brand-sub">Customer Portal · Professional</p>
            <Link href="/" className="nav-link portal-home-link">
              ← Website Home
            </Link>
          </div>
        )}

        {isMobile && (
          <div style={{ marginBottom: 16, paddingBottom: 12, borderBottom: "1px solid #2a2a38" }}>
            <BrandLogo variant="nav" href="/" priority />
            <p style={{ color: "#777", fontSize: 11, margin: "4px 0 0" }}>Customer Portal</p>
          </div>
        )}

        {items.map((item) => {
          const active =
            item.href === "/portal"
              ? pathname === "/portal"
              : pathname === item.href || pathname.startsWith(item.href + "/");
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`nav-link${active ? " active" : ""}`}
              style={isMobile ? { padding: "12px 8px", fontSize: 15 } : {}}
            >
              {item.label}
            </Link>
          );
        })}

        <div style={{ marginTop: "auto", paddingTop: 16 }}>
          <Link href="/" className="nav-link">
            Official Website
          </Link>
        </div>
      </aside>

      {/* Mobile overlay */}
      {isMobile && open && (
        <div
          onClick={() => setOpen(false)}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0,0,0,0.6)",
            zIndex: 150,
          }}
        />
      )}
    </>
  );
}