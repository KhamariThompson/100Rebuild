# 100Days

A professional-grade iOS app for tracking and completing 100-day challenges, built with SwiftUI and following MVVM + Feature-based architecture. This app helps users build habits and track their progress through 100-day challenges with features like streak tracking, progress visualization, and smart reminders.

## 🚀 Prerequisites

Before you begin, ensure you have the following installed:

- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later
- CocoaPods (for Firebase dependencies)
- A Firebase account (for backend services)

## 🚀 Features

- **Challenge Tracking**: Create and monitor your 100-day challenges
- **Daily Check-ins**: Record your progress with optional notes
- **Streak Counter**: Track your current and longest streaks
- **Progress Stats**: View detailed progress metrics and completion rates
- **Smart Reminders**: Get notified when it's time to check in
- **Multiple Challenges**: Manage different challenges simultaneously
- **Dark Mode**: Beautiful dark-themed UI that's easy on the eyes
- **Pro Features**: Analytics, unlimited challenges, and more with a subscription

## 🏗️ Project Structure

```
100Days/
├── App/
│   ├── App100Days.swift        # Main app entry point
│   └── AppDelegate.swift       # App lifecycle and Firebase setup
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift        # Color palette and theme
│   │   ├── Typography.swift    # Typography system
│   │   ├── Buttons.swift       # Reusable button styles
│   │   └── Components/         # Reusable UI components
│   └── Utils/
│       ├── BaseViewModel.swift # Base view model protocol
│       └── Extensions/         # Swift extensions
├── Features/
│   ├── Auth/
│   │   ├── Views/             # Login, Signup, Password Reset
│   │   └── ViewModels/        # Auth logic
│   ├── Challenges/
│   │   ├── Views/             # Challenge list, creation, details
│   │   └── ViewModels/        # Challenge management
│   ├── Progress/
│   │   ├── Views/             # Progress dashboard, charts
│   │   └── ViewModels/        # Progress calculations
│   ├── Reminders/
│   │   ├── Views/             # Reminder settings
│   │   └── ViewModels/        # Notification logic
│   └── Social/
│       ├── Views/             # Social features UI
│       └── ViewModels/        # Social features logic
├── Models/
│   ├── Challenge.swift        # Challenge data model
│   ├── User.swift            # User data model
│   └── Progress.swift        # Progress tracking model
├── Services/
│   ├── FirebaseService.swift  # Firebase integration
│   ├── NotificationService.swift # Local notifications
│   ├── AuthService.swift     # Authentication service
│   └── SubscriptionService.swift # RevenueCat integration
├── Resources/
│   ├── Assets.xcassets       # Asset catalog
│   └── Fonts/                # Custom fonts
└── SupportingFiles/
    ├── Info.plist            # App configuration
    └── GoogleService-Info.plist # Firebase config
```

## 🛠️ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/KhamariThompson/100Rebuild.git
cd 100Days
```

### 2. Install Dependencies

```bash


# Install project dependencies
pod install
```

### 3. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add an iOS app to your Firebase project
3. Download `GoogleService-Info.plist`
4. Place `GoogleService-Info.plist` in the `SupportingFiles` directory
5. Enable Authentication and Firestore in Firebase Console

### 4. RevenueCat Setup (Optional)

1. Create a RevenueCat account
2. Add your API key to `Configuration/RevenueCat.xcconfig`
3. Configure your subscription products in RevenueCat dashboard

### 5. Build and Run

1. Open `100Days.xcworkspace` (not .xcodeproj)
2. Select your development team in Xcode
3. Choose a simulator or device
4. Build and run (⌘R)

## 🎨 Design System

The app uses a modern, dark-themed design system:

### Colors

- Primary: #007AFF (iOS Blue)
- Secondary: #5856D6 (Purple)
- Background: #000000 (Black)
- Surface: #1C1C1E (Dark Gray)
- Text: #FFFFFF (White)
- Subtext: #8E8E93 (Light Gray)

### Typography

- Headline: SF Pro Display, 34pt
- Title: SF Pro Display, 28pt
- Body: SF Pro Text, 17pt
- Caption: SF Pro Text, 12pt

### Components

- Cards with 16pt corner radius
- Subtle shadows and gradients
- Consistent spacing (8pt grid)
- Animated transitions

## 🔧 Configuration

### Environment Variables

Create a `Configuration/Config.xcconfig` file with your development or production configuration:

```xcconfig
// For development
#include "Development.xcconfig"

// For production
// #include "Production.xcconfig"
```

### API Security

**Important**: Do not store API keys in configuration files for production builds. Instead:

1. For RevenueCat: Use the secure runtime wrapper in SubscriptionService.swift
2. For Firebase: Use GoogleService-Info.plist (which is gitignored)

### Authentication

The app supports:

- Email/Password authentication
- Apple Sign-In
- Google Sign-In

### Build Settings

- Deployment Target: iOS 17.0
- Swift Version: 5.9
- Enable Dark Mode

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add YourFeature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

### Code Style

- Follow Swift Style Guide
- Use SwiftLint for code formatting
- Write unit tests for new features
- Document public APIs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Firebase for backend services
- RevenueCat for subscription management
- SwiftUI for the amazing UI framework
- The iOS community for inspiration and support

## Troubleshooting

### Fixing "68 duplicate symbols" Linker Error

If you encounter a linker error with "68 duplicate symbols" when building the project, the following changes have been made to address this issue:

1. The root-level `Core` directory has been renamed to `Core.bak` to prevent it from being included in the build and causing duplicate symbol definitions with `100DaysRebuild/Core`.

2. Added the `-Wl,-no_warn_duplicate_libraries` flag to the project's Other Linker Flags to suppress warnings about duplicate libraries.

To build the project after these changes:

- Clean the build folder (Shift+Command+K)
- Build the project (Command+B)

If you still encounter issues, you may need to:

1. Check for duplicate module imports in your code
2. Look for duplicate class/struct definitions across the project
3. Verify that the same frameworks aren't being imported multiple times through different dependency paths

# 100Days Challenge App - Technical Improvements

This document summarizes the technical improvements made to the 100Days Challenge App to address various issues and enhance the user experience.

## Fixed Issues

### Authentication View Improvements (AuthView.swift)

- Fixed binding vs FocusState issue by changing the EmailPasswordForm component to use @Binding for focusedField instead of @FocusState
- Removed unnecessary try expressions from async calls that don't throw
- Created non-throwing wrappers in the ViewModel for all auth operations:
  - signInWithEmail(email:password:) - non-throwing wrapper for auth.signIn
  - signUpWithEmail(email:password:) - non-throwing wrapper for auth.createUser
  - signInWithGoogle() - handles finding rootViewController and error handling
  - signInWithApple() - wraps the throwing signInWithAppleInternal with error handling
  - resetPassword(email:) - non-throwing wrapper for auth.sendPasswordReset
  - signOutWithoutThrowing() - non-throwing wrapper for auth.signOut
- Updated SettingsView.swift and ProfileViewModel.swift to use the signOutWithoutThrowing() method consistently

### Apple Sign-In Authentication Issues

- Added guards against multiple simultaneous auth operations
- Improved error handling to properly distinguish between user cancellation and actual errors
- Enhanced authentication flow with proper loading states to prevent UI glitches

### Navigation Constraint Errors

- Fixed SFAuthenticationViewController constraint conflicts by:
  - Implementing ephemeral web browser sessions
  - Adding proper delay before presenting authentication views
  - Ensuring proper cleanup after authentication is completed or canceled

### Check-In Functionality Improvements

- Fixed issue where tapping on the challenge card would incorrectly bring up the edit page
- Removed the problematic tap gesture that was causing the wrong sheet to appear
- Ensured check-in button triggers the proper check-in flow without navigation conflicts
- Added validation to prevent check-in attempts for challenges that are already completed

### Profile Statistics Accuracy

- Modified the challenge counting logic to only include active (non-archived) challenges
- Improved data loading from Firestore with proper filtering
- Enhanced error handling for profile data retrieval

### UI Appearance and Keyboard Handling

- Improved navigation bar appearance settings to prevent constraint conflicts
- Enhanced keyboard handling at the application level
- Implemented cleaner navigation appearance with shadow removal

## Technical Implementation Details

The improvements focused on:

1. Better state management for authentication flows
2. Proper view controller lifecycle management
3. Clear separation between different user actions (check-in vs. editing)
4. Accurate data queries and state updates
5. Robust error handling with user-friendly messages

These changes should provide a more stable and intuitive user experience while addressing the specific technical issues that were occurring in the app.

# App Store Submission Checklist

Before submitting the app to the App Store, ensure all of these items are ready:

## Required Assets

- [x] App icon in all required sizes (1024x1024 for App Store)
- [x] Screenshots for all supported device sizes
- [x] App preview videos (optional but recommended)

## Metadata

- [x] App name: 100Days
- [x] App description
- [x] Keywords for App Store search
- [x] Privacy policy URL (https://100days.site/privacy)
- [x] Support URL
- [x] Marketing URL (optional)
- [x] Copyright information

## Technical Requirements

- [x] All features are fully functional
- [x] Data is properly saved to Firebase/Firestore
- [x] Challenges are correctly filtered (showing active, hiding archived)
- [x] Progress view shows correct challenge statistics
- [x] Fixed duplicate navigation headers throughout the app
- [x] Ensured proper data persistence when offline
- [x] Fixed all constraint issues in SFAuthenticationViewController
- [x] Optimized memory usage for large challenge lists

## Compliance

- [x] Privacy policy implemented and accessible in the app
- [x] Terms of Service implemented and accessible in the app
- [x] App complies with Apple's App Review Guidelines
- [x] Ensured no hardcoded API credentials in the app
- [x] Subscription products configured in App Store Connect
- [x] In-app purchases tested and working

## Final Testing

- [x] Tested on multiple iOS versions
- [x] Verified proper functionality on slow network connections
- [x] Checked compatibility with different device sizes
- [x] Ensured dark mode support works correctly
- [x] Verified all animations run smoothly

With all items checked, the app is ready for submission to the App Store!
