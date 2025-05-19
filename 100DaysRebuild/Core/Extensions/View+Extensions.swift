import SwiftUI

extension View {
    /// Applies an overlay only if the condition is true
    @ViewBuilder func conditionalOverlay<OverlayContent: View>(
        _ condition: Bool,
        @ViewBuilder content: () -> OverlayContent
    ) -> some View {
        if condition {
            self.overlay(content())
        } else {
            self
        }
    }
    
    /// Applies a modifier only if the condition is true
    @ViewBuilder func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 