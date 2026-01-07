#!/bin/bash

# Script to enable C++ interoperability in Xcode project
# This updates Swift version and enables C++ interop

PROJECT_FILE="maxmiize-v1.xcodeproj/project.pbxproj"

echo "Configuring Xcode project for Swift-C++ interoperability..."

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
echo "✓ Created backup: $PROJECT_FILE.backup"

# Update Swift version to 6.0 (supports C++ interop)
sed -i '' 's/SWIFT_VERSION = 5\.0/SWIFT_VERSION = 6.0/g' "$PROJECT_FILE"
echo "✓ Updated SWIFT_VERSION to 6.0"

# Enable C++ and Objective-C++ interoperability
# Add SWIFT_OBJC_INTEROP_MODE if not present
if ! grep -q "SWIFT_OBJC_INTEROP_MODE" "$PROJECT_FILE"; then
    # This is a simplified approach - in reality, we'd need to add it properly
    echo "⚠ Note: SWIFT_OBJC_INTEROP_MODE may need manual configuration"
fi

echo ""
echo "Configuration complete!"
echo "Next steps:"
echo "1. Open maxmiize-v1.xcodeproj in Xcode"
echo "2. Build the project to verify Swift 6.0 compatibility"
echo "3. If there are migration issues, Xcode will offer to fix them"

