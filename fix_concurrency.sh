#!/bin/bash

# This script adds @preconcurrency imports to files with UIKit actor isolation issues

echo "Adding @preconcurrency imports to UIKit files..."

# Add @preconcurrency import UIKit to App.swift
if grep -q "^import UIKit$" 100DaysRebuild/App.swift; then
    sed -i '' 's/^import UIKit$/@preconcurrency import UIKit/' 100DaysRebuild/App.swift
    echo "✓ Updated App.swift"
fi

# Add @preconcurrency import UIKit to AppFixes.swift
if grep -q "^import UIKit$" 100DaysRebuild/AppFixes.swift; then
    sed -i '' 's/^import UIKit$/@preconcurrency import UIKit/' 100DaysRebuild/AppFixes.swift
    echo "✓ Updated AppFixes.swift"
fi

# Add @preconcurrency import UserNotifications to SettingsView
if grep -q "^import UserNotifications$" 100DaysRebuild/Features/Settings/Views/SettingsView.swift; then
    sed -i '' 's/^import UserNotifications$/@preconcurrency import UserNotifications/' 100DaysRebuild/Features/Settings/Views/SettingsView.swift
    echo "✓ Updated SettingsView.swift"
fi

# Add @preconcurrency import FirebaseAuth to auth-related files
for file in 100DaysRebuild/Features/Settings/Views/ChangeEmailView.swift \
            100DaysRebuild/Features/Settings/Views/ChangePasswordView.swift; do
    if [ -f "$file" ] && grep -q "^import FirebaseAuth$" "$file"; then
        sed -i '' 's/^import FirebaseAuth$/@preconcurrency import FirebaseAuth/' "$file"
        echo "✓ Updated $(basename $file)"
    fi
done

echo "Done! Please rebuild the project."
