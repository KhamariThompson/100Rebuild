import SwiftUI

/// A reusable header view that dynamically responds to scroll position
/// with FAANG-level polish including shrinking title, blur, and elevation changes
struct ScrollAwareHeaderView<Content: View>: View {
    // Title text to display in the header
    let title: String
    
    // Binding to track scroll offset from parent
    @Binding var scrollOffset: CGFloat
    
    // Optional subtitle that appears below the title
    var subtitle: String?
    
    // Optional accent color gradient for the title
    var accentGradient: LinearGradient?
    
    // Optional custom content view that appears below the title
    var additionalContent: Content?
    
    // Threshold for when the header should start transforming
    var transformThreshold: CGFloat = 80
    
    // Maximum height of the expanded header
    var maxHeight: CGFloat = 140
    
    // Minimum height of the collapsed header
    var minHeight: CGFloat = 60
    
    // Visual properties that change with scroll offset
    private var titleScale: CGFloat {
        let scale = 1.0 - min(max(0, scrollOffset), transformThreshold) / transformThreshold * 0.3
        return max(0.7, scale)
    }
    
    private var titleOffset: CGFloat {
        return min(0, -scrollOffset * 0.2)
    }
    
    private var headerHeight: CGFloat {
        let shrinkAmount = min(max(0, scrollOffset), transformThreshold) / transformThreshold
        return max(minHeight, maxHeight - (maxHeight - minHeight) * shrinkAmount)
    }
    
    private var backgroundOpacity: CGFloat {
        return min(1, max(0, scrollOffset) / (transformThreshold * 0.7))
    }
    
    private var shadowOpacity: CGFloat {
        return min(0.2, max(0, scrollOffset) / transformThreshold * 0.2)
    }
    
    private var titleOpacity: CGFloat {
        return 1.0 - min(0.3, max(0, scrollOffset) / transformThreshold * 0.3)
    }
    
    // Helper for content fade opacity calculation to avoid ambiguous operator errors
    private var contentFadeOpacity: CGFloat {
        let multiplier: CGFloat = 2
        return max(0, 1 - (backgroundOpacity * multiplier))
    }
    
    init(title: String, 
         scrollOffset: Binding<CGFloat>, 
         subtitle: String? = nil, 
         accentGradient: LinearGradient? = nil,
         @ViewBuilder additionalContent: () -> Content) {
        self.title = title
        self._scrollOffset = scrollOffset
        self.subtitle = subtitle
        self.accentGradient = accentGradient
        self.additionalContent = additionalContent()
    }
    
    // Initializer without additional content
    init(title: String, 
         scrollOffset: Binding<CGFloat>, 
         subtitle: String? = nil,
         accentGradient: LinearGradient? = nil) where Content == EmptyView {
        self.title = title
        self._scrollOffset = scrollOffset
        self.subtitle = subtitle
        self.accentGradient = accentGradient
        self.additionalContent = nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Title with dynamic sizing based on scroll position
            if let gradient = accentGradient {
                Text(title)
                    .font(SwiftUI.Font.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(gradient)
                    .kerning(0.2)
                    .scaleEffect(titleScale, anchor: .bottom)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
            } else {
                Text(title)
                    .font(SwiftUI.Font.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.theme.text)
                    .kerning(0.2)
                    .scaleEffect(titleScale, anchor: .bottom)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
            }
            
            // Subtitle if provided
            if let subtitle = subtitle {
                Text(subtitle)
                    .modifier(SubtitleTextStyle())
                    .foregroundColor(Color.theme.subtext)
                    .opacity(contentFadeOpacity)
                    .padding(.top, -4)
            }
            
            // Additional content if provided
            if let additionalContent = additionalContent {
                additionalContent
                    .opacity(contentFadeOpacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Blurred background that appears when scrolling
            ZStack {
                if backgroundOpacity > 0 {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(backgroundOpacity)
                }
            }
        )
        .shadow(color: Color.black.opacity(shadowOpacity), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// Custom style for subtitles to avoid font ambiguity
struct SubtitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
    }
}

// ScrollOffsetPreferenceKey to track scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Extension to track scroll offset
extension View {
    func trackScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .global).minY
                    )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            offset.wrappedValue = -value
        }
    }
}

// Example wrapper for screen-specific implementations
struct ScreenWithScrollHeader<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    @State private var scrollOffset: CGFloat = 0
    
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Content with scroll tracking
            ScrollView {
                VStack {
                    // Spacer to push content below the header
                    Color.clear
                        .frame(height: 110)
                    
                    // Main content
                    content
                        .padding(.horizontal)
                }
                .trackScrollOffset($scrollOffset)
            }
            
            // Overlay the header on top
            ScrollAwareHeaderView(
                title: title,
                scrollOffset: $scrollOffset,
                subtitle: subtitle
            )
        }
        .edgesIgnoringSafeArea(.top)
    }
}

// Preview for the component
struct ScrollAwareHeaderView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var scrollOffset: CGFloat = 0
        
        var body: some View {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 20) {
                        Color.clear.frame(height: 140)
                        
                        ForEach(0..<20) { i in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.theme.surface)
                                .frame(height: 80)
                                .overlay(Text("Item \(i)"))
                        }
                    }
                    .padding()
                    .trackScrollOffset($scrollOffset)
                }
                
                ScrollAwareHeaderView(
                    title: "Preview Title",
                    scrollOffset: $scrollOffset,
                    subtitle: "Scroll to see the magic"
                )
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
} 