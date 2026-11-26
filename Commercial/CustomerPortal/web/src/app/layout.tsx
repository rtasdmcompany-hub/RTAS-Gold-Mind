import type { Viewport } from "next";
import { Cormorant_Garamond, Inter } from "next/font/google";
import { brandRootMetadata } from "@/lib/brand-metadata";
import { AiAssistantWidget } from "@/components/AiAssistantWidget";
import { auth } from "@/auth";
import "./globals.css";
import "../styles/enterprise.css";

const serif = Cormorant_Garamond({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-serif",
  display: "swap",
});

const sans = Inter({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata = brandRootMetadata();

export const viewport: Viewport = {
  themeColor: "#050505",
  colorScheme: "dark",
};

const ADMIN_ROLES = [
  "super_admin", "admin", "owner", "administrator",
  "commercial_manager", "support_agent", "support",
  "finance_manager", "qa_manager", "auditor",
];

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Session se role pata karo — widget ek hi baar, har page par, sahi role ke sath
  let role: "anonymous" | "customer" | "admin" = "anonymous";
  let email: string | undefined;
  try {
    const session = await auth();
    if (session?.user) {
      email = session.user.email || undefined;
      const r = ((session.user as { role?: string }).role || "customer").toLowerCase();
      role = ADMIN_ROLES.includes(r) ? "admin" : "customer";
    }
  } catch {
    role = "anonymous";
  }

  return (
    <html lang="en" className={`${serif.variable} ${sans.variable}`}>
      <body>
        {children}
        <AiAssistantWidget title="May I help you?" surface="website" role={role} customerEmail={email} />
      </body>
    </html>
  );
}