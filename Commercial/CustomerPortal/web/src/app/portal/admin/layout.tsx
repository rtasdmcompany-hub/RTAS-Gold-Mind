import { auth } from "@/auth";
import { redirect } from "next/navigation";
import Link from "next/link";
import {
  canAccessAdminConsole,
  ROLE_LABELS,
} from "@/server/admin/roles";
import { getAdminIdleTimeoutMinutes } from "@/server/admin/security";
import { isDevAdminBypass } from "@/server/security/dev-bypass";
import { AdminIdleGuard } from "@/components/AdminIdleGuard";

const ADMIN_LINKS: { href: string; label: string; icon: string }[] = [
  { href: "/portal/admin", label: "Overview", icon: "📊" },
  { href: "/portal/admin/customers", label: "Customers", icon: "👥" },
  { href: "/portal/admin/licenses", label: "Licenses", icon: "🔑" },
  { href: "/portal/admin/billing", label: "Billing", icon: "💳" },
  { href: "/portal/admin/support", label: "Support", icon: "🎫" },
  { href: "/portal/admin/releases", label: "Releases", icon: "📦" },
  { href: "/portal/admin/market", label: "MQL5 Market", icon: "🛒" },
  { href: "/portal/admin/site-content", label: "Site Content", icon: "🖥️" },
  { href: "/portal/admin/audit", label: "Audit Log", icon: "📋" },
  { href: "/portal/admin/security", label: "Security", icon: "🛡️" },
  { href: "/portal/admin/roles", label: "Staff Roles", icon: "👤" },
];

const ADMIN_ROLES = [
  "super_admin", "admin", "owner", "administrator",
  "commercial_manager", "support_agent", "support",
  "finance_manager", "qa_manager", "auditor",
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const session = await auth();
  const email = session?.user?.email?.toLowerCase() || "";
  const role = ((session?.user as { role?: string } | undefined)?.role || "customer").toLowerCase();
  if (!canAccessAdminConsole(role) && !isDevAdminBypass(email)) {
    redirect("/portal");
  }

  const idleMin = getAdminIdleTimeoutMinutes();

  return (
    <div>
      <AdminIdleGuard timeoutMinutes={idleMin} />

      <style>{`
        .admin-topbar {
          display: flex; flex-wrap: wrap; align-items: center; gap: 12px;
          background: linear-gradient(180deg, #14141d, #0e0e15);
          border: 1px solid #2a2a38; border-radius: 12px;
          padding: 14px 18px; margin-bottom: 14px;
        }
        .admin-topbar-title { color: #f5c542; font-size: 15px; font-weight: 800; letter-spacing: .04em; }
        .admin-topbar-meta { color: #9a95a8; font-size: 12px; }
        .admin-topbar-badge {
          margin-left: auto; color: #7ee2a8; font-size: 11px;
          border: 1px solid rgba(126,226,168,.35); border-radius: 99; padding: 4px 12px;
        }
        .admin-tabs { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 24px; }
        .admin-tab {
          display: inline-flex; align-items: center; gap: 8px;
          padding: 9px 16px; border-radius: 99; text-decoration: none;
          color: #d4d4d8; background: #16161d; border: 1px solid #2a2a38;
          font-size: 13px; font-weight: 600; transition: all .18s ease;
        }
        .admin-tab:hover {
          border-color: #f5c542; color: #f5c542;
          background: rgba(245,197,66,.08); transform: translateY(-1px);
        }
        .admin-tab-icon { font-size: 15px; line-height: 1; }
      `}</style>

      {/* Professional identity bar */}
      <div className="admin-topbar">
        <span className="admin-topbar-title">⬡ ADMIN CONSOLE</span>
        <span className="admin-topbar-meta">
          {ROLE_LABELS[role] || role} · {email} · auto-lock {idleMin}m
        </span>
        <span className="admin-topbar-badge">● Commercial services only — Trading Engine isolated</span>
      </div>

      {/* Icon pill navigation */}
      <nav className="admin-tabs" aria-label="Admin sections">
        {ADMIN_LINKS.map((l) => (
          <Link key={l.href} href={l.href} className="admin-tab">
            <span className="admin-tab-icon">{l.icon}</span>
            {l.label}
          </Link>
        ))}
      </nav>

      {children}
    </div>
  );
}