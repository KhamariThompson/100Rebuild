import SwiftUI

extension PreviewProvider {
    static var dev: DeveloperPreview {
        return DeveloperPreview.instance
    }
}

@MainActor
class DeveloperPreview {
    static let instance = DeveloperPreview()
    
    let subscriptionService: SubscriptionService
    let userSession: UserSession
    
    private init() {
        self.subscriptionService = SubscriptionService.shared
        self.userSession = UserSession.shared
    }
    
    func previewView<Content: View>(_ content: Content) -> some View {
        content
            .environmentObject(subscriptionService)
            .environmentObject(userSession)
    }
} 