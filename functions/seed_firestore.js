/**
 * Odlua – Firestore Seed Script
 *
 * Seeds:
 *   • app_banners  – home screen carousel banners
 *   • app_config/version_control – force-update control document
 *
 * HOW TO RUN:
 *   1. Go to Firebase Console → Project Settings → Service Accounts
 *   2. Click "Generate new private key" and save as service-account.json
 *      inside this folder (functions/).
 *   3. cd functions
 *   4. node seed_firestore.js
 *
 * You can re-run this safely — it uses set() which overwrites.
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json"); // <- download from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "odlua-139c3",
});

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────
// BANNERS
// ─────────────────────────────────────────────────────────────────────
// Schema per document:
//   imageUrl        String   – publicly accessible image URL (Firebase Storage or CDN)
//   title           Map      – { en, ar, de, fr }
//   subtitle        Map      – { en, ar, de, fr }
//   targetCountries List     – ISO 3166-1 alpha-2 codes e.g. ['eg','de']. Empty = all.
//   isActive        bool     – set to false to hide without deleting
//   actionType      String   – 'none' | 'url'
//   actionValue     String   – URL to open when banner is tapped (if actionType='url')
//   order           int      – lower = shown first
//   startDate       Timestamp (optional) – don't show before this date
//   endDate         Timestamp (optional) – don't show after this date

const banners = [
  {
    id: "banner_welcome",
    imageUrl:
      "https://firebasestorage.googleapis.com/v0/b/odlua-139c3.appspot.com/o/banners%2Fbanner_welcome.jpg?alt=media",
    title: {
      en: "Share Homemade Food",
      ar: "شارك طعامك المنزلي",
      de: "Hausgemachtes Essen teilen",
      fr: "Partager la cuisine maison",
    },
    subtitle: {
      en: "Connect with chefs near you",
      ar: "تواصل مع الطهاة بالقرب منك",
      de: "Verbinde dich mit Köchen in deiner Nähe",
      fr: "Connectez-vous avec des chefs près de chez vous",
    },
    targetCountries: [], // empty = all countries
    isActive: true,
    actionType: "none",
    actionValue: "",
    order: 1,
  },
  {
    id: "banner_donate",
    imageUrl:
      "https://firebasestorage.googleapis.com/v0/b/odlua-139c3.appspot.com/o/banners%2Fbanner_donate.jpg?alt=media",
    title: {
      en: "Donate Surplus Food",
      ar: "تبرع بالطعام الزائد",
      de: "Überschussessen spenden",
      fr: "Donner les surplus alimentaires",
    },
    subtitle: {
      en: "Help reduce food waste in your community",
      ar: "ساعد في تقليل هدر الطعام في مجتمعك",
      de: "Hilf dabei, Lebensmittelverschwendung zu reduzieren",
      fr: "Aidez à réduire le gaspillage alimentaire",
    },
    targetCountries: [],
    isActive: true,
    actionType: "none",
    actionValue: "",
    order: 2,
  },
  {
    id: "banner_exchange",
    imageUrl:
      "https://firebasestorage.googleapis.com/v0/b/odlua-139c3.appspot.com/o/banners%2Fbanner_exchange.jpg?alt=media",
    title: {
      en: "Exchange Dishes",
      ar: "تبادل الأطباق",
      de: "Gerichte tauschen",
      fr: "Échanger des plats",
    },
    subtitle: {
      en: "Trade your cooking for something new",
      ar: "تداول طبخك بشيء جديد",
      de: "Tausche deine Kochkunst gegen etwas Neues",
      fr: "Échangez votre cuisine contre quelque chose de nouveau",
    },
    targetCountries: [],
    isActive: true,
    actionType: "none",
    actionValue: "",
    order: 3,
  },
];

// ─────────────────────────────────────────────────────────────────────
// VERSION CONTROL
// ─────────────────────────────────────────────────────────────────────
const versionControl = {
  forceUpdate: false,
  minimumAndroidVersion: "2.1.0",
  minimumIOSVersion: "2.1.0",
  updateMessage: {
    en: "A new version of Odlua is available. Please update to continue.",
    ar: "إصدار جديد من أودلوا متاح. يرجى التحديث للمتابعة.",
    de: "Eine neue Version von Odlua ist verfügbar. Bitte aktualisieren Sie, um fortzufahren.",
    fr: "Une nouvelle version d'Odlua est disponible. Veuillez mettre à jour pour continuer.",
  },
  storeUrls: {
    android: "https://play.google.com/store/apps/details?id=com.app.odlua",
    ios: "https://apps.apple.com/app/id", // <- add your App Store ID here
  },
};

// ─────────────────────────────────────────────────────────────────────
// SEED
// ─────────────────────────────────────────────────────────────────────
async function seed() {
  console.log("🌱 Starting Firestore seed...\n");

  // Banners
  for (const banner of banners) {
    const { id, ...data } = banner;
    await db.collection("app_banners").doc(id).set(data);
    console.log(`  ✅ app_banners/${id}`);
  }

  // Version control
  await db
    .collection("app_config")
    .doc("version_control")
    .set(versionControl);
  console.log("  ✅ app_config/version_control");

  console.log("\n🎉 Seed complete!");
  process.exit(0);
}

seed().catch((err) => {
  console.error("❌ Seed failed:", err);
  process.exit(1);
});
