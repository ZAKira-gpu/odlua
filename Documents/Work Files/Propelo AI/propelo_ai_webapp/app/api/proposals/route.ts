import { NextRequest, NextResponse } from "next/server";
import { db, collections, queryDocuments, auth } from "@/lib/firebase-admin";
import { cookies } from "next/headers";

// GET all proposals for a user OR a single proposal by ID (public)
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const proposalId = searchParams.get("id");

    // If ID is provided, fetch single proposal (public access)
    if (proposalId) {
      try {
        // Extract userId from proposalId format: userId_actualProposalId
        const parts = proposalId.split('_');
        if (parts.length !== 2) {
          return NextResponse.json(
            { error: "Invalid proposal ID format" },
            { status: 400 }
          );
        }
        
        const [userId, actualProposalId] = parts;
        const docRef = db.collection(collections.users).doc(userId).collection('proposals').doc(actualProposalId);
        const doc = await docRef.get();

        if (!doc.exists) {
          return NextResponse.json(
            { error: "Proposal not found" },
            { status: 404 }
          );
        }

        const proposalData = { id: `${userId}_${doc.id}`, ...doc.data() };

        return NextResponse.json({
          success: true,
          data: proposalData,
        });
      } catch (error: any) {
        console.error("Error fetching proposal by ID:", error);
        return NextResponse.json(
          { error: "Failed to fetch proposal" },
          { status: 500 }
        );
      }
    }

    // Otherwise, fetch user's proposals (requires authentication)
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    
    if (!sessionCookie) {
      return NextResponse.json(
        { error: "Unauthorized - Please sign in" },
        { status: 401 }
      );
    }

    // Verify the session token
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(sessionCookie);
    } catch (error) {
      return NextResponse.json(
        { error: "Invalid session - Please sign in again" },
        { status: 401 }
      );
    }

    const userId = decodedToken.uid;

    const page = parseInt(searchParams.get("page") || "1");
    const pageSize = parseInt(searchParams.get("pageSize") || "20");
    const status = searchParams.get("status");
    const platform = searchParams.get("platform");

    // Query proposals from user subcollection
    let query = db
      .collection(collections.users)
      .doc(userId)
      .collection('proposals')
      .orderBy('createdAt', 'desc')
      .limit(pageSize);
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    if (platform) {
      query = query.where('platform', '==', platform);
    }

    const snapshot = await query.get();
    const proposals = snapshot.docs.map(doc => ({
      id: `${userId}_${doc.id}`, // Composite ID for public access
      ...doc.data()
    }));

    return NextResponse.json({
      success: true,
      data: proposals,
      page,
      pageSize,
      hasMore: proposals.length === pageSize,
    });
  } catch (error: any) {
    console.error("Error fetching proposals:", error);
    return NextResponse.json(
      { error: "Failed to fetch proposals" },
      { status: 500 }
    );
  }
}

// POST create a new proposal
export async function POST(req: NextRequest) {
  try {
    // Get user session from cookie
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    
    if (!sessionCookie) {
      return NextResponse.json(
        { error: "Unauthorized - Please sign in" },
        { status: 401 }
      );
    }

    // Verify the session token
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(sessionCookie);
    } catch (error) {
      return NextResponse.json(
        { error: "Invalid session - Please sign in again" },
        { status: 401 }
      );
    }

    const userId = decodedToken.uid;

    const body = await req.json();

    const proposalData = {
      ...body,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // Save to user's proposals subcollection
    const proposalRef = await db
      .collection(collections.users)
      .doc(userId)
      .collection('proposals')
      .add(proposalData);

    return NextResponse.json({
      success: true,
      data: { id: `${userId}_${proposalRef.id}`, ...proposalData },
    });
  } catch (error: any) {
    console.error("Error creating proposal:", error);
    return NextResponse.json(
      { error: "Failed to create proposal" },
      { status: 500 }
    );
  }
}
