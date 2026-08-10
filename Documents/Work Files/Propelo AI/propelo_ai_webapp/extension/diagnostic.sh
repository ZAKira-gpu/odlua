#!/bin/bash

# Propelo Extension - Quick Diagnostic Script
# Run this to check if everything is set up correctly

echo "========================================"
echo "🔍 PROPELO EXTENSION DIAGNOSTIC"
echo "========================================"
echo ""

echo "✅ Checking Extension Files..."
echo "----------------------------------------"

if [ -f "/Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist/manifest.json" ]; then
    echo "✓ manifest.json exists"
else
    echo "✗ manifest.json MISSING!"
fi

if [ -f "/Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist/content-upwork.js" ]; then
    SIZE=$(ls -lh /Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist/content-upwork.js | awk '{print $5}')
    echo "✓ content-upwork.js exists ($SIZE)"
else
    echo "✗ content-upwork.js MISSING!"
fi

if [ -f "/Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist/popup.js" ]; then
    echo "✓ popup.js exists"
else
    echo "✗ popup.js MISSING!"
fi

if [ -f "/Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist/background.js" ]; then
    echo "✓ background.js exists"
else
    echo "✗ background.js MISSING!"
fi

echo ""
echo "✅ Checking Next.js Server..."
echo "----------------------------------------"

if lsof -ti:3000 > /dev/null 2>&1; then
    echo "✓ Server is running on port 3000"
else
    echo "✗ Server NOT running on port 3000"
    echo "  Run: cd /Users/nourmahmoud/Desktop/propelo_ai_webapp && npm run dev"
fi

echo ""
echo "✅ Content Script Patterns in Manifest..."
echo "----------------------------------------"
grep -A 15 "content_scripts" /Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist/manifest.json | grep "matches" -A 5 | head -20

echo ""
echo "========================================"
echo "📋 NEXT STEPS:"
echo "========================================"
echo ""
echo "1. Go to chrome://extensions/"
echo "2. Remove old Propelo extension"
echo "3. Click 'Load unpacked'"
echo "4. Select: /Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/dist"
echo ""
echo "5. Go to a VALID Upwork job URL like:"
echo "   https://www.upwork.com/jobs/~01abc123def456..."
echo ""
echo "6. Open Console (F12 or Cmd+Option+I)"
echo "7. Refresh the page (Cmd+R)"
echo "8. Look for: [Propelo Upwork] 🚀 Initializing..."
echo ""
echo "========================================"
