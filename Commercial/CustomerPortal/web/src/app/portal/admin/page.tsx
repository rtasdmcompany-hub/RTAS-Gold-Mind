import Link from "next/link";

const SECTIONS = [
  { href: "/portal/admin/customers", label: "Customers", desc: "Accounts, status, search" },
  { href: "/portal/admin/licenses", label: "Licenses", desc: "Issue, revoke, validate keys" },
  { href: "/portal/admin/billing", label: "Billing", desc: "Invoices, payments, refunds" },
  { href: "/portal/admin/support", label: "Support", desc: "Tickets and replies" },
  { href: "/portal/admin/releases", label: "Releases", desc: "Versions and installers" },
  { href: "/portal/admin/market", label: "MQL5 Market", desc: "Market listing & compliance" },
  { href: "/portal/admin/site-content", label: "Site Content", desc: "Website copy, media, videos" },
  { href: "/portal/admin/audit", label: "Audit", desc: "Admin action log" },
  { href: "/portal/admin/security", label: "Security", desc: "Sessions and threats" },
  { href: "/portal/admin/roles", label: "Roles", desc: "Staff roles & permissions" },
];

export default function AdminHub() {
  return (
    <>
      <style>{`
        .admin-grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 16px;
        }
        .admin-card {
          text-decoration: none;
          display: block;
          transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .admin-card:hover {
          transform: translateY(-4px);
          box-shadow: 0 8px 24px rgba(245, 197, 66, 0.18);
        }
        @media (max-width: 900px) {
          .admin-grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 600px) {
          .admin-grid { grid-template-columns: 1fr; }
        }
      `}</style>

      <header style={{ marginBottom: 24 }}>
        <h1 className="page-title">Operations Hub</h1>
        <p className="page-sub">
          Everything you need to run the business — nothing you don&apos;t.
        </p>
      </header>

      <div className="admin-grid">
        {SECTIONS.map((s) => (
          <Link key={s.href} href={s.href} className="card admin-card">
            <h3 style={{ color: "#f5c542", marginBottom: 8 }}>{s.label}</h3>
            <div className="meta" style={{ color: "#9a95a8", fontSize: 13 }}>{s.desc}</div>
          </Link>
        ))}
      </div>
    </>
  );
}