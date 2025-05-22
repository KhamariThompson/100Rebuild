# Core Design System

This directory contains the core design system components for the 100DaysRebuild application.

## Structure

- **DesignSystem/**: Contains all design tokens and components
  - `Colors.swift`: Color definitions and theme
  - `Typography.swift`: Text styles and font definitions
  - `Buttons.swift`: Button styles and modifiers
  - `Components.swift`: Reusable UI components

## Usage

### Colors

Access colors through the `AppColors` namespace or the `.theme` extension:

```swift
Text("Hello")
    .foregroundColor(.theme.primary)

// Or directly:
Text("Hello")
    .foregroundColor(AppColors.primary)
```

### Typography

Use the typography styles either through the enum or the convenience modifiers:

```swift
// Using the enum:
Text("Title")
    .font(AppTypography.title)

// Using modifiers:
Text("Title")
    .title()
```

### Buttons

Apply button styles to any button:

```swift
Button("Primary Action") {
    // action
}
.buttonStyle(.primary)

Button("Secondary Action") {
    // action
}
.buttonStyle(.secondary)
```

### Components

Use the components to maintain consistent UI:

```swift
AppComponents.Card {
    VStack {
        Text("Card Title")
        Text("Card content goes here")
    }
}

AppComponents.Badge(text: "New", color: .theme.accent)
```

## Extending the Design System

When adding new components:

1. Place them in the appropriate file based on their type
2. Add public access modifiers to ensure they're accessible
3. Add documentation comments to explain usage
4. Follow existing naming conventions

## Troubleshooting

If you encounter duplicate symbol errors:

- Make sure each component has proper access modifiers
- Don't create global instances of types in header files
- Use the `-ld_classic` linker flag for Xcode 15+ projects
