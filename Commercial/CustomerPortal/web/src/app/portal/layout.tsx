import { auth } from "@/auth";
import type { Session } from "next-auth";
import { EnterpriseNav } from "@/components/enterprise/EnterpriseNav";
import { EnterpriseFooter } from "@/components/enterprise/EnterpriseFooter";
import { SiteContentProvider } from "@/components/enterprise/SiteContentProvider";
import { ensureSiteContentLoaded, getPublicSiteContent } from "@/server/site-content/store";
import { PortalNav } from "@/components/PortalNav";
import { PortalUserBar } from "@/components/PortalUserBar";
import { AiAssistantWidget } from "@/components/AiAssistantWidget";
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

  // ✅ Role ko lowercase karo — "SUPER_ADMIN" ab "super_admin" ban jayega
  const role = ((session.user as { role?: string }).role || "customer").toLowerCase();
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

  // ✅ Server se site content load karo (same as home page)
  await ensureSiteContentLoaded();
  const siteContent = getPublicSiteContent();

  return (
    <SiteContentProvider initial={siteContent}>
      <div className="e-site" style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
        <EnterpriseNav />

        <div style={{ display: "flex", flex: 1, position: "relative" }}>
          <PortalNav showAdmin={!!showAdmin} showBeta={showBeta} showPartner={showPartner} />

          <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
            <div style={{ padding: 0, borderBottom: "none" }}>
              <PortalUserBar
                name={session.user.name}
                email={session.user.email}
                image={session.user.image}
                role={role}
              />
            </div>

            <main style={{ flex: 1, padding: "24px", overflow: "auto" }}>
              {children}
            </main>

            <EnterpriseFooter />
          </div>
        </div>

        <AiAssistantWidget
          surface="customer_portal"
          role={showAdmin ? "admin" : "customer"}
          customerEmail={session.user.email || undefined}
          title="May I help you?"
        />
      </div>
    </SiteContentProvider>
  );
}