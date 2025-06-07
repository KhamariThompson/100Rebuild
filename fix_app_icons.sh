#!/bin/bash

# Script to fix app icons by removing transparency and adding a black background
# This fixes the "Invalid large app icon" validation error

echo "Fixing app icons by removing alpha channel and adding black background..."

# Create temp directory
mkdir -p temp_fixed_icons

# Process all PNG files in the main app asset catalog
for icon in 100DaysRebuild/Assets.xcassets/AppIcon.appiconset/*.png; do
    filename=$(basename "$icon")
    echo "Processing $filename..."
    
    # Convert image to remove transparency and set black background
    # Force RGB colorspace without alpha channel
    magick "$icon" -background black -flatten -alpha off +repage -colorspace RGB -define png:color-type=2 "temp_fixed_icons/$filename"
    
    # Verify the image has no alpha channel
    channels=$(magick identify -format "%[channels]" "temp_fixed_icons/$filename")
    echo "Channels after processing: $channels"
    
    # Replace original with fixed version
    cp "temp_fixed_icons/$filename" "$icon"
    
    echo "Fixed $filename"
done

# Clean up
rm -rf temp_fixed_icons

# Also fix the large App Store icon
if [ -f "AppIcons/appstore.png" ]; then
    echo "Fixing App Store icon..."
    magick "AppIcons/appstore.png" -background black -flatten -alpha off +repage -colorspace RGB -define png:color-type=2 "temp_appstore.png"
    mv "temp_appstore.png" "AppIcons/appstore.png"
fi

# Also process icons in AppIcon.imageset if they exist
if [ -d "100DaysRebuild/Assets.xcassets/AppIcon.imageset" ]; then
    echo "Fixing icons in AppIcon.imageset..."
    for icon in 100DaysRebuild/Assets.xcassets/AppIcon.imageset/*.png; do
        filename=$(basename "$icon")
        echo "Processing $filename..."
        magick "$icon" -background black -flatten -alpha off +repage -colorspace RGB -define png:color-type=2 "temp_$filename"
        mv "temp_$filename" "$icon"
        echo "Fixed $filename"
    done
fi

echo "App icons fixed! They now have black backgrounds with no transparency." 