#!/bin/bash

# This script temporarily disables strict concurrency checking
# Run this to quickly build for App Store submission

PROJECT_FILE="100DaysRebuild.xcodeproj/project.pbxproj"

# Backup the current project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Replace strict concurrency setting with minimal
sed -i '' 's/SWIFT_STRICT_CONCURRENCY = complete/SWIFT_STRICT_CONCURRENCY = minimal/g' "$PROJECT_FILE"

echo "✅ Strict concurrency checking has been set to 'minimal'"
echo "📦 You can now build for App Store submission"
echo "⚠️  To restore strict checking later, run: mv $PROJECT_FILE.backup $PROJECT_FILE"
