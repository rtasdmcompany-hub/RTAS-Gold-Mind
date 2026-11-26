import Link from "next/link";
import Image from "next/image";
import { Fragment } from "react";

const BRANDS = [
  { src: "/brand/footer-gold-mind.png", name: "RTAS Gold Mind", alt: "RTAS Gold Mind" },
  { src: "/brand/footer-rtas-digital.png", name: "RTAS Digital Marketing", alt: "RTAS Digital Marketing Company" },
  { src: "/brand/footer-rtas-group.png", name: "RTAS Group", alt: "RTAS Group" },
];

export function EnterpriseFooter() {
  return (
    <footer className="e-footer">
      <style>{`
        .e-footer { background:#0a0a0a; border-top:1px solid #2a2a38; padding:22px 16px 14px; }
        .e-footer-row {
          display:flex; flex-wrap:wrap; justify-content:center; align-items:center;
          gap:22px; max-width:1200px; margin:0 auto;
        }
        .e-brand { display:flex; flex-direction:column; align-items:center; gap:6px; }
        .e-brand img { width:64px; height:40px; object-fit:contain; }
        .e-brand span { color:#9a95a8; font-size:11px; white-space:nowrap; }
        .e-sep { color:#333; font-size:14px; }
        .e-links { display:flex; flex-wrap:wrap; justify-content:center; gap:16px; margin-top:16px; }
        .e-links a { color:#9a95a8; text-decoration:none; font-size:13px; }
        .e-links a:hover { color:#f5c542; }
        .e-copy {
          color:#555; font-size:11px; text-align:center;
          margin-top:14px; padding-top:12px; border-top:1px solid #1a1a24;
        }
        @media (max-width:640px) {
          .e-footer { padding:16px 10px 10px; }
          .e-footer-row { gap:14px; }
          .e-brand img { width:44px; height:28px; }
          .e-brand span { font-size:9px; }
          .e-sep { display:none; }
          .e-links { gap:12px; }
          .e-links a { font-size:12px; }
        }
      `}</style>

      <div className="e-footer-row">
        {BRANDS.map((b, i) => (
          <Fragment key={b.name}>
            <div className="e-brand">
              <Image src={b.src} alt={b.alt} width={64} height={40} style={{ objectFit: "contain" }} unoptimized />
              <span>{b.name}</span>
            </div>
            {i < BRANDS.length - 1 && <span className="e-sep">·</span>}
          </Fragment>
        ))}
      </div>

      <div className="e-links">
        <Link href="/privacy">Privacy</Link>
        <Link href="/terms">Terms</Link>
        <Link href="/contact">Contact</Link>
        <Link href="/refund">Refunds</Link>
      </div>

      <div className="e-copy">
        © {new Date().getFullYear()} RTAS Gold Mind AI Professional. All rights reserved.
      </div>
    </footer>
  );
}