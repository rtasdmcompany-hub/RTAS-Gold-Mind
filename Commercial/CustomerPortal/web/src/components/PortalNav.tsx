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
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  // Jab route change ho, drawer band karo
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  const items = [
    ...customerNav,
    ...(showBeta ? [betaNavItem] : []),
    ...(showPartner ? [partnerNavItem] : []),
    ...(showAdmin ? [{ href: "/portal/admin", label: "Admin Console" }] : []),
  ];

  // Mobile top bar — sirf mobile par dikhe
  const mobileTopBarStyle: React.CSSProperties = {
    display: isMobile ? "flex" : "none",
    position: "sticky",
    top: 0,
    zIndex: 100,
    background: "#0a0a0a",
    borderBottom: "1px solid #2a2a38",
    padding: "10px 14px",
    alignItems: "center",
    justifyContent: "space-between",
  };

  // Hamburger button
  const hamburgerStyle: React.CSSProperties = {
    background: "transparent",
    border: "1px solid #c9971f",
    color: "#f5c542",
    borderRadius: 6,
    width: 40,
    height: 40,
    cursor: "pointer",
    fontSize: 20,
    display: "grid",
    placeItems: "center",
  };

  // Sidebar — mobile par drawer, desktop par normal
  const sidebarStyle: React.CSSProperties = {
    position: isMobile ? "fixed" : undefined,
    top: 0,
    left: 0,
    bottom: 0,
    width: isMobile ? "85%" : undefined,
    maxWidth: isMobile ? 300 : undefined,
    background: "#0a0a0a",
    borderRight: isMobile ? "1px solid #c9971f" : undefined,
    zIndex: 200,
    padding: "16px",
    overflowY: "auto",
    transform: isMobile ? (mobileOpen ? "translateX(0)" : "translateX(-100%)") : undefined,
    transition: "transform 0.3s ease",
  };

  // Mobile overlay
  const overlayStyle: React.CSSProperties = {
    display: isMobile && mobileOpen ? "block" : "none",
    position: "fixed",
    inset: 0,
    background: "rgba(0,0,0,0.6)",
    zIndex: 150,
  };

  return (
    <>
      {/* Mobile top bar with hamburger */}
      <div style={mobileTopBarStyle}>
        <Link href="/" style={{ textDecoration: "none" }}>
          <BrandLogo variant="nav" href="/" priority />
        </Link>
        <button
          type="button"
          onClick={() => setMobileOpen(!mobileOpen)}
          aria-label="Toggle menu"
          style={hamburgerStyle}
        >
          {mobileOpen ? "✕" : "☰"}
        </button>
      </div>

      {/* Mobile overlay */}
      <div style={overlayStyle} onClick={() => setMobileOpen(false)} />

      {/* Sidebar */}
      <aside className="nav" aria-label="Customer Portal" style={sidebarStyle}>
        <div className="brand">
          <BrandLogo variant="nav" href="/" priority />
          <p className="brand-sub">Customer Portal · Professional</p>
          <Link href="/" className="nav-link portal-home-link">
            ← Website Home
          </Link>
        </div>

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
              style={isMobile ? { padding: "14px 8px", fontSize: 16, borderBottom: "1px solid #1a1a24" } : {}}
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
    </>
  );
}