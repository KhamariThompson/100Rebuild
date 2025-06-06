#!/bin/bash

# Script to create ultra high-quality app icons with black background
# Preserves maximum image quality while meeting App Store requirements

SOURCE_IMAGE="/Volumes/NoodleDev/khamarit/Desktop/100Rebuild/100Days.png"
TARGET_DIR="100DaysRebuild/Assets.xcassets/AppIcon.appiconset"
APP_STORE_ICON="AppIcons/appstore.png"

echo "Creating ultra high-quality app icons from source image..."

# Verify source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
  echo "Error: Source image not found at $SOURCE_IMAGE"
  exit 1
fi

# Create a temp directory for processing
mkdir -p temp_icons

# Step 1: Create a high-quality base with black background
echo "Step 1: Creating maximum quality base image..."
# Use a larger intermediary size for better downscaling
magick "$SOURCE_IMAGE" -background black -alpha remove \
  -resize 2048x2048 -extent 2048x2048 -gravity center \
  -alpha off -colorspace RGB -define png:color-type=2 \
  -density 600 -quality 100 -filter Lanczos \
  "temp_icons/base_hq.png"

# App icon sizes needed for iOS
declare -a SIZES=("29" "40" "57" "58" "60" "80" "87" "114" "120" "180" "1024")

echo "Step 2: Generating all icon sizes with maximum quality preservation..."
for size in "${SIZES[@]}"; do
  echo "Creating ${size}x${size} icon..."
  
  # Two-step approach for better quality:
  # 1. Resize with Lanczos filter at very high quality
  # 2. Apply minimal processing to maintain quality
  magick "temp_icons/base_hq.png" \
    -filter Lanczos -resize ${size}x${size} \
    -background black -gravity center -extent ${size}x${size} \
    -colorspace RGB -define png:color-type=2 \
    -define png:compression-level=0 \
    -quality 100 -strip \
    "${TARGET_DIR}/${size}.png"
  
  # Verify no alpha channel and proper format
  channels=$(magick identify -format "%[channels]" "${TARGET_DIR}/${size}.png")
  echo "Channels for ${size}.png: $channels"
  
  # Also verify file size
  filesize=$(du -h "${TARGET_DIR}/${size}.png" | cut -f1)
  echo "Size of ${size}.png: $filesize"
done

# Create App Store icon with absolute highest quality
echo "Step 3: Creating App Store icon with maximum quality..."
magick "temp_icons/base_hq.png" \
  -filter Lanczos -resize 1024x1024 \
  -background black -gravity center -extent 1024x1024 \
  -colorspace RGB -define png:color-type=2 \
  -define png:compression-level=0 \
  -quality 100 -strip \
  "$APP_STORE_ICON"

# Clean up
rm -rf temp_icons

echo "✅ All app icons created with maximum possible quality while meeting App Store requirements!"
echo "📱 Ready for App Store submission." 