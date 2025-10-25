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
    
    private let contactStore = CNContactStore()
    private let firestore = Firestore.firestore()
    
    private init() {
        checkContactsPermission()
    }
    
    // MARK: - Permission Management
    
    func requestContactsPermission() async throws {
        let status = try await contactStore.requestAccess(for: .contacts)
        hasContactsPermission = status
        
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
            let contacts = try await fetchContacts()
            let hashedIdentifiers = hashContactIdentifiers(contacts)
            await findMatchingUsers(hashedIdentifiers: hashedIdentifiers)
        } catch {
            errorMessage = "Failed to process contacts: \(error.localizedDescription)"
        }
    }
    
    private func fetchContacts() async throws -> [CNContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [CNContact] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try contactStore.enumerateContacts(with: request) { contact, _ in
                    contacts.append(contact)
                }
                continuation.resume(returning: contacts)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func hashContactIdentifiers(_ contacts: [CNContact]) -> Set<String> {
        var hashedIdentifiers = Set<String>()
        
        for contact in contacts {
            // Hash phone numbers
            for phoneNumber in contact.phoneNumbers {
                let cleanedNumber = phoneNumber.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !cleanedNumber.isEmpty {
                    let hashedNumber = hashString(cleanedNumber)
                    hashedIdentifiers.insert(hashedNumber)
                }
            }
            
            // Hash email addresses
            for email in contact.emailAddresses {
                let emailString = email.value as String
                let hashedEmail = hashString(emailString.lowercased())
                hashedIdentifiers.insert(hashedEmail)
            }
        }
        
        return hashedIdentifiers
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