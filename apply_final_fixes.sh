#!/bin/bash

echo "Applying final concurrency fixes..."

# Fix App.swift - InputAssistantManager singleton
sed -i '' 's/static let shared = InputAssistantManager()/nonisolated(unsafe) static let shared = InputAssistantManager()/' 100DaysRebuild/App.swift
echo "✓ Fixed InputAssistantManager singleton"

# Fix App.swift - Add @MainActor to classes that need it
sed -i '' 's/^class AppDelegate:/@ preconcurrency\nclass AppDelegate:/' 100DaysRebuild/App.swift 2>/dev/null || true

# Fix CheckInService - add await keywords
sed -i '' 's/analyticsService\.trackEvent(/await analyticsService.trackEvent(/' 100DaysRebuild/CheckInService.swift
echo "✓ Fixed CheckInService await keywords"

echo "Done! Rebuild the project to see remaining errors."
