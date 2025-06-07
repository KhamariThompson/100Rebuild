#!/bin/bash

# Source image
SOURCE="100DaysRebuild/Assets.xcassets/100DaysPro.imageset/100Days.png"

# Destination directory
DEST="100DaysRebuild/Assets.xcassets/AppIcon.appiconset"

# Check if sips is available (macOS utility for image processing)
if ! command -v sips &> /dev/null; then
    echo "Error: sips command not found. This script requires macOS."
    exit 1
fi

# Create all required icon sizes
echo "Generating app icons from $SOURCE..."

# iPhone icons
sips -z 40 40 "$SOURCE" --out "$DEST/40.png"
sips -z 60 60 "$SOURCE" --out "$DEST/60.png"
sips -z 29 29 "$SOURCE" --out "$DEST/29.png"
sips -z 58 58 "$SOURCE" --out "$DEST/58.png"
sips -z 87 87 "$SOURCE" --out "$DEST/87.png"
sips -z 80 80 "$SOURCE" --out "$DEST/80.png"
sips -z 120 120 "$SOURCE" --out "$DEST/120.png"
sips -z 57 57 "$SOURCE" --out "$DEST/57.png"
sips -z 114 114 "$SOURCE" --out "$DEST/114.png"
sips -z 180 180 "$SOURCE" --out "$DEST/180.png"
sips -z 1024 1024 "$SOURCE" --out "$DEST/1024.png"

echo "All app icons have been generated!" 