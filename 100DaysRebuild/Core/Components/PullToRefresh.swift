import SwiftUI

struct PullToRefresh: View {
    @Binding var isRefreshing: Bool
    let action: () -> Void
    
    // Track whether pull threshold has been exceeded
    @State private var pullDistance: CGFloat = 0
    @State private var shouldRefresh: Bool = false
    
    // Pull threshold to trigger refresh
    private let pullThreshold: CGFloat = 80
    
    var body: some View {
        GeometryReader { geo in
            if geo.frame(in: .global).minY > 0 {
                HStack {
                    Spacer()
                    
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.down")
                            .font(AppTypography.body(.semibold))
                            .foregroundColor(.theme.accent)
                            .opacity(min(geo.frame(in: .global).minY / pullThreshold, 1.0))
                            .rotationEffect(.degrees(min((geo.frame(in: .global).minY / 20.0) * 180.0, 180.0)))
                    }
                    
                    Spacer()
                }
                .offset(y: -min(geo.frame(in: .global).minY / 2, 40))
                .onChange(of: geo.frame(in: .global).minY) { newValue in
                    // Store the current pull distance
                    pullDistance = newValue
                    
                    // Check if we've exceeded the threshold and should trigger a refresh
                    if pullDistance > pullThreshold && !shouldRefresh && !isRefreshing {
                        shouldRefresh = true
                        
                        // Start refresh
                        withAnimation {
                            isRefreshing = true
                        }
                        
                        // Trigger the refresh action
                        action()
                    } else if pullDistance < 10 && shouldRefresh {
                        // Reset once user has released and view has returned to normal position
                        shouldRefresh = false
                    }
                }
            }
        }
        .frame(height: 40)
    }
}

#Preview {
    PullToRefresh(isRefreshing: .constant(false)) {
        print("Refreshing...")
    }
} 
