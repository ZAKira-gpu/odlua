#!/usr/bin/env python3
"""
Simple logo processor for extension assets.
Reads source logos from the repository `brand-assets/logos` directory and
creates resized PNG variants (512px, 256px) into the extension assets folder.

Run from the repo root: `python3 extension/src/assets/process_logos.py`
"""

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC_DIR = ROOT / 'brand-assets' / 'logos'
OUT_DIR = Path(__file__).resolve().parent

RESIZES = [512, 256]

def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

def resample_png(src: Path, dest: Path, width: int):
    # Use sips on macOS to resample; fallback to copying if sips not available
    try:
        subprocess.run(['sips', '-s', 'format', 'png', '--resampleWidth', str(width), str(src), '--out', str(dest)], check=True)
        print(f"Resized {src.name} -> {dest.name} ({width}px)")
    except Exception as e:
        # fallback copy
        try:
            dest.write_bytes(src.read_bytes())
            print(f"Copied (fallback) {src.name} -> {dest.name}")
        except Exception as e2:
            print(f"Failed to process {src}: {e} / {e2}")

def main():
    if not SRC_DIR.exists():
        print(f"Source logos folder not found: {SRC_DIR}")
        return

    ensure_dir(OUT_DIR)

    for logo_name in ['full-logo.png', 'logo-banner.png', 'logo-icon.png']:
        src = SRC_DIR / logo_name
        if not src.exists():
            print(f"SKIP: {logo_name} (not found in {SRC_DIR})")
            continue

        base = logo_name.replace('.png', '')
        for size in RESIZES:
            dest = OUT_DIR / f"{base}-{size}.png"
            resample_png(src, dest, size)

    print("Done processing logos.")

if __name__ == '__main__':
    main()
