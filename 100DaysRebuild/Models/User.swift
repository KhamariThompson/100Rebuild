import Foundation
import FirebaseAuth

struct User: Identifiable {
    let id: String
    let uid: String
    let email: String
    let displayName: String?
    let photoURL: URL?
    
    init(id: String = UUID().uuidString,
         uid: String,
         email: String,
         displayName: String? = nil,
         photoURL: URL? = nil) {
        self.id = id
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
    }
    
    init(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.uid = firebaseUser.uid
        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName
        self.photoURL = firebaseUser.photoURL
    }
} 