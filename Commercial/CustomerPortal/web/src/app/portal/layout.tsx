import { auth } from "@/auth";
import type { Session } from "next-auth";
import Link from "next/link";
import { EnterpriseNav } from "@/components/enterprise/EnterpriseNav";
import { EnterpriseFooter } from "@/components/enterprise/EnterpriseFooter";
import { PortalNav } from "@/components/PortalNav";
import { PortalUserBar } from "@/components/PortalUserBar";
import { canAccessAdminConsole } from "@/server/admin/roles";
import { isDevAdminBypass } from "@/server/security/dev-bypass";
import { getParticipantByEmail } from "@/server/launch/beta-store";
import { getPartnerByEmail } from "@/server/partners/portal";
import { redirect } from "next/navigation";

export default async function PortalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  let session: Session | null = null;
  try {
    session = await auth();
  } catch {
    redirect("/login");
  }
  if (!session?.user) redirect("/login");
  const role = (session.user as { role?: string }).role;
  const showAdmin = canAccessAdminConsole(role) || isDevAdminBypass(session.user.email);

  let showBeta = false;
  let showPartner = false;
  try {
    showBeta = !!(session.user.email && getParticipantByEmail(session.user.email));
  } catch {
    showBeta = false;
  }
  try {
    showPartner = !!(session.user.email && getPartnerByEmail(session.user.email.toLowerCase()));
  } catch {
    showPartner = false;
  }

  return (
    <div className="e-site" style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
      {/* Same header as home page */}
      <EnterpriseNav />

      {/* Main layout: Sidebar + Content */}
      <div style={{ display: "flex", flex: 1, position: "relative" }}>
        {/* Portal sidebar */}
        <PortalNav showAdmin={!!showAdmin} showBeta={showBeta} showPartner={showPartner} />

        {/* Content area */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
          {/* User bar */}
          <div style={{ padding: 0, borderBottom: "none" }}>
            <PortalUserBar
              name={session.user.name}
              email={session.user.email}
              image={session.user.image}
              role={role}
            />
          </div>

          {/* Page content */}
          <main style={{ flex: 1, padding: "24px", overflow: "auto" }}>
            {children}
          </main>

          {/* Same footer as home page */}
          <EnterpriseFooter />
        </div>
      </div>

      <style>{`
        /* Responsive layout */
        @media (max-width: 1024px) {
          .portal-topbar {
            padding: 12px 16px !important;
          }
          main {
            padding: 16px !important;
          }
        }

        @media (max-width: 768px) {
          .portal-topbar {
            padding: 12px !important;
          }
          main {
            padding: 12px !important;
          }
        }
      `}</style>
    </div>
  );
}