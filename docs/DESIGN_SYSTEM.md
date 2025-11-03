# 100Days Design System

This document outlines the design system for the 100Days iOS app, which has been updated to match the clean, minimal aesthetic of the [100days.site](https://100days.site) landing page.

## Core Design Principles

1. **Clean and Minimal**: Focus on simplicity, white space, and clear hierarchy
2. **Neutral Color Palette**: Black, white, and grays with subtle gradients
3. **Consistent Typography**: Clear hierarchical type system with modern fonts
4. **Subtle Shadows**: Elegant elevation with minimal shadows
5. **Purposeful Spacing**: Consistent spacing throughout the app

## Key Design Components

### Colors

The color palette has been completely overhauled to match the landing page aesthetic:

- Removed blue accents and replaced with neutral tones
- Implemented a grayscale palette for the primary UI elements
- Maintained clear contrast between elements
- Enhanced dark mode with appropriate color inversions

### Typography

Typography follows a clean, modern approach:

- Bold, large titles (28-40pt)
- Medium weights for section headers (22pt)
- Regular weights for body text (16pt)
- Subtle letter spacing adjustments for improved readability
- Consistent line heights for proper text flow

### Shadows

Shadow system has been refined to be more subtle and elegant:

- Card shadows are lighter and more diffused
- Appropriate elevation hierarchy through shadow intensity
- Reduced opacity for a more subtle effect
- Larger blur radius for a softer feel

### Spacing

A comprehensive spacing system ensures consistency:

- Standard screen padding (16pt)
- Consistent item spacing in lists (16pt)
- Hierarchical spacing scale (4, 8, 16, 24, 32, 48pt)
- Proper vertical rhythm throughout the interface

### Button Styles

Button styles have been updated to match the landing page:

- Clean, minimal appearance
- Subtle shadows and border overlays
- Responsive press states with scale animations
- Consistent corner radius (12pt)
- Clear visual hierarchy between primary and secondary actions

### Cards and Containers

Cards and container elements follow the minimal aesthetic:

- Clean backgrounds with subtle borders
- Consistent corner radius (12pt)
- Minimal shadows for elevation
- Proper internal padding (16pt)
- Clear visual separation from background

## Implementation Notes

The design system is organized into several key Swift files:

- `Colors.swift`: Defines the color palette and theme
- `Typography.swift`: Defines text styles and modifiers
- `ShadowModifiers.swift`: Defines elevation through shadows
- `ButtonStyles.swift`: Defines button appearance and behavior
- `CalAIDesignTokens.swift`: Defines core design values and spacing
- `StatCard.swift`: Example components using the design system

## Usage Guidelines

1. Always use the predefined colors, spacing, and typography from the design system
2. Maintain consistent elevation hierarchy with shadows
3. Use the appropriate button style based on action importance
4. Follow spacing guidelines for layout
5. Test all UI in both light and dark mode

By following these guidelines, the app maintains a cohesive look and feel that aligns with the 100days.site landing page aesthetic.
