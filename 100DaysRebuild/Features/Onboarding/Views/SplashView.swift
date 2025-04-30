import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.theme.accent)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("100Days")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.theme.text)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
} 