import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

// Initialize Firebase Admin
const apps = getApps();

if (!apps.length) {
  initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
  });
}

export const db = getFirestore();
export const auth = getAuth();

// Collections
export const collections = {
  users: "users",
  proposals: "proposals",
  clients: "clients",
  snippets: "snippets",
  analytics: "analytics",
  enhancements: "enhancements",
} as const;

// Helper functions
export async function getDocument(collection: string, id: string) {
  const doc = await db.collection(collection).doc(id).get();
  if (!doc.exists) {
    return null;
  }
  return { id: doc.id, ...doc.data() };
}

export async function setDocument(collection: string, id: string, data: any) {
  await db.collection(collection).doc(id).set(data, { merge: true });
}

export async function addDocument(collection: string, data: any) {
  const ref = await db.collection(collection).add(data);
  return ref.id;
}

export async function updateDocument(collection: string, id: string, data: any) {
  await db.collection(collection).doc(id).update(data);
}

export async function deleteDocument(collection: string, id: string) {
  await db.collection(collection).doc(id).delete();
}

export async function queryDocuments(
  collection: string,
  filters: Array<{ field: string; operator: any; value: any }>,
  orderBy?: { field: string; direction: "asc" | "desc" },
  limit?: number
) {
  let query: any = db.collection(collection);

  filters.forEach((filter) => {
    query = query.where(filter.field, filter.operator, filter.value);
  });

  if (orderBy) {
    query = query.orderBy(orderBy.field, orderBy.direction);
  }

  if (limit) {
    query = query.limit(limit);
  }

  const snapshot = await query.get();
  return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
}

export default db;
