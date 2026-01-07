#!/bin/bash

# Script to fix app icon not showing in macOS
# This clears all caches and forces Xcode to rebuild the icon

echo "🔧 Fixing App Icon Display"
echo "================================"
echo ""

# 1. Kill Dock to refresh icon cache
echo "1. Restarting Dock..."
killall Dock 2>/dev/null
echo "   ✅ Dock restarted"
echo ""

# 2. Clear Launch Services database
echo "2. Clearing Launch Services cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
echo "   ✅ Launch Services cleared"
echo ""

# 3. Clear icon cache
echo "3. Clearing icon cache..."
sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null
rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null
echo "   ✅ Icon cache cleared"
echo ""

# 4. Remove DerivedData
echo "4. Clearing Xcode DerivedData..."
DERIVED_DATA_PATH=~/Library/Developer/Xcode/DerivedData
if [ -d "$DERIVED_DATA_PATH" ]; then
    rm -rf "$DERIVED_DATA_PATH"
    echo "   ✅ DerivedData cleared"
else
    echo "   ℹ️  No DerivedData to clear"
fi
echo ""

echo "================================"
echo "✨ Cache Clear Complete!"
echo "================================"
echo ""
echo "📋 Next Steps in Xcode:"
echo "   1. Clean Build Folder (⌘+Shift+K)"
echo "   2. Build (⌘+B)"
echo "   3. Run (⌘+R)"
echo ""
echo "💡 If still not showing:"
echo "   - Restart your Mac"
echo "   - Check that asset catalog is included in target"
echo ""

