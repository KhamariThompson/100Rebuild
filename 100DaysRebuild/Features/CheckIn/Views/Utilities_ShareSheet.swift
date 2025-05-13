import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A wrapper around UIActivityViewController for sharing content in SwiftUI
struct CheckIn_ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        
        // Add default caption for social media
        let hashtags = "#100DaysChallenge #BuildBetterHabits @100DaysApp"
        
        if let firstItem = items.first as? UIImage {
            // For image shares, add text suggestion
            UIPasteboard.general.image = firstItem
            UIPasteboard.general.string = hashtags
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// Extension to help with SwiftUI sharing
extension View {
    /// Present a share sheet
    /// - Parameters:
    ///   - items: Items to share (text, URL, image, etc.)
    ///   - isPresented: Binding to control presentation
    func shareSheet(items: [Any], isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            CheckIn_ShareSheet(items: items)
        }
    }
    
    /// Present a share sheet with completed milestone
    /// - Parameters:
    ///   - dayNumber: The milestone day number
    ///   - challengeTitle: Title of the challenge
    ///   - isPresented: Binding to control presentation
    func shareMilestone(
        dayNumber: Int,
        challengeTitle: String,
        isPresented: Binding<Bool>
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            MilestoneShareCardView(
                dayNumber: dayNumber,
                challengeTitle: challengeTitle,
                isPresented: isPresented
            )
        }
    }
} 