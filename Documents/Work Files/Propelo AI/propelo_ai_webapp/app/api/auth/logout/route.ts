import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    // Clear the session cookie server-side
    const isProd = process.env.NODE_ENV === "production";
    let cookie = `session=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax`;

    if (isProd) {
      cookie += "; Secure";
    }

    return NextResponse.json(
      { success: true },
      {
        status: 200,
        headers: {
          "Set-Cookie": cookie,
        },
      }
    );
  } catch (error: any) {
    console.error("Error clearing session cookie:", error);
    return NextResponse.json({ error: "Failed to clear session cookie" }, { status: 500 });
  }
}
