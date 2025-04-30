import SwiftUI

struct SocialView: View {
    @State private var isAnimating = false
    @State private var showingShareSheet = false
    
    private let features = [
        ("person.2.fill", "Add and follow friends"),
        ("eye.fill", "See what your friends are working on"),
        ("flag.2.crossed.fill", "Join group challenges"),
        ("sparkles", "Celebrate milestones together")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.theme.accent)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    
                    Text("Social Accountability is Coming to 100Days")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.theme.text)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                    
                    Text("Connect with friends, join group challenges, and celebrate your progress together.")
                        .font(.body)
                        .foregroundColor(.theme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                }
                .padding(.top, 32)
                
                // Feature Preview
                VStack(spacing: 16) {
                    ForEach(features, id: \.1) { icon, text in
                        HStack(spacing: 16) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(.theme.accent)
                                .frame(width: 40)
                            
                            Text(text)
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.theme.accent)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                    }
                }
                .padding(.horizontal)
                
                // Invite Friends Button
                Button(action: { showingShareSheet = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Invite Friends Early")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                            .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.horizontal)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
            }
        }
        .background(Color.theme.background.ignoresSafeArea())
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: ["Join me on 100Days - the best way to build habits and achieve your goals! https://100days.app"])
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 