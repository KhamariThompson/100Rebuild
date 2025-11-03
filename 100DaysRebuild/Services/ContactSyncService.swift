import Foundation
import Contacts
import CryptoKit
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ContactSyncService: ObservableObject {
    static let shared = ContactSyncService()
    
    @Published var hasContactsPermission = false
    @Published var isProcessingContacts = false
    @Published var suggestedFriends: [UserSuggestion] = []
    @Published var errorMessage: String?
    
    nonisolated(unsafe) private let contactStore = CNContactStore()
    nonisolated(unsafe) private let firestore = Firestore.firestore()
    
    private init() {
        checkContactsPermission()
    }
    
    // MARK: - Permission Management
    
    nonisolated func requestContactsPermission() async throws {
        let status = try await Task.detached {
            let store = CNContactStore()
            return try await store.requestAccess(for: .contacts)
        }.value

        await MainActor.run {
            hasContactsPermission = status
        }

        if status {
            await processContacts()
        }
    }
    
    private func checkContactsPermission() {
        hasContactsPermission = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    // MARK: - Contact Processing

    private func processContacts() async {
        guard hasContactsPermission else { return }

        isProcessingContacts = true
        defer { isProcessingContacts = false }

        do {
            let hashedIdentifiers = try await fetchAndHashContacts()
            await findMatchingUsers(hashedIdentifiers: hashedIdentifiers)
        } catch {
            errorMessage = "Failed to process contacts: \(error.localizedDescription)"
        }
    }

    nonisolated private func fetchAndHashContacts() async throws -> Set<String> {
        return try await Task.detached {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]

            let request = CNContactFetchRequest(keysToFetch: keys)
            let store = CNContactStore()

            var hashedIdentifiers = Set<String>()

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        // Hash phone numbers
                        for phoneNumber in contact.phoneNumbers {
                            let cleanedNumber = phoneNumber.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                            if !cleanedNumber.isEmpty {
                                let hashedNumber = SHA256.hash(data: Data(cleanedNumber.utf8))
                                    .compactMap { String(format: "%02x", $0) }.joined()
                                hashedIdentifiers.insert(hashedNumber)
                            }
                        }

                        // Hash email addresses
                        for email in contact.emailAddresses {
                            let emailString = email.value as String
                            let hashedEmail = SHA256.hash(data: Data(emailString.lowercased().utf8))
                                .compactMap { String(format: "%02x", $0) }.joined()
                            hashedIdentifiers.insert(hashedEmail)
                        }
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            return hashedIdentifiers
        }.value
    }
    
    private func hashString(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func findMatchingUsers(hashedIdentifiers: Set<String>) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Query users who have opted into contact discovery
            let usersSnapshot = try await firestore
                .collection("users")
                .whereField("allowContactDiscovery", isEqualTo: true)
                .whereField("hashedContactInfo", arrayContainsAny: Array(hashedIdentifiers))
                .getDocuments()
            
            let matchingUsers = usersSnapshot.documents.compactMap { doc -> UserSuggestion? in
                let data = doc.data()
                guard let username = data["username"] as? String,
                      doc.documentID != currentUserId else { return nil }
                
                return UserSuggestion(
                    id: doc.documentID,
                    username: username,
                    displayName: data["displayName"] as? String,
                    photoURL: data["photoURL"] as? String != nil ? URL(string: data["photoURL"] as! String) : nil,
                    suggestionType: .contactMatch,
                    mutualFriends: 0
                )
            }
            
            suggestedFriends.append(contentsOf: matchingUsers)
        } catch {
            errorMessage = "Failed to find matching users: \(error.localizedDescription)"
        }
    }
}

// MARK: - Models
struct UserSuggestion: Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let photoURL: URL?
    let suggestionType: SuggestionType
    let mutualFriends: Int
    
    enum SuggestionType {
        case contactMatch
        case mutualFriend
        case similarChallenge
        case recentlyActive
    }
} 