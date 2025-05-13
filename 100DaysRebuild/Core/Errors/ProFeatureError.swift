import Foundation

/// Error type for Pro feature-related errors
public enum ProFeatureError: Error, LocalizedError {
    case subscriptionRequired
    
    public var errorDescription: String? {
        switch self {
        case .subscriptionRequired:
            return "This feature requires a Pro subscription"
        }
    }
} 