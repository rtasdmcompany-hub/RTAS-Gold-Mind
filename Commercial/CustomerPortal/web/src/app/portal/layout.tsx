import { auth } from "@/auth";
import type { Session } from "next-auth";
import { EnterpriseNav } from "@/components/enterprise/EnterpriseNav";
import { EnterpriseFooter } from "@/components/enterprise/EnterpriseFooter";
import { SiteContentProvider } from "@/components/enterprise/SiteContentProvider";
import { ensureSiteContentLoaded, getPublicSiteContent } from "@/server/site-content/store";
import { PortalNav } from "@/components/PortalNav";
import { PortalUserBar } from "@/components/PortalUserBar";
import { canAccessAdminConsole } from "@/server/admin/roles";
import { isDevAdminBypass } from "@/server/security/dev-bypass";
import { getParticipantByEmail } from "@/server/launch/beta-store";
import { getPartnerByEmail } from "@/server/partners/portal";
import { redirect } from "next/navigation";

const ADMIN_ROLES = [
  "super_admin", "admin", "owner", "administrator",
  "commercial_manager", "support_agent", "support",
  "finance_manager", "qa_manager", "auditor",
];

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

  const role = ((session.user as { role?: string }).role || "customer").toLowerCase();
  const showAdmin =
    ADMIN_ROLES.includes(role) ||
    canAccessAdminConsole(role) ||
    isDevAdminBypass(session.user.email);

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

  await ensureSiteContentLoaded();
  const siteContent = getPublicSiteContent();

  return (
    <SiteContentProvider initial={siteContent}>
      <div className="e-site" style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
        <EnterpriseNav />

        <div style={{ display: "flex", flex: 1, position: "relative" }}>
          <PortalNav showAdmin={!!showAdmin} showBeta={showBeta} showPartner={showPartner} />

          <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
            <PortalUserBar
              name={session.user.name}
              email={session.user.email}
              image={session.user.image}
              role={role}
            />

            <main style={{ flex: 1, padding: "24px", overflow: "auto" }}>
              {children}
            </main>

            <EnterpriseFooter />
          </div>
        </div>
      </div>
    </SiteContentProvider>
  );
}