/**
 * manage_banners.js  — CLI tool to manage app_banners from terminal
 *
 * USAGE:
 *   node manage_banners.js list                          → list all banners
 *   node manage_banners.js enable  <id>                 → activate a banner
 *   node manage_banners.js disable <id>                 → deactivate a banner
 *   node manage_banners.js add <imageUrl> "<title_en>"  → add a new banner
 *   node manage_banners.js delete <id>                  → permanently delete
 *
 * EXAMPLES:
 *   node manage_banners.js list
 *   node manage_banners.js enable  banner_welcome
 *   node manage_banners.js disable banner_welcome
 *   node manage_banners.js add "https://storage.../...jpg" "Spring Sale"
 *   node manage_banners.js delete  banner_old
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const [, , command, ...args] = process.argv;

// ─── helpers ────────────────────────────────────────────────────────────────

function pad(str, len) {
  return String(str ?? "").substring(0, len).padEnd(len);
}

async function listBanners() {
  const snap = await db.collection("app_banners").get();
  if (snap.empty) {
    console.log("📭 No banners found in app_banners collection.");
    return;
  }

  // Sort in memory so documents without an order field still appear
  const docs = [...snap.docs].sort((a, b) => {
    const oa = a.data().order ?? 999;
    const ob = b.data().order ?? 999;
    return oa - ob;
  });

  console.log("\n" + pad("ID", 25) + pad("ACTIVE", 8) + pad("ORDER", 7) + "TITLE (en)");
  console.log("─".repeat(75));

  for (const doc of docs) {
    const d = doc.data();
    const titleEn =
      (d.title instanceof Object ? d.title?.en : d.title) ?? "—";
    const active = d.isActive === true ? "✅ yes" : "⛔ no ";
    console.log(pad(doc.id, 25) + pad(active, 8) + pad(d.order ?? "—", 7) + titleEn);
  }
  console.log();
}

async function setBannerActive(id, value) {
  const ref = db.collection("app_banners").doc(id);
  const doc = await ref.get();
  if (!doc.exists) {
    console.error(`❌ Banner "${id}" not found.`);
    process.exit(1);
  }
  await ref.update({ isActive: value });
  console.log(`${value ? "✅ Enabled" : "⛔ Disabled"} banner: ${id}`);
}

async function addBanner(imageUrl, titleEn) {
  if (!imageUrl) {
    console.error("❌ Usage: node manage_banners.js add <imageUrl> \"<title_en>\"");
    process.exit(1);
  }

  // Generate a unique-ish ID
  const slug = (titleEn || "banner")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "");
  const id = `banner_${slug}_${Date.now().toString(36)}`;

  // Find highest order
  const snap = await db
    .collection("app_banners")
    .orderBy("order", "desc")
    .limit(1)
    .get()
    .catch(() => ({ empty: true }));
  const nextOrder = snap.empty ? 1 : (snap.docs[0].data().order ?? 0) + 1;

  const data = {
    imageUrl,
    title: { en: titleEn || "", ar: "", de: "", fr: "" },
    subtitle: { en: "", ar: "", de: "", fr: "" },
    targetCountries: [],
    isActive: true,
    actionType: "none",
    actionValue: "",
    order: nextOrder,
  };

  await db.collection("app_banners").doc(id).set(data);
  console.log(`\n✅ Banner created: ${id}`);
  console.log(`   imageUrl : ${imageUrl}`);
  console.log(`   title.en : ${titleEn || "(empty)"}`);
  console.log(`   order    : ${nextOrder}`);
  console.log(`   isActive : true`);
  console.log(`\n💡 Edit title/subtitle in Firebase Console to add more languages.`);
}

async function deleteBanner(id) {
  const ref = db.collection("app_banners").doc(id);
  const doc = await ref.get();
  if (!doc.exists) {
    console.error(`❌ Banner "${id}" not found.`);
    process.exit(1);
  }
  await ref.delete();
  console.log(`🗑️  Deleted banner: ${id}`);
}

// ─── dispatch ────────────────────────────────────────────────────────────────

async function main() {
  switch (command) {
    case "list":
      await listBanners();
      break;

    case "enable":
      if (!args[0]) { console.error("❌ Usage: node manage_banners.js enable <id>"); process.exit(1); }
      await setBannerActive(args[0], true);
      break;

    case "disable":
      if (!args[0]) { console.error("❌ Usage: node manage_banners.js disable <id>"); process.exit(1); }
      await setBannerActive(args[0], false);
      break;

    case "add":
      await addBanner(args[0], args.slice(1).join(" "));
      break;

    case "delete":
    case "remove":
      if (!args[0]) { console.error("❌ Usage: node manage_banners.js delete <id>"); process.exit(1); }
      await deleteBanner(args[0]);
      break;

    default:
      console.log(`
Usage:
  node manage_banners.js list
  node manage_banners.js enable  <id>
  node manage_banners.js disable <id>
  node manage_banners.js add <imageUrl> "<title_en>"
  node manage_banners.js delete  <id>
      `);
  }
}

main().catch((err) => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});
