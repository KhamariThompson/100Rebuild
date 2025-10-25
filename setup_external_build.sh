#!/bin/bash

# Script to configure Xcode and development environment to use external SSD
# Run this script each time you start development to ensure external drive is used

echo "Configuring development environment to use external SSD..."

# Set Xcode DerivedData location to external drive
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation "/Volumes/NoodleDev/XcodeBuildData/DerivedData"

# Create necessary directories on external drive
mkdir -p /Volumes/NoodleDev/XcodeBuildData/DerivedData
mkdir -p /Volumes/NoodleDev/TempFiles
mkdir -p /Volumes/NoodleDev/SimulatorData

# Set temporary directory to external drive
export TMPDIR="/Volumes/NoodleDev/TempFiles"

# Set simulator data directory (optional)
export SIMULATOR_RUNTIME_ROOT="/Volumes/NoodleDev/SimulatorData"

# Add to shell profile for persistence
if ! grep -q "TMPDIR=/Volumes/NoodleDev/TempFiles" ~/.zshrc; then
    echo 'export TMPDIR="/Volumes/NoodleDev/TempFiles"' >> ~/.zshrc
    echo "Added TMPDIR to ~/.zshrc"
fi

echo "✅ External SSD configuration complete!"
echo "📁 DerivedData: /Volumes/NoodleDev/XcodeBuildData/DerivedData"
echo "📁 Temp files: /Volumes/NoodleDev/TempFiles"
echo ""
echo "Please restart Xcode for changes to take effect."






