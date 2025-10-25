import Foundation
import SwiftUI

// Adapters to convert between different Friend model variants used across the Social feature.

extension Friend {
    /// Initialize the standalone `Friend` model from the nested `SocialViewModel.Friend`.
    /// Maps displayName/username -> name, profileImageUrl -> profileImageURL, leaves streak and lastActive defaulted.
    init(from socialFriend: SocialViewModel.Friend) {
        let name = socialFriend.displayName.isEmpty ? socialFriend.username : socialFriend.displayName
        self.init(
            id: socialFriend.id,
            name: name,
            streak: 0,
            lastActive: Date(),
            profileImageURL: socialFriend.profileImageUrl
        )
    }
}

extension SocialViewModel.Friend {
    /// Initialize the nested `SocialViewModel.Friend` from the standalone `Friend` model.
    /// Uses `name` for both `username` and `displayName` when necessary and maps profileImageURL -> profileImageUrl.
    init(from friendModel: Friend) {
        let username = friendModel.name.replacingOccurrences(of: " ", with: "_").lowercased()
        let displayName = friendModel.name
        self.init(
            id: friendModel.id,
            username: username,
            displayName: displayName,
            profileImageUrl: friendModel.profileImageURL
        )
    }
}
