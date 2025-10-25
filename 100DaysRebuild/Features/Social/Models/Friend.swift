import Foundation

// Canonical Friend model used by Social features.
// Includes common fields used across views and view models: `username`, `displayName`, and `photoURL`.
// Backwards-compatible initializer that accepts `name` is preserved.
struct Friend: Identifiable {
    let id: String

    // Primary identity fields
    let username: String
    let displayName: String?

    // Legacy / convenience name field (kept for compatibility)
    let name: String

    // Activity metadata
    let streak: Int
    let lastActive: Date

    // Image URL (canonical)
    let profileImageURL: URL?

    // Alias used elsewhere in the codebase
    var photoURL: URL? { profileImageURL }

    // Backwards-compatible initializer (original form that accepted `name`)
    init(id: String = UUID().uuidString,
         name: String,
         streak: Int = 0,
         lastActive: Date = Date(),
         profileImageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.username = name.replacingOccurrences(of: " ", with: "_").lowercased()
        self.displayName = nil
        self.streak = streak
        self.lastActive = lastActive
        self.profileImageURL = profileImageURL
    }

    // Preferred initializer when username/displayName are known
    init(id: String = UUID().uuidString,
         username: String,
         displayName: String? = nil,
         streak: Int = 0,
         lastActive: Date = Date(),
         profileImageURL: URL? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.name = displayName ?? username
        self.streak = streak
        self.lastActive = lastActive
        self.profileImageURL = profileImageURL
    }
}
