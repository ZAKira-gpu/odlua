// Simple branding asset copier
// Usage: node scripts/apply-branding.js

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const brandDir = path.join(root, 'brand-assets');
const configPath = path.join(brandDir, 'branding.config.json');

if (!fs.existsSync(configPath)) {
  console.error('branding.config.json not found in brand-assets/');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function copyIfExists(srcRelative, destPath) {
  const src = path.join(brandDir, srcRelative);
  if (!fs.existsSync(src)) {
    console.warn(`SKIP: ${srcRelative} (source not found)`);
    return false;
  }
  ensureDir(path.dirname(destPath));
  fs.copyFileSync(src, destPath);
  console.log(`COPIED: ${srcRelative} -> ${path.relative(root, destPath)}`);
  return true;
}

// Web (Next.js) public folder
const webTarget = path.join(root, 'public');
ensureDir(webTarget);
if (config.web) {
  Object.values(config.web).forEach((p) => {
    if (typeof p === 'string') {
      const dest = path.join(webTarget, path.basename(p));
      copyIfExists(p, dest);
    }
  });
}

// Extension assets
const extTarget = path.join(root, 'extension', 'src', 'assets');
ensureDir(extTarget);
if (config.extension) {
  Object.values(config.extension).forEach((p) => {
    if (typeof p === 'string') {
      const dest = path.join(extTarget, path.basename(p));
      copyIfExists(p, dest);
    }
  });
}

console.log('Done. Review warnings above for missing files.');
