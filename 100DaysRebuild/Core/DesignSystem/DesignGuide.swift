import SwiftUI

/// Design System Documentation
///
/// This file serves as a reference guide for the 100Days app design system.
/// It contains documentation on spacing, typography, colors, and components.
///
enum DesignGuide {
    
    // MARK: - Overview
    
    /// # 100Days Design System
    ///
    /// The 100Days design system provides a set of consistent styling rules and components
    /// for building a cohesive user experience. This guide outlines the core elements of the
    /// design system and how to use them.
    ///
    /// ## Key Principles
    ///
    /// 1. **Consistency**: Use defined spacing, typography, and color values rather than hardcoded numbers
    /// 2. **Adaptability**: All components should work with both light and dark modes
    /// 3. **Reusability**: Prefer shared components over one-off implementations
    /// 4. **Accessibility**: Ensure text is readable and touch targets are appropriately sized
    
    // MARK: - Spacing Guide
    
    /// # Spacing System
    ///
    /// The spacing system uses a consistent scale throughout the app with the following values:
    ///
    /// - `xxs`: 4pt - Minimal spacing, used for very tight arrangements
    /// - `xs`: 8pt - Extra small spacing (default for tight spacing)
    /// - `s`: 12pt - Small spacing (common for related items)
    /// - `m`: 16pt - Medium spacing (default general spacing)
    /// - `l`: 24pt - Large spacing (section spacing)
    /// - `xl`: 32pt - Extra large spacing (major section divisions)
    /// - `xxl`: 48pt - Extra extra large spacing (screen-level divisions)
    ///
    /// For component-specific spacing, refer to `AppSpacing` for constants.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// VStack(spacing: AppSpacing.m) {
    ///     Text("Headline")
    ///     Text("Subheadline")
    /// }
    /// .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    /// ```
    
    // MARK: - Typography Guide
    
    /// # Typography System
    ///
    /// The typography system defines a set of text styles for consistent hierarchy:
    ///
    /// ## Text Sizes
    /// - `display`: 42pt - For splash screens or major headlines
    /// - `largeTitle`: 34pt - Main screen titles
    /// - `title1`: 28pt - Primary headings
    /// - `title2`: 22pt - Secondary headings
    /// - `title3`: 20pt - Tertiary headings
    /// - `headline`: 17pt - Emphasized content headers
    /// - `body`: 17pt - Default text size
    /// - `callout`: 16pt - Slightly emphasized text
    /// - `subheadline`: 15pt - Secondary text
    /// - `footnote`: 13pt - Supplementary information
    /// - `caption`: 12pt - Labels and annotations
    /// - `small`: 10pt - Very small text
    ///
    /// ## Font Weights
    /// - `regular`: Normal weight
    /// - `medium`: Slightly emphasized
    /// - `semibold`: Medium emphasis
    /// - `bold`: Strong emphasis
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// Text("Headline")
    ///     .font(AppTypography.headline())
    ///     .foregroundColor(.theme.text)
    ///
    /// // Or using view extension
    /// Text("Headline").headline()
    /// ```
    
    // MARK: - Color Guide
    
    /// # Color System
    ///
    /// The color system provides semantic colors that automatically adapt to light and dark modes.
    /// Always use the theme colors instead of hardcoded Color values.
    ///
    /// ## Primary Colors
    /// - `.theme.accent`: Primary brand color
    /// - `.theme.background`: Main background color
    /// - `.theme.surface`: Surface/card background color
    /// - `.theme.text`: Primary text color
    /// - `.theme.subtext`: Secondary text color
    /// - `.theme.border`: Border color for dividers and outlines
    /// - `.theme.shadow`: Shadow color for elevation effects
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// Text("Important message")
    ///     .foregroundColor(.theme.accent)
    ///     .padding()
    ///     .background(Color.theme.surface)
    /// ```
    
    // MARK: - Components Guide
    
    /// # Component System
    ///
    /// The component system provides reusable UI elements with consistent styling.
    ///
    /// ## Cards
    /// - `AppComponents.Card`: Standard card with shadow and padding
    /// - `AppComponents.GlassCard`: Card with blur effect for overlays
    /// - `AppComponents.GradientCard`: Card with gradient background
    ///
    /// ## Stats
    /// - `StatCard`: Vertical statistic card with title, value and icon
    /// - `HorizontalStatCard`: Horizontal variant for space-constrained layouts
    ///
    /// ## Buttons
    /// - `AppPrimaryButtonStyle`: Main action buttons
    /// - `AppSecondaryButtonStyle`: Secondary/outline buttons
    /// - `AppTextButtonStyle`: Text-only buttons
    /// - `AppScaleButtonStyle`: Scale animation for any button
    ///
    /// ## Progress
    /// - `AppComponents.ProgressBar`: Standard progress bar
    /// - `AppProgressStatCard`: Stats with progress visualization
    ///
    /// ## Modifiers
    /// - `.themeShadow()`: Apply theme-consistent shadow
    /// - `.cardShadow()`: Apply card-specific shadow
    /// - `.conditionalOverlay()`: Apply overlay only if condition is true
    /// - `.applyIf()`: Apply any modifier conditionally
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // Card example
    /// AppComponents.Card {
    ///     VStack(spacing: AppSpacing.m) {
    ///         Text("Card Title").headline()
    ///         Text("Card content").body()
    ///     }
    /// }
    ///
    /// // Button example
    /// Button("Primary Action") { }
    ///     .buttonStyle(AppPrimaryButtonStyle())
    /// ```
    
    // MARK: - Best Practices
    
    /// # Design System Best Practices
    ///
    /// 1. **Use semantic constants**: Instead of `padding(16)`, use `padding(AppSpacing.m)`
    ///
    /// 2. **Respect platform patterns**: Use iOS-native gestures and interaction patterns
    ///
    /// 3. **Maintain hierarchy**: Use typography to establish clear information hierarchy
    ///
    /// 4. **Test in both modes**: Always check how components look in both light and dark mode
    ///
    /// 5. **Consistent spacing**: Use the spacing scale consistently for predictable layouts
    ///
    /// 6. **Use design-system components**: Prefer AppComponents over custom implementations
    ///
    /// 7. **Scale appropriately**: Ensure the UI is usable on all supported device sizes
}

/// Preview provider for visualizing the design system
struct DesignGuidePreview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    // Typography
                    spacingPreview
                        .padding(.bottom, AppSpacing.l)
                    
                    typographyPreview
                        .padding(.bottom, AppSpacing.l)
                    
                    colorPreview
                        .padding(.bottom, AppSpacing.l)
                    
                    componentPreview
                }
                .padding(AppSpacing.m)
            }
            .navigationTitle("Design Guide")
            .background(Color.theme.background)
        }
    }
    
    static var spacingPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Spacing").font(AppTypography.title1()).foregroundColor(.theme.text)
            
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                spacingRow("xxs", AppSpacing.xxs)
                spacingRow("xs", AppSpacing.xs)
                spacingRow("s", AppSpacing.s)
                spacingRow("m", AppSpacing.m)
                spacingRow("l", AppSpacing.l)
                spacingRow("xl", AppSpacing.xl)
                spacingRow("xxl", AppSpacing.xxl)
            }
        }
        .padding(AppSpacing.m)
        .background(Color.theme.surface)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
    
    static func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.body())
                .foregroundColor(.theme.text)
                .frame(width: 50, alignment: .leading)
            
            Text("\(Int(value))pt")
                .font(AppTypography.caption1())
                .foregroundColor(.theme.subtext)
                .frame(width: 50, alignment: .leading)
            
            Rectangle()
                .fill(Color.theme.accent.opacity(0.2))
                .frame(width: value, height: 24)
                .overlay(
                    Rectangle()
                        .stroke(Color.theme.accent, lineWidth: 1)
                )
        }
    }
    
    static var typographyPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Typography").font(AppTypography.title1()).foregroundColor(.theme.text)
            
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("Display").font(AppTypography.display()).foregroundColor(.theme.text)
                Text("Large Title").font(AppTypography.largeTitle()).foregroundColor(.theme.text)
                Text("Title 1").font(AppTypography.title1()).foregroundColor(.theme.text)
                Text("Title 2").font(AppTypography.title2()).foregroundColor(.theme.text)
                Text("Title 3").font(AppTypography.title3()).foregroundColor(.theme.text)
                Text("Headline").font(AppTypography.headline()).foregroundColor(.theme.text)
                Text("Body").font(AppTypography.body()).foregroundColor(.theme.text)
                Text("Body Medium").font(AppTypography.body(.medium)).foregroundColor(.theme.text)
                Text("Callout").font(AppTypography.callout()).foregroundColor(.theme.text)
                Text("Subheadline").font(AppTypography.subhead()).foregroundColor(.theme.text)
                Text("Footnote").font(AppTypography.footnote()).foregroundColor(.theme.text)
                Text("Caption").font(AppTypography.caption1()).foregroundColor(.theme.text)
                Text("Small").font(AppTypography.caption2()).foregroundColor(.theme.text)
            }
        }
        .padding(AppSpacing.m)
        .background(Color.theme.surface)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
    
    static var colorPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Colors").font(AppTypography.title1()).foregroundColor(.theme.text)
            
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                colorRow("accent", Color.theme.accent)
                colorRow("background", Color.theme.background)
                colorRow("surface", Color.theme.surface)
                colorRow("text", Color.theme.text)
                colorRow("subtext", Color.theme.subtext)
                colorRow("border", Color.theme.border)
                colorRow("error", Color.theme.error)
                colorRow("success", Color.theme.success)
            }
        }
        .padding(AppSpacing.m)
        .background(Color.theme.surface)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
    
    static func colorRow(_ name: String, _ color: Color) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.body())
                .foregroundColor(.theme.text)
                .frame(width: 100, alignment: .leading)
            
            Rectangle()
                .fill(color)
                .frame(width: 30, height: 30)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.theme.border, lineWidth: 1)
                )
        }
    }
    
    static var componentPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Components").font(AppTypography.title1()).foregroundColor(.theme.text)
            
            // Cards
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Cards").font(AppTypography.headline()).foregroundColor(.theme.text)
                
                AppComponents.Card {
                    Text("Standard Card")
                        .font(AppTypography.body())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                AppComponents.GlassCard {
                    Text("Glass Card")
                        .font(AppTypography.body())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                AppComponents.GradientCard {
                    Text("Gradient Card")
                        .font(AppTypography.body())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Buttons
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Buttons").font(AppTypography.headline()).foregroundColor(.theme.text)
                
                HStack(spacing: AppSpacing.m) {
                    Button("Primary") { }
                        .buttonStyle(AppPrimaryButtonStyle())
                    
                    Button("Secondary") { }
                        .buttonStyle(AppSecondaryButtonStyle())
                    
                    Button("Text") { }
                        .buttonStyle(AppTextButtonStyle())
                }
            }
            
            // Stats
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Stats").font(AppTypography.headline()).foregroundColor(.theme.text)
                
                HStack(spacing: AppSpacing.m) {
                    StatCard(
                        title: "Days",
                        value: "87",
                        icon: "calendar"
                    )
                    
                    HorizontalStatCard(
                        title: "Streak",
                        value: "12",
                        icon: "flame.fill"
                    )
                }
            }
            
            // Progress
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Progress").font(AppTypography.headline()).foregroundColor(.theme.text)
                
                AppComponents.ProgressBar(value: 0.65)
                    .frame(height: AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.m)
        .background(Color.theme.surface)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
} 