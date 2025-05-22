import SwiftUI
import Foundation

/// Feature-specific progress components for the Progress feature.
/// These components are only used within the Progress feature screens.
/// More generic/reusable progress components are in Core/DesignSystem/ProgressComponents.swift

/// A styled stat card component for ProgressView
struct ProgressFeatureStatCard: View {
    let title: String
    let value: String
    var icon: String? = nil
    
    // For animations
    @State private var animateValue = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Value display with optional icon
            HStack(spacing: AppSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: AppSpacing.iconSizeMedium, weight: .semibold))
                        .foregroundColor(.theme.accent)
                        .opacity(0.8)
                        .frame(width: AppSpacing.iconSizeMedium, height: AppSpacing.iconSizeMedium)
                        .rotationEffect(Angle(degrees: animateValue ? 0 : -10))
                }
                
                Text(value)
                    .font(AppTypography.title2())
                    .foregroundColor(.theme.accent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .scaleEffect(animateValue ? 1.0 : 0.8)
            }
            .frame(maxWidth: .infinity)
            
            // Title text for the card
            Text(title)
                .font(AppTypography.subhead())
                .foregroundColor(.theme.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.buttonVerticalPadding)
        .padding(.horizontal, AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .shadow(color: Color.theme.shadow.opacity(isPressed ? 0.03 : 0.08), 
                       radius: isPressed ? 4 : 6, 
                       x: 0, 
                       y: isPressed ? 1 : 2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(Color.theme.accent.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            // Trigger the animation after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    animateValue = true
                }
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPressed = false
                    }
                }
        )
    }
}

/// A badge card with animation for the progress view
struct ProgressFeatureBadgeCard: View {
    let badge: ProgressBadge
    
    // For animation
    @State private var animateAppear = false
    
    var body: some View {
        VStack(spacing: AppSpacing.s) {
            // Badge icon with animated glow effect
            ZStack {
                // Subtle glow behind the icon
                Circle()
                    .fill(Color.theme.accent.opacity(0.15))
                    .frame(width: animateAppear ? 50 : 40, height: animateAppear ? 50 : 40)
                    .blur(radius: 8)
                
                // Main icon
                Image(systemName: badge.iconName)
                    .font(.system(size: AppSpacing.iconSizeLarge, weight: .semibold))
                    .foregroundColor(.theme.accent)
                    .scaleEffect(animateAppear ? 1.0 : 0.8)
            }
            .padding(.bottom, AppSpacing.xxs)
            
            // Badge title
            Text(badge.title)
                .font(AppTypography.subhead())
                .foregroundColor(.theme.text)
                .multilineTextAlignment(.center)
                .opacity(animateAppear ? 1.0 : 0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, AppSpacing.buttonVerticalPadding)
        .padding(.horizontal, AppSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(Color.theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(Color.theme.accent.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.theme.shadow.opacity(0.07), radius: 6, x: 0, y: 2)
        )
        .onAppear {
            // Animate badge appearance with a slight delay for staggered effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    animateAppear = true
                }
            }
        }
    }
}

/// Loading step indicator for progress view
struct ProgressFeatureLoadingStepIndicator: View {
    let title: String
    let isCompleted: Bool
    var isAnimating: Bool = false
    
    @State private var animationPhase: Double = 0
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.2) : Color.theme.subtext.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else if isAnimating {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(Angle(degrees: animationPhase))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                                animationPhase = 360
                            }
                        }
                } else {
                    Circle()
                        .fill(Color.theme.subtext.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            
            Text(title)
                .font(AppTypography.caption1())
                .foregroundColor(isCompleted ? .green : .theme.subtext)
        }
    }
}

/// Fallback button for loading screens
struct ProgressFeatureFallbackButton: View {
    let isShowing: Bool
    let action: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        Button(action: action) {
            Text("Continue with sample data")
                .font(AppTypography.footnote())
                .fontWeight(.medium)
                .foregroundColor(.theme.accent)
                .padding(.horizontal, AppSpacing.buttonHorizontalPadding)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(Color.theme.accent.opacity(0.1))
                )
        }
        .opacity(isShowing ? 1 : 0)
        .scaleEffect(isShowing ? 1 : 0.8)
        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5), value: isShowing)
        .onAppear {
            // Add a small delay before showing the button
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isVisible = isShowing
                }
            }
        }
    }
}

// MARK: - Backward Compatibility Aliases

/// For backward compatibility with existing code - aliases to the new component names
typealias AppProgressStatCard = ProgressFeatureStatCard
typealias ProgressBadgeCard = ProgressFeatureBadgeCard 
typealias LoadingStepIndicator = ProgressFeatureLoadingStepIndicator
typealias FallbackButton = ProgressFeatureFallbackButton 