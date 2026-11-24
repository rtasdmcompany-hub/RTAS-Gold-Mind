export const customerNav = [
  { href: "/portal", label: "Dashboard" },
  { href: "/portal/licenses", label: "My Licenses" },
  { href: "/portal/downloads", label: "Downloads" },
  { href: "/portal/billing", label: "Billing & Invoices" },
  { href: "/portal/devices", label: "Devices" },
  { href: "/portal/support", label: "Support" },
  { href: "/portal/account", label: "Account" },
  { href: "/portal/security", label: "Security" },
] as const;

/** Shown only to invited beta participants — not part of the default customer nav. */
export const betaNavItem = { href: "/portal/beta", label: "Beta Onboarding" } as const;

/** Shown only to enrolled partners — not part of the default customer nav. */
export const partnerNavItem = { href: "/portal/partner", label: "Partner Portal" } as const;

/** @deprecated use customerNav + admin entry */
export const portalNav = [
  ...customerNav,
  { href: "/portal/admin", label: "Admin Console" },
] as const;