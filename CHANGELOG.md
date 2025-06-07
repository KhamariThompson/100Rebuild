# Changelog

All notable changes to the 100Days app will be documented in this file.

## [1.0.5] - 2024-05-20

### Fixed

- Fixed subscription migration for users transitioning from anonymous to identified accounts
- Enhanced user identification with RevenueCat to prevent subscription loss
- Updated deprecated RevenueCat API calls for better StoreKit 2 compatibility
- Fixed compilation errors in social features
- Improved error handling in subscription-related views
- Fixed significant delay in SimpleCheckInSheet presentation by replacing SwiftUI sheets with direct overlay modals
- Optimized SimpleCheckInSheet performance and prewarming to ensure instant appearance
- Improved ConsistencyHeatmap visibility by simplifying to white/gray cells for better readability
- Fixed inconsistent completion percentage display in ProgressView to match global stats
- Enhanced challenge selector UI in MainTabView with a more modern and sleek design
- Added keyboard dismissal controls to SimpleCheckInSheet for better user experience
- Added X icon to SimpleCheckInSheet for easy modal dismissal

## [1.0.4] - 2024-05-17

### Fixed

- Fixed subscription validation issues where Pro status wasn't being properly recognized
- Fixed "Restore Purchases" functionality to correctly restore subscription access
- Corrected RevenueCat entitlement casing from "pro" to "Pro" for proper validation
- Improved subscription flow to ensure proper user identification with RevenueCat
- Enhanced error handling and logging for subscription-related issues

## [1.0.3] - 2024-05-15

### Added

- Added enhanced analytics for user engagement
- Implemented improved check-in reminders

### Fixed

- Fixed UI layout issues on smaller devices
- Addressed authentication edge cases
- Improved network reliability for offline use

## [1.0.2] - 2024-05-01

### Added

- Added support for multiple simultaneous challenges
- Implemented social sharing for milestones

### Fixed

- Fixed dark mode color inconsistencies
- Improved notification reliability

## [1.0.1] - 2024-04-15

### Fixed

- Addressed initial launch performance issues
- Fixed user authentication edge cases
- Improved overall app stability

## [1.0.0] - 2024-04-01

### Added

- Initial release of 100Days app
- Challenge tracking functionality
- Daily check-ins with streaks
- Progress visualization
- Basic analytics
- Pro subscription features
