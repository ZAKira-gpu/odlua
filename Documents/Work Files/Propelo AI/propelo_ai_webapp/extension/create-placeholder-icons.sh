#!/bin/bash

# Simple script to create placeholder icon files for Chrome extension
# This creates basic colored squares as temporary icons

echo "🎨 Creating placeholder icons for Propelo Chrome Extension..."

cd "$(dirname "$0")"

# Check if ImageMagick is installed (optional)
if command -v convert &> /dev/null; then
    echo "✅ ImageMagick found - creating colored icons..."
    
    # Create 16x16 icon
    convert -size 16x16 xc:"#00FFFF" icons/icon16.png
    echo "✅ Created icon16.png"
    
    # Create 48x48 icon
    convert -size 48x48 xc:"#00FFFF" icons/icon48.png
    echo "✅ Created icon48.png"
    
    # Create 128x128 icon
    convert -size 128x128 xc:"#00FFFF" icons/icon128.png
    echo "✅ Created icon128.png"
    
    echo "🎉 Placeholder icons created successfully!"
else
    echo "⚠️  ImageMagick not found. Please create icons manually:"
    echo ""
    echo "Required files:"
    echo "  - icons/icon16.png (16x16 pixels)"
    echo "  - icons/icon48.png (48x48 pixels)"
    echo "  - icons/icon128.png (128x128 pixels)"
    echo ""
    echo "You can:"
    echo "  1. Use any image editor (Photoshop, GIMP, Figma)"
    echo "  2. Copy your Propelo logo and resize"
    echo "  3. Use online tools like favicon.io"
    echo ""
    echo "Recommended colors:"
    echo "  - Cyan: #00FFFF"
    echo "  - Cream: #FFF5E6"
fi
