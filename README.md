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
- **Milestone Celebrations**: Beautiful, animated celebration modals when you reach key milestones (Day 3, 7, 30, 50, 100)
- **Social Sharing**: Share your milestone achievements with customizable cards
- **Dark Mode**: Beautiful dark-themed UI that's easy on the eyes
- **Pro Features**: Analytics, unlimited challenges, and more with a subscription

## 🏗️ Project Structure

```
100DaysRebuild/
├── App/
│   └── App.swift               # Main app entry point with AppDelegate
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift        # Color palette and theme
│   │   ├── Typography.swift    # Typography system
│   │   ├── ButtonStyles.swift  # Reusable button styles
│   │   ├── ThemeManager.swift  # Theme management
│   │   ├── AppSpacing.swift    # Spacing constants
│   │   ├── Components.swift    # Reusable UI components
│   │   ├── StatCard.swift      # Statistics cards
│   │   └── ProgressComponents.swift # Progress UI components
│   ├── UI/                     # Common UI components
│   ├── Navigation/             # Navigation helpers
│   ├── Extensions/             # Swift extensions
│   └── Utils/                  # Utility functions
├── Features/
│   ├── Auth/                   # Authentication
│   ├── Challenges/             # Challenge management
│   ├── CheckIn/                # Daily check-in functionality
│   ├── Progress/               # Progress tracking and visualization
│   ├── Profile/                # User profile
│   ├── Reminders/              # Notification settings
│   ├── Settings/               # App settings
│   ├── Social/                 # Social sharing features
│   ├── Subscription/           # Pro subscription features
│   └── TimerSession/           # Timer functionality
├── Models/                     # Data models
├── Services/
│   ├── FirebaseService.swift   # Firebase integration
│   ├── NotificationService.swift # Local notifications
│   ├── AuthService.swift       # Authentication service
│   ├── SubscriptionService.swift # RevenueCat integration
│   ├── ChallengeService.swift  # Challenge data management
│   ├── CheckInService.swift    # Check-in functionality
│   ├── UserSession.swift       # User state management
│   ├── ProgressService.swift   # Progress calculations
│   └── NetworkMonitor.swift    # Network connectivity monitoring
├── Resources/                  # Assets and resources
├── Configuration/              # App configuration
└── SupportingFiles/
    ├── Info.plist              # App configuration
    └── GoogleService-Info.plist # Firebase config
```

## 🛠️ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/KhamariThompson/100Rebuild.git
cd 100DaysRebuild
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
4. Place `GoogleService-Info.plist` in the `100DaysRebuild` directory
5. Enable Authentication and Firestore in Firebase Console

### 4. RevenueCat Setup

1. Create a RevenueCat account
2. Set up your product and entitlement in the RevenueCat dashboard
3. Ensure your "pro" entitlement is properly configured
4. Update the API key in SubscriptionService.swift if needed

### 5. Build and Run

1. Open `100DaysRebuild.xcworkspace` (not .xcodeproj)
2. Select your development team in Xcode
3. Choose a simulator or device
4. Build and run (⌘R)

## 🎨 Design System

The app uses a comprehensive, modern design system:

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
- Consistent spacing using AppSpacing constants
- Animated transitions
- Standardized button styles

## 🔧 Configuration

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

## Technical Improvements

### Authentication System Rebuild

The authentication system has been completely redesigned to provide a more reliable authentication experience:

- Consolidated authentication methods in AuthService class
- Implemented proper error handling and network awareness
- Created non-throwing wrappers for all auth operations
- Fixed Apple Sign-In issues with proper authentication flow

### Check-In Functionality Improvements

- Implemented robust check-in validation
- Fixed navigation conflicts between check-in and edit flows
- Added proper streak counting and statistics updates
- Enhanced data persistence with Firestore

### Performance Optimizations

- Reduced Firebase cache size from 100MB to 10MB
- Implemented memory warning handlers
- Optimized animations and UI transitions
- Improved network request handling with timeout management
- Added offline mode support with recovery mechanisms

### UI/UX Enhancements

- Implemented comprehensive design system with consistent typography, colors and spacing
- Fixed navigation bar appearance and constraint issues
- Enhanced keyboard handling
- Added proper loading states throughout the app

## App Store Submission Checklist

Before submitting the app to the App Store, ensure all of these items are ready:

### Required Assets

- [x] App icon in all required sizes (1024x1024 for App Store)
- [x] Screenshots for all supported device sizes
- [x] App preview videos (optional but recommended)

### Metadata

- [x] App name: 100Days
- [x] App description
- [x] Keywords for App Store search
- [x] Privacy policy URL (https://100days.site/privacy)
- [x] Support URL
- [x] Marketing URL (optional)
- [x] Copyright information

### Technical Requirements

- [x] All features are fully functional
- [x] Data is properly saved to Firebase/Firestore
- [x] Challenges are correctly filtered (showing active, hiding archived)
- [x] Progress view shows correct challenge statistics
- [x] Fixed duplicate navigation headers throughout the app
- [x] Ensured proper data persistence when offline
- [x] Fixed all constraint issues in SFAuthenticationViewController
- [x] Optimized memory usage for large challenge lists

### Compliance

- [x] Privacy policy implemented and accessible in the app
- [x] Terms of Service implemented and accessible in the app
- [x] App complies with Apple's App Review Guidelines
- [x] Ensured no hardcoded API credentials in the app
- [x] Subscription products configured in App Store Connect
- [x] In-app purchases tested and working

### Final Testing

- [x] Tested on multiple iOS versions
- [x] Verified proper functionality on slow network connections
- [x] Checked compatibility with different device sizes
- [x] Ensured dark mode support works correctly
- [x] Verified all animations run smoothly

## Memory and Performance Optimizations

The app has undergone significant memory and performance optimizations to resolve freezing issues:

1. **Tab Navigation System**: Simplified tab navigation with optimized animations
2. **Memory Management**: Added proper cleanup for timers and background tasks
3. **Animation Improvements**: Reduced expensive animations and simplified transitions
4. **Cache Management**: Added memory warning handlers to clear caches when system memory is low
5. **Network Requests**: Improved timeout handling and error recovery

If you encounter frozen UI:

- Force quit the app from the app switcher
- Restart the app
- If problems persist, try restarting your device

These optimizations significantly improve stability while maintaining the app's responsiveness and visual polish.

## Running social feature tests locally

This project uses Firestore for social features (friend requests, friend lists). To run tests that interact with Firestore locally, use the Firebase Emulator Suite.

1. Install Firebase CLI:

   npm install -g firebase-tools

2. Start the emulator in the repo root:

   firebase emulators:start --only firestore

3. In Xcode or your test runner, point your Firestore initialization to the emulator host (typically localhost:8080) using the Firebase SDK emulator setup.

4. Run the unit/integration tests in Xcode or via `xcodebuild`.

Note: Some test scaffolding is added in `Tests/FriendServiceTests` as placeholders — replace with proper emulator-backed tests in CI.
