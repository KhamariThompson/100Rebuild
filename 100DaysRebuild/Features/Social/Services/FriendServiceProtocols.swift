import Foundation

// Protocols to allow testing and DI for FriendService in the future.
protocol FriendServiceProtocol: AnyObject {
    var friends: [Friend] { get }
    var incomingRequests: [FriendRequest] { get }
    var outgoingRequests: [FriendRequest] { get }

    func startListening()
    func stopListening()

    func searchUsers(query: String) async throws -> [UserProfileResult]
    func sendFriendRequest(to username: String) async throws
    func acceptFriendRequest(_ requestId: String) async throws
    func rejectFriendRequest(_ requestId: String) async throws
}
