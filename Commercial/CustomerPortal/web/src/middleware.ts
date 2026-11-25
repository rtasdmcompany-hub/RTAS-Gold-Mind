import { auth } from "@/auth";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Ye routes bina login ke nahi khulne chahiye
const PROTECTED_ROUTES = ["/portal"];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Portal routes ko protect karo
  const isProtected = PROTECTED_ROUTES.some((route) => pathname.startsWith(route));

  if (isProtected) {
    const session = await auth();

    // Agar session nahi hai to login par redirect karo
    if (!session?.user) {
      const loginUrl = new URL("/login", request.url);
      loginUrl.searchParams.set("callbackUrl", pathname);
      return NextResponse.redirect(loginUrl);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|.*\\.png$).*)"],
};