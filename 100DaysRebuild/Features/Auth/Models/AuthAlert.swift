import Foundation

/// Alert model used for authentication-related alerts throughout the app
public struct AuthAlert: Identifiable {
    public let id = UUID()
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
} 