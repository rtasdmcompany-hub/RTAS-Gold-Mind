"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { BrandLogo } from "@/components/BrandLogo";
import { useSiteContent } from "./SiteContentProvider";

const LINKS = [
  { href: "/", label: "Home" },
  { href: "/about", label: "About" },
  { href: "/pricing", label: "Pricing" },
  { href: "/docs", label: "Docs" },
  { href: "/portal/downloads", label: "Download" },
  { href: "/contact", label: "Contact" },
  { href: "/register", label: "Register" },
];

export function EnterpriseNav({ transparent = false }: { transparent?: boolean }) {
  const pathname = usePathname();
  const site = useSiteContent();
  const [scrolled, setScrolled] = useState(false);
  const [shrunk, setShrunk] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      const y = window.scrollY;
      setScrolled(y > 32);
      setShrunk(y > 120);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    const check = () => {
      const mobile = window.innerWidth < 768;
      setIsMobile(mobile);
      if (!mobile) setMenuOpen(false);
    };
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  // Jab route change ho, menu band karo
  useEffect(() => {
    setMenuOpen(false);
  }, [pathname]);

  // Body scroll lock jab menu open ho
  useEffect(() => {
    if (menuOpen && isMobile) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [menuOpen, isMobile]);

  const solid = scrolled || !transparent;

  return (
    <>
      <header
        className={`e-nav ${solid ? "e-nav--solid" : "e-nav--transparent"} ${shrunk ? "e-nav--shrunk" : ""}`}
        style={
          isMobile
            ? {
                position: "sticky",
                top: 0,
                zIndex: 100,
                background: "#0a0a0a",
                borderBottom: "1px solid #2a2a38",
              }
            : {}
        }
      >
        <div className="e-nav-inner">
          <Link href="/" className="e-brand-lockup" onClick={() => setMenuOpen(false)}>
            <BrandLogo
              variant="header"
              priority
              className="e-brand-logo e-brand-logo--header"
              src={site.logos.header}
            />
            <span className="e-brand-wordmark">
              <span className="e-brand-wordmark-title">{site.header.brandName}</span>
              <span className="e-brand-wordmark-sub">{site.header.brandSub}</span>
            </span>
          </Link>

          {/* Desktop nav — sirf desktop par dikhe */}
          {!isMobile && (
            <nav>
              <ul className="e-nav-links">
                {LINKS.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className={
                        l.href === "/portal/downloads"
                          ? `e-nav-download${pathname.startsWith("/portal/downloads") ? " e-active" : ""}`
                          : pathname === l.href
                            ? "e-active"
                            : ""
                      }
                    >
                      {l.label}
                    </Link>
                  </li>
                ))}
                <li>
                  <Link
                    href={site.header.ctaHref || "/login"}
                    className="e-nav-cta"
                  >
                    {site.header.ctaLabel || "User Portal"}
                  </Link>
                </li>
              </ul>
            </nav>
          )}

          {/* Mobile hamburger button */}
          {isMobile && (
            <button
              type="button"
              aria-label="Toggle menu"
              aria-expanded={menuOpen}
              onClick={() => setMenuOpen((o) => !o)}
              style={{
                background: "transparent",
                border: "2px solid #f5c542",
                borderRadius: 8,
                width: 44,
                height: 44,
                cursor: "pointer",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: 4,
                padding: 8,
                marginLeft: "auto",
              }}
            >
              <span
                style={{
                  display: "block",
                  width: 22,
                  height: 2,
                  background: "#f5c542",
                  borderRadius: 2,
                  transition: "all 0.3s ease",
                  transform: menuOpen ? "rotate(45deg) translate(4px, 4px)" : "none",
                }}
              />
              <span
                style={{
                  display: "block",
                  width: 22,
                  height: 2,
                  background: "#f5c542",
                  borderRadius: 2,
                  transition: "all 0.3s ease",
                  opacity: menuOpen ? 0 : 1,
                }}
              />
              <span
                style={{
                  display: "block",
                  width: 22,
                  height: 2,
                  background: "#f5c542",
                  borderRadius: 2,
                  transition: "all 0.3s ease",
                  transform: menuOpen ? "rotate(-45deg) translate(4px, -4px)" : "none",
                }}
              />
            </button>
          )}
        </div>
      </header>

      {/* Mobile Menu Overlay + Drawer */}
      {isMobile && menuOpen && (
        <>
          {/* Dark overlay */}
          <div
            onClick={() => setMenuOpen(false)}
            style={{
              position: "fixed",
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background: "rgba(0, 0, 0, 0.7)",
              zIndex: 998,
              backdropFilter: "blur(4px)",
            }}
          />

          {/* Menu drawer */}
          <div
            style={{
              position: "fixed",
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background: "#0a0a0a",
              zIndex: 999,
              padding: "24px",
              overflowY: "auto",
              animation: "slideInMenu 0.3s ease",
            }}
          >
            {/* Header with close button */}
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
                {site.header.brandName}
              </div>
              <button
                type="button"
                onClick={() => setMenuOpen(false)}
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
              {LINKS.map((l) => {
                const isActive = pathname === l.href;
                return (
                  <Link
                    key={l.href}
                    href={l.href}
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
                    {l.label}
                  </Link>
                );
              })}
            </div>

            {/* Divider */}
            <div style={{ margin: "24px 0", borderBottom: "1px solid #2a2a38" }} />

            {/* User Portal Button */}
            <Link
              href={site.header.ctaHref || "/login"}
              style={{
                display: "block",
                padding: "16px",
                borderRadius: 8,
                textDecoration: "none",
                color: "#f5c542",
                background: "transparent",
                fontSize: 18,
                fontWeight: 700,
                textAlign: "center",
                border: "2px solid #f5c542",
                marginBottom: 12,
              }}
            >
              {site.header.ctaLabel || "User Portal"}
            </Link>

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
              {site.header.brandName} · {site.header.brandSub}
            </div>
          </div>

          <style>{`
            @keyframes slideInMenu {
              from {
                opacity: 0;
                transform: translateY(-20px);
              }
              to {
                opacity: 1;
                transform: translateY(0);
              }
            }
          `}</style>
        </>
      )}
    </>
  );
}