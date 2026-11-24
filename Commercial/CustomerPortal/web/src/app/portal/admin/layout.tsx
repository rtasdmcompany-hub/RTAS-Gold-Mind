import { auth } from "@/auth";
import { redirect } from "next/navigation";
import Link from "next/link";
import {
  canAccessAdminConsole,
  hasPermission,
  ROLE_LABELS,
  type AdminPermission,
} from "@/server/admin/roles";
import { getAdminIdleTimeoutMinutes } from "@/server/admin/security";
import { isDevAdminBypass } from "@/server/security/dev-bypass";
import { AdminIdleGuard } from "@/components/AdminIdleGuard";

const ADMIN_LINKS: { href: string; label: string; permission: AdminPermission }[] = [
  { href: "/portal/admin", label: "Overview", permission: "admin.dashboard" },
  { href: "/portal/admin/customers", label: "Customers", permission: "admin.customers.read" },
  { href: "/portal/admin/licenses", label: "Licenses", permission: "admin.licenses.read" },
  { href: "/portal/admin/billing", label: "Billing", permission: "admin.billing.read" },
  { href: "/portal/admin/support", label: "Support", permission: "admin.support.read" },
  { href: "/portal/admin/releases", label: "Releases", permission: "admin.releases.read" },
  { href: "/portal/admin/market", label: "MQL5 Market", permission: "admin.releases.read" },
  { href: "/portal/admin/site-content", label: "Site Content", permission: "admin.launch.read" },
  { href: "/portal/admin/audit", label: "Audit", permission: "admin.audit.read" },
  { href: "/portal/admin/security", label: "Security", permission: "admin.security.manage" },
  { href: "/portal/admin/roles", label: "Roles", permission: "admin.roles.manage" },
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const session = await auth();
  const email = session?.user?.email?.toLowerCase() || "";
  const role = (session?.user as { role?: string } | undefined)?.role || "customer";
  if (!canAccessAdminConsole(role) && !isDevAdminBypass(email)) {
    redirect("/portal");
  }

  const links = ADMIN_LINKS.filter(
    (l) => isDevAdminBypass(email) || hasPermission(role, l.permission)
  );
  const idleMin = getAdminIdleTimeoutMinutes();

  return (
    <div>
      <AdminIdleGuard timeoutMinutes={idleMin} />
      <div
        className="card"
        style={{ marginBottom: 16, display: "flex", flexWrap: "wrap", gap: 8, alignItems: "center" }}
      >
        <strong style={{ marginRight: 8 }}>Admin Console</strong>
        <span className="meta">
          {ROLE_LABELS[role] || role} · {email} · idle {idleMin}m
        </span>
        <span className="meta" style={{ marginLeft: "auto" }}>
          Commercial services only — Trading Engine isolated
        </span>
      </div>
      <nav aria-label="Admin sections" style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 20 }}>
        {links.map((l) => (
          <Link key={l.href} href={l.href} className="btn">
            {l.label}
          </Link>
        ))}
      </nav>
      {children}
    </div>
  );
}