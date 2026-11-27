import Link from "next/link";

type Section = {
  href: string;
  icon: string;
  label: string;
  desc: string;
  action: string;
};

const GROUPS: { title: string; hint: string; items: Section[] }[] = [
  {
    title: "💼 Commercial Operations",
    hint: "Customers aur paisay se jude kaam",
    items: [
      { href: "/portal/admin/customers", icon: "👥", label: "Customers", desc: "Saare registered users — search, status, role change", action: "Manage customers" },
      { href: "/portal/admin/licenses", icon: "🔑", label: "Licenses", desc: "License keys banana, revoke karna, validate karna", action: "Manage licenses" },
      { href: "/portal/admin/billing", icon: "💳", label: "Billing", desc: "Invoices, payments aur refunds ka poora record", action: "Manage billing" },
    ],
  },
  {
    title: "📦 Product & Distribution",
    hint: "Software release aur market listing",
    items: [
      { href: "/portal/admin/support", icon: "🎫", label: "Support Tickets", desc: "Customer tickets parhna aur reply karna", action: "Open tickets" },
      { href: "/portal/admin/releases", icon: "📦", label: "Releases", desc: "New versions publish karna, installers manage karna", action: "Manage releases" },
      { href: "/portal/admin/market", icon: "🛒", label: "MQL5 Market", desc: "MQL5 market listing aur compliance status", action: "Market settings" },
    ],
  },
  {
    title: "🖥️ Platform & Governance",
    hint: "Website content aur security control",
    items: [
      { href: "/portal/admin/site-content", icon: "🖥️", label: "Site Content", desc: "Website videos, logos, header/footer text edit karna", action: "Edit website" },
      { href: "/portal/admin/audit", icon: "📋", label: "Audit Log", desc: "Kis admin ne kab kya kaam kiya — poora record", action: "View audit log" },
      { href: "/portal/admin/security", icon: "🛡️", label: "Security", desc: "Sessions, threats aur security settings", action: "Security center" },
      { href: "/portal/admin/roles", icon: "👤", label: "Staff Roles", desc: "Team members ke roles aur permissions set karna", action: "Manage roles" },
    ],
  },
];

export default function AdminHub() {
  return (
    <>
      <style>{`
        .hub-head { margin-bottom: 28px; }
        .hub-title { font-size: clamp(1.6rem, 3vw, 2.2rem); color: #f4f1e8; margin: 0 0 6px; }
        .hub-sub { color: #9a95a8; font-size: 14px; margin: 0; }
        .hub-group { margin-bottom: 32px; }
        .hub-group-head {
          display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap;
          margin-bottom: 14px; padding-bottom: 10px; border-bottom: 1px solid #2a2a38;
        }
        .hub-group-title { color: #f5c542; font-size: 15px; font-weight: 800; letter-spacing: .03em; }
        .hub-group-hint { color: #777; font-size: 12px; }
        .hub-grid {
          display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
          gap: 16px;
        }
        .hub-card {
          display: flex; flex-direction: column; gap: 10px;
          background: #14141d; border: 1px solid #2a2a38; border-radius: 14px;
          padding: 20px; text-decoration: none; transition: all .2s ease;
        }
        .hub-card:hover {
          border-color: #f5c542; transform: translateY(-3px);
          box-shadow: 0 10px 28px rgba(245,197,66,.12);
        }
        .hub-card-top { display: flex; align-items: center; gap: 12px; }
        .hub-icon {
          width: 42px; height: 42px; border-radius: 10px;
          display: grid; place-items: center; font-size: 20px;
          background: rgba(245,197,66,.1); border: 1px solid rgba(245,197,66,.3);
        }
        .hub-label { color: #f4f1e8; font-size: 16px; font-weight: 700; }
        .hub-desc { color: #9a95a8; font-size: 13px; line-height: 1.55; }
        .hub-action {
          margin-top: auto; color: #f5c542; font-size: 12px; font-weight: 700;
          letter-spacing: .05em; display: flex; align-items: center; gap: 6px;
        }
        .hub-arrow { transition: transform .2s ease; }
        .hub-card:hover .hub-arrow { transform: translateX(4px); }
      `}</style>

      <header className="hub-head">
        <h1 className="hub-title">Operations Hub</h1>
        <p className="hub-sub">
          Choose a section below — har button ka kaam saaf likha hua hai.
        </p>
      </header>

      {GROUPS.map((g) => (
        <section key={g.title} className="hub-group">
          <div className="hub-group-head">
            <span className="hub-group-title">{g.title}</span>
            <span className="hub-group-hint">{g.hint}</span>
          </div>
          <div className="hub-grid">
            {g.items.map((s) => (
              <Link key={s.href} href={s.href} className="hub-card">
                <div className="hub-card-top">
                  <span className="hub-icon">{s.icon}</span>
                  <span className="hub-label">{s.label}</span>
                </div>
                <p className="hub-desc">{s.desc}</p>
                <span className="hub-action">
                  {s.action} <span className="hub-arrow">→</span>
                </span>
              </Link>
            ))}
          </div>
        </section>
      ))}
    </>
  );
}