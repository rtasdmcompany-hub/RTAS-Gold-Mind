import { auth } from "@/auth";
import { StatusBadge } from "@/components/StatusBadge";
import { AiCommandCenterPreview } from "@/components/AiCommandCenterPreview";
import { ensureSeedData } from "@/server/licensing/seed";
import { listLicensesForCustomer } from "@/server/licensing/license-service";
import { listDevicesForCustomer } from "@/server/licensing/device-service";
import { listSubscriptionsForCustomer } from "@/server/licensing/subscription-service";
import { graceDays } from "@/server/licensing/crypto";
import { ensureBillingStoreLoaded } from "@/server/billing/store";
import { getBillingSummary } from "@/server/billing/billing-service";
import { ensureSupportStoreLoaded } from "@/server/admin/support-store";
import { listSupportTickets } from "@/server/admin/support-store";
import Link from "next/link";
import { brand } from "@/lib/brand";
import { product } from "@/lib/product";

type DashboardSub = {
  status?: string;
  plan?: string;
  expirationDate?: string;
};

export default async function DashboardPage() {
  await ensureSeedData();
  await ensureBillingStoreLoaded();
  await ensureSupportStoreLoaded();
  
  const session = await auth();
  const email = session?.user?.email?.toLowerCase() || "";
  const name = session?.user?.name || "Customer";
  
  const licenses = email ? await listLicensesForCustomer(email) : [];
  const devices = email ? listDevicesForCustomer(email) : [];
  const subs = email ? (listSubscriptionsForCustomer(email) as DashboardSub[]) : [];
  const billing = email ? getBillingSummary(email) : { invoices: [], payments: [], subscriptions: [], emails: [] };
  const tickets = email ? listSupportTickets({ customerEmail: email }) : [];
  
  const primaryLicense = licenses.find((l) => l.status === "active") || 
                         licenses.find((l) => l.status === "grace") || 
                         licenses.find((l) => l.status === "pending") || 
                         licenses[0];

  const activeDevices = devices.filter((d) => d.status === "active").length;
  
  const allSubs = [...subs, ...(billing.subscriptions as DashboardSub[])];
  const primarySub = allSubs.find((s) => s.status === "active" || s.status === "trialing" || s.status === "pending") || allSubs[0];

  const openTickets = tickets.filter((t) => t.status === "open" || t.status === "pending").length;

  return (
    <>
      <style>{`
        .dash-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
          gap: 20px;
          margin-bottom: 24px;
        }
        @media (max-width: 768px) {
          .dash-grid {
            grid-template-columns: 1fr;
            gap: 16px;
          }
        }
        .page-title {
          font-size: clamp(1.5rem, 4vw, 2rem);
          margin-bottom: 8px;
        }
        .page-sub {
          font-size: clamp(0.875rem, 2vw, 1rem);
          color: #9a95a8;
          margin-bottom: 24px;
        }
        .card {
          padding: clamp(16px, 3vw, 24px);
          background: #16161d;
          border: 1px solid #2a2a38;
          border-radius: 12px;
          transition: transform 0.2s ease;
        }
        .card:hover {
          transform: translateY(-2px);
        }
        .card h3 {
          font-size: clamp(0.75rem, 2vw, 0.875rem);
          color: #f5c542;
          margin-bottom: 12px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        .card .value {
          font-size: clamp(1.25rem, 3vw, 1.5rem);
          color: #f4f1e8;
          margin-bottom: 8px;
        }
        .card .meta {
          font-size: clamp(0.75rem, 2vw, 0.875rem);
          color: #9a95a8;
        }
        .card .meta a {
          color: #f5c542;
          text-decoration: none;
        }
        .card .meta a:hover {
          text-decoration: underline;
        }
      `}</style>

      <header>
        <h1 className="page-title">Dashboard</h1>
        <p className="page-sub">
          Live commercial status · grace {graceDays()} day(s) · Core Trading Engine isolated. Installer activation is
          required — Dashboard shows Active only after {product.installer.name} (or portal) confirms your key.
        </p>
      </header>

      <div className="dash-grid">
        <div className="card">
          <h3>Customer</h3>
          <div className="value">{name}</div>
          <div className="meta">{email || "Not signed in"}</div>
        </div>
        <div className="card">
          <h3>Subscription</h3>
          <div className="value">
            <StatusBadge status={primarySub?.status || "None"} />
          </div>
          <div className="meta">
            {primarySub?.plan
              ? `${primarySub.plan} · exp ${primarySub.expirationDate?.slice(0, 10) || "—"}`
              : "No subscription — "}
            {!primarySub && <Link href="/portal/billing">Billing</Link>}
          </div>
        </div>
        <div className="card">
          <h3>License</h3>
          <div className="value">
            <StatusBadge status={primaryLicense?.status || "None"} />
          </div>
          <div className="meta">
            {primaryLicense?.keyMasked ? (
              <Link href="/portal/licenses">{primaryLicense.keyMasked}</Link>
            ) : (
              <>— <Link href="/portal/licenses">My Licenses</Link></>
            )}
          </div>
        </div>
        <div className="card">
          <h3>Product Edition</h3>
          <div className="value" style={{ fontSize: "clamp(1rem, 2.5vw, 1.25rem)" }}>
            {brand.productName}
          </div>
        </div>
        <div className="card">
          <h3>Devices</h3>
          <div className="value">
            {activeDevices} / {primaryLicense?.seatsMax ?? "—"}
          </div>
          <div className="meta">
            <Link href="/portal/devices">Manage devices</Link>
          </div>
        </div>
        <div className="card">
          <h3>Last validated</h3>
          <div className="value" style={{ fontSize: "clamp(0.875rem, 2vw, 1rem)" }}>
            {primaryLicense?.lastValidatedAt?.replace("T", " ").slice(0, 19) || "Not yet validated"}
          </div>
        </div>
        <div className="card">
          <h3>Invoices / Orders</h3>
          <div className="value">
            {billing.invoices.length} / {billing.payments.filter((p) => p.status === "succeeded").length}
          </div>
          <div className="meta">
            <Link href="/portal/invoices">Invoices</Link> · <Link href="/portal/orders">Orders</Link>
          </div>
        </div>
        <div className="card">
          <h3>Open support tickets</h3>
          <div className="value">{openTickets}</div>
          <div className="meta">
            <Link href="/portal/support">Support</Link>
          </div>
        </div>
        <div className="card">
          <h3>Quick links</h3>
          <div className="meta">
            <Link href="/portal/downloads">Downloads</Link> · <Link href="/portal/announcements">Announcements</Link> ·{" "}
            <Link href="/portal/account">Account</Link>
          </div>
        </div>
      </div>

      <AiCommandCenterPreview />
    </>
  );
}