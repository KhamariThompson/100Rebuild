import SwiftUI

/// A reusable header view with a fixed position regardless of scroll position
struct ScrollAwareHeaderView<Content: View>: View {
    // Title text to display in the header
    let title: String
    
    // Binding to track scroll offset from parent (kept for compatibility)
    @Binding var scrollOffset: CGFloat
    
    // Optional subtitle that appears below the title
    var subtitle: String?
    
    // Optional accent color gradient for the title
    var accentGradient: LinearGradient?
    
    // Optional custom content view that appears below the title
    var additionalContent: Content?
    
    // Fixed header height - reduced to match Cal AI
    var headerHeight: CGFloat = 80
    
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
        VStack(alignment: .leading, spacing: 2) {
            // Title with optional gradient
            if let gradient = accentGradient {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(gradient)
            } else {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.theme.text)
            }
            
            // Subtitle if provided
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color.theme.subtext)
            }
            
            // Additional content if provided
            if let additionalContent = additionalContent {
                additionalContent
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.background)
        .zIndex(99) // Ensure header stays on top
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// Custom style for subtitles to avoid font ambiguity
struct SubtitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .regular, design: .rounded))
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
                        .frame(height: CalAIDesignTokens.headerHeight)
                    
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
                        Color.clear.frame(height: 80)
                        
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