Brand Assets
============

This folder contains logo and branding assets for Propelo and a simple config + script to apply them to both the web app and the extension.

Files
- `logos/` - place your high-resolution logo files here (SVG / PNG @2x or @3x). Current placeholder: `propelo-logo.svg`.
- `branding.config.json` - mapping for what should be copied to `public/` (web) and `extension/src/assets/` (extension).
- `scripts/apply-branding.js` - Node script that reads `branding.config.json` and copies listed files into the app's `public/` and extension `assets/` folders.

How to use
1. Replace the placeholder logo(s) in `brand-assets/logos` with your final high-resolution files. Keep the filenames consistent or update `branding.config.json` accordingly.
2. From the project root run:

```bash
node scripts/apply-branding.js
```

3. The script will copy the listed assets into:
- `public/` (web app)
- `extension/src/assets/` (extension)

4. Restart dev server if necessary.

Tips
- Prefer SVG for logos. Add PNG @2x/@3x for environments that need raster images.
- If you upgrade logos, re-run the script to push updates into both targets.

Editing what shows where
- Edit `brand-assets/branding.config.json` to change which file is copied to which target and the filenames used by each app.

If you want, I can update the app code to reference new names (e.g., swap `logo.png` references to a new file). Ask me to update code after you place the final logos.
