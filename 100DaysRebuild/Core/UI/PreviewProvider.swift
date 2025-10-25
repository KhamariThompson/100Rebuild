import SwiftUI

extension PreviewProvider {
    static var dev: DeveloperPreview {
        return DeveloperPreview.instance
    }
}

@MainActor
class DeveloperPreview {
    static let instance = DeveloperPreview()

    let subscriptionStore: SubscriptionStore
    let entitlementsAdapter: EntitlementsAdapter
    let userSession: UserSession

    private init() {
        self.subscriptionStore = SubscriptionStore.shared
        self.entitlementsAdapter = EntitlementsAdapter.shared
        self.userSession = UserSession.shared
    }

    func previewView<Content: View>(_ content: Content) -> some View {
        content
            .environmentObject(subscriptionStore)
            .environmentObject(entitlementsAdapter)
            .environmentObject(userSession)
    }
} 