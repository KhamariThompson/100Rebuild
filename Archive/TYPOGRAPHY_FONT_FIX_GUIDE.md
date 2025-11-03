# Typography & Button Contrast Fix Guide

## Problem Identified

**58 files** with white color usage (potential contrast issues)
**580+ occurrences** of custom `.font(.system(size:...))` declarations
**Result:** Inconsistent typography and button contrast failures in light/dark mode

---

## Solution: Centralized Design System

### ✅ Created: `AdaptiveColors.swift`

Provides adaptive color helpers that automatically work in light/dark mode:

```swift
// For button text on accent backgrounds
DS.Colors.primaryButtonFg(colorScheme) // Returns black in light, white in dark

// For text on colored gradients
DS.Colors.textOnColoredBg // Always white (safe for most colored backgrounds)

// View modifiers
Text("Button")
    .adaptiveButtonText(colorScheme) // Auto-adapts
```

---

## Typography Hierarchy (USE THESE ONLY)

### Display Sizes (Headlines, Titles):
```swift
DS.Typo.titleXL      // 32pt bold  - Page titles, hero text
DS.Typo.titleL       // 28pt semibold - Section titles
DS.Typo.title2       // 22pt semibold - Card titles
DS.Typo.title3       // 20pt semibold - Subheadings
```

### Body Sizes (Primary Content):
```swift
DS.Typo.headline     // 17pt semibold - List headers, emphasis
DS.Typo.body         // 16pt regular - Body text, descriptions
DS.Typo.bodyMedium   // 16pt medium - Medium emphasis body
DS.Typo.callout      // 15pt regular - Secondary body text
```

### Small Sizes (Labels, Captions):
```swift
DS.Typo.subhead      // 14pt regular - Subtitles, secondary info
DS.Typo.footnote     // 13pt regular - Footnotes, disclaimers
DS.Typo.caption1     // 12pt regular - Captions, timestamps
DS.Typo.caption2     // 11pt regular - Smallest text
DS.Typo.overline     // 12pt semibold - Labels, tags
```

---

## Button Color Guidelines

### ❌ NEVER DO THIS:
```swift
// White text on white background (light mode fail)
Button("Action") {
    ...
}
.foregroundColor(.white)
.background(Color.white)

// Black text on black background (dark mode fail)
Text("Button")
    .foregroundColor(.black)
    .background(Color.theme.surface) // May be dark in dark mode
```

### ✅ ALWAYS DO THIS:

#### Primary Buttons (Accent Background):
```swift
@Environment(\.colorScheme) var colorScheme

Button("Get Started") {
    ...
}
.font(DS.Typo.headline)
.foregroundStyle(DS.Colors.primaryButtonFg(colorScheme)) // Auto-adapts
.background(DS.Colors.accent)
```

#### Secondary Buttons (Surface Background):
```swift
Button("Cancel") {
    ...
}
.font(DS.Typo.body)
.foregroundStyle(DS.Colors.secondaryButtonFg) // Uses theme text color
.background(DS.Colors.surface)
```

#### Ghost/Tertiary Buttons:
```swift
Button("Learn More") {
    ...
}
.font(DS.Typo.body)
.foregroundStyle(DS.Colors.tertiaryButtonFg) // Accent color
```

#### Destructive Buttons:
```swift
Button("Delete") {
    ...
}
.font(DS.Typo.body)
.foregroundStyle(DS.Colors.destructiveButtonFg) // Error red
```

---

## Font Replacement Strategy

### Replace ALL occurrences of:

#### ❌ Old (Inconsistent):
```swift
.font(.system(size: 28, weight: .bold, design: .rounded))
.font(.system(size: 18, weight: .semibold))
.font(Font.system(size: 16))
```

#### ✅ New (Consistent):
```swift
.font(DS.Typo.titleL)      // 28pt semibold
.font(DS.Typo.headline)    // 17pt semibold (closest to 18pt)
.font(DS.Typo.body)        // 16pt regular
```

---

## Mapping Guide

| Old Size | Old Weight | New DS.Typo |
|----------|-----------|-------------|
| 32pt+ | Bold/Black | `titleXL` |
| 28-30pt | Semibold/Bold | `titleL` |
| 22-24pt | Semibold | `title2` |
| 20-21pt | Semibold | `title3` |
| 17-18pt | Semibold/Bold | `headline` |
| 16-17pt | Regular | `body` |
| 16-17pt | Medium | `bodyMedium` |
| 15pt | Regular | `callout` |
| 14pt | Regular | `subhead` |
| 13pt | Regular | `footnote` |
| 12pt | Regular | `caption1` |
| 12pt | Semibold | `overline` |
| 11pt | Regular | `caption2` |

---

## Critical Files to Fix

### High Priority (User-Facing):
1. **WelcomeView.swift** - Already enhanced, verify button colors
2. **AuthView.swift** - Login/signup buttons
3. **PaywallView.swift** - Purchase buttons
4. **CommitNowView.swift** - Already enhanced, verify
5. **ImprovedFunnelView.swift** - Funnel CTAs
6. **ChallengesView.swift** - Home view consistency

### Medium Priority (Core UI):
7. **SettingsView.swift** - Settings buttons
8. **ProfileView.swift** - Profile actions
9. **SocialView.swift** - Social buttons
10. **CheckInView.swift** - Check-in actions

### Low Priority (Supporting):
- Badge views
- Modal sheets
- Celebration views
- Helper components

---

## Implementation Steps

### Step 1: Add Environment Variable
In every view with buttons:
```swift
@Environment(\.colorScheme) var colorScheme
```

### Step 2: Update Button Text Colors
Replace:
```swift
.foregroundColor(.white)
.foregroundStyle(.white)
```

With:
```swift
.foregroundStyle(DS.Colors.primaryButtonFg(colorScheme))
// OR
.adaptiveButtonText(colorScheme)
```

### Step 3: Update All Fonts
Replace:
```swift
.font(.system(size: X, weight: Y, design: Z))
```

With appropriate:
```swift
.font(DS.Typo.{style})
```

### Step 4: Verify in Both Modes
- Test each screen in light mode
- Test each screen in dark mode
- Verify all text is readable

---

## Automated Find & Replace

### VS Code/Xcode Regex Replace:

#### Replace Custom Fonts:
```regex
Find: \.font\(\.system\(size: (\d+)
Replace: .font(DS.Typo.body  // MANUAL: Choose appropriate DS.Typo style
```

#### Replace .white on Buttons:
```regex
Find: \.foregroundColor\(\.white\)
Replace: .foregroundStyle(DS.Colors.primaryButtonFg(colorScheme))
```

#### Replace .foregroundStyle(.white):
```regex
Find: \.foregroundStyle\(\.white\)
Replace: .foregroundStyle(DS.Colors.primaryButtonFg(colorScheme))
```

---

## Testing Checklist

### Light Mode:
- [ ] Primary buttons: Black text on accent background
- [ ] Secondary buttons: Dark text on light surface
- [ ] Ghost buttons: Accent-colored text
- [ ] All body text uses consistent sizes
- [ ] Headings follow hierarchy (XL > L > 2 > 3)

### Dark Mode:
- [ ] Primary buttons: White text on accent background
- [ ] Secondary buttons: Light text on dark surface
- [ ] Ghost buttons: Accent-colored text (bright)
- [ ] All body text readable on dark backgrounds
- [ ] No white-on-white or black-on-black anywhere

---

## Professional Polish Standards

### Typography Rules:
1. **Maximum 5 font sizes per screen** - Use DS.Typo hierarchy
2. **Consistent design: .rounded** - Already in DS.Typo
3. **Line spacing: 2-4pts** for readability
4. **Letter spacing: Default** (no custom tracking)

### Color Rules:
1. **Minimum contrast: 4.5:1** for body text (WCAG AA)
2. **Minimum contrast: 3:1** for large text (WCAG AA)
3. **Never hardcode .white or .black** - Use adaptive colors
4. **Test in both modes** before committing

### Button Rules:
1. **Minimum height: 44pt** (Apple HIG)
2. **Minimum padding: 16pt horizontal**
3. **Clear visual hierarchy** (Primary > Secondary > Tertiary)
4. **Consistent corner radius: 12-16pt**

---

## Quick Reference Card

```swift
// BUTTONS
@Environment(\.colorScheme) var colorScheme

// Primary
.font(DS.Typo.headline)
.foregroundStyle(DS.Colors.primaryButtonFg(colorScheme))
.background(DS.Colors.accent)

// Secondary
.font(DS.Typo.body)
.foregroundStyle(DS.Colors.onSurface)
.background(DS.Colors.surface)

// Ghost
.font(DS.Typo.body)
.foregroundStyle(DS.Colors.accent)

// TYPOGRAPHY
Hero: DS.Typo.titleXL (32pt)
Section: DS.Typo.titleL (28pt)
Card Title: DS.Typo.title2 (22pt)
Subheading: DS.Typo.title3 (20pt)
Emphasis: DS.Typo.headline (17pt)
Body: DS.Typo.body (16pt)
Secondary: DS.Typo.callout (15pt)
Label: DS.Typo.subhead (14pt)
Caption: DS.Typo.caption1 (12pt)
```

---

**Status:** Guide created - Ready for implementation
**Files to modify:** 58+ files with button issues
**Fonts to standardize:** 580+ occurrences
**Estimated time:** 2-3 hours for complete fix
**Priority:** HIGH - Affects user experience significantly

