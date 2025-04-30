# 100Days

A professional-grade iOS app for tracking and completing 100-day challenges, built with SwiftUI and following MVVM + Feature-based architecture. This app helps users build habits and track their progress through 100-day challenges with features like streak tracking, progress visualization, and smart reminders.

## 🚀 Prerequisites

Before you begin, ensure you have the following installed:

- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later
- CocoaPods (for Firebase dependencies)
- A Firebase account (for backend services)

## 📱 Features

### Core Features

- **Authentication**

  - Email/password login
  - Secure password reset
  - Session management
  - Profile customization

- **Challenges**

  - Create and manage 100-day challenges
  - Daily check-in system
  - Streak tracking and protection
  - Challenge archiving and completion tracking

- **Progress Tracking**

  - Visual progress indicators
  - Streak statistics
  - Completion percentage
  - Historical data visualization

- **Smart Reminders**
  - Customizable reminder times
  - Streak protection notifications
  - Pro-only reminder customization
  - Local notification support

### Pro Features

- Advanced analytics and charts
- Custom reminder times
- Detailed challenge breakdowns
- Historical data visualization
- Streak calendar view

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

Create a `Configuration/Environment.xcconfig` file with:

```xcconfig
// Firebase
FIREBASE_API_KEY = your_api_key
FIREBASE_PROJECT_ID = your_project_id

// RevenueCat
REVENUECAT_API_KEY = your_api_key
```

### Build Settings

- Deployment Target: iOS 17.0
- Swift Version: 5.9
- Enable Dark Mode
- Enable Localization

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
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
