//  Friend.swift — a confirmed friend and a pending incoming request.
import Foundation

struct Friend: Identifiable, Equatable {
    let friendshipID: UUID
    let profile: UserProfile
    var id: UUID { profile.id }
}

struct FriendRequest: Identifiable, Equatable {
    let id: UUID          // the friendship/request row id
    let profile: UserProfile
    let createdAt: Date
}
