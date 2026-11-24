"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
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

  const items = [
    ...customerNav,
    ...(showBeta ? [betaNavItem] : []),
    ...(showPartner ? [partnerNavItem] : []),
    ...(showAdmin ? [{ href: "/portal/admin", label: "Admin Console" }] : []),
  ];

  return (
    <>
      {/* Mobile top bar with hamburger */}
      <div className="portal-mobile-topbar">
        <Link href="/" style={{ textDecoration: "none" }}>
          <BrandLogo variant="nav" href="/" priority />
        </Link>
        <button
          type="button"
          onClick={() => setMobileOpen(!mobileOpen)}
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
          {mobileOpen ? "✕" : "☰"}
        </button>
      </div>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="portal-mobile-overlay"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`nav${mobileOpen ? " mobile-open" : ""}`}
        aria-label="Customer Portal"
      >
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
              onClick={() => setMobileOpen(false)}
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