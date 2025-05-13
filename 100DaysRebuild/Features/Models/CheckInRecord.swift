import Foundation

// Model for a check-in record
public struct Models_CheckInRecord: Identifiable, Equatable {
    public let id: String
    public let dayNumber: Int
    public let date: Date
    public var note: String?
    public let quote: Quote?
    public let promptShown: String?
    public var photoURL: URL?
    
    public static func == (lhs: Models_CheckInRecord, rhs: Models_CheckInRecord) -> Bool {
        lhs.id == rhs.id
    }
} 