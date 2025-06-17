#!/bin/bash

# Script to create high-quality app icons with black background from a source image
# This fixes the "Invalid large app icon" validation error while preserving image quality

SOURCE_IMAGE="/Volumes/NoodleDev/khamarit/Desktop/100Rebuild/100Days.png"
TARGET_DIR="100DaysRebuild/Assets.xcassets/AppIcon.appiconset"
APP_STORE_ICON="AppIcons/appstore.png"

echo "Creating high-quality app icons with black background from source image..."

# Verify source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
  echo "Error: Source image not found at $SOURCE_IMAGE"
  exit 1
fi

# Create a temp directory for processing
mkdir -p temp_icons

# Create the base icon with black background at highest quality
echo "Creating base icon with black background (maintaining quality)..."
magick "$SOURCE_IMAGE" -background black -alpha remove -alpha off +repage -colorspace RGB -define png:color-type=2 -quality 100 -filter Lanczos -strip -density 300 "temp_icons/base.png"

# Generate all required sizes with high quality settings
echo "Generating icons of all required sizes with maximum quality..."

# App icon sizes needed for iOS
declare -a SIZES=("29" "40" "57" "58" "60" "80" "87" "114" "120" "180" "1024")

for size in "${SIZES[@]}"; do
  echo "Creating ${size}x${size} icon with high quality..."
  
  # Use high-quality resize with Lanczos filter and no compression
  magick "temp_icons/base.png" -resize "${size}x${size}" -background black -gravity center -extent "${size}x${size}" \
    -alpha off -colorspace RGB -define png:color-type=2 -define png:compression-level=0 \
    -filter Lanczos -quality 100 -strip "${TARGET_DIR}/${size}.png"
  
  # Verify the image has no alpha channel
  channels=$(magick identify -format "%[channels]" "${TARGET_DIR}/${size}.png")
  echo "Channels for ${size}.png: $channels"
done

# Create App Store icon with highest quality
echo "Creating App Store icon with maximum quality..."
magick "temp_icons/base.png" -resize "1024x1024" -background black -gravity center -extent "1024x1024" \
  -alpha off -colorspace RGB -define png:color-type=2 -define png:compression-level=0 \
  -filter Lanczos -quality 100 -strip "$APP_STORE_ICON"

# Clean up
rm -rf temp_icons

echo "All app icons created with black backgrounds and maximum quality! Ready for App Store submission." 