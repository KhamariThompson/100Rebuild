import SwiftUI

// Helper view to share items
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 