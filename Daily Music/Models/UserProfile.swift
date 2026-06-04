//
//  UserProfile.swift
//  Daily Music
//
//  A user's public identity: the name + photo other people will see (friend
//  bubbles, lists). Stored as first-class columns on the `profiles` row,
//  separate from the private `settings` JSONB blob.
//

import Foundation

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String?
    var avatarURL: String?
}
