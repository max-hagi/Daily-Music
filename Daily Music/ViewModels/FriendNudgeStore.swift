//
//  FriendNudgeStore.swift
//  Daily Music
//
//  View-facing state for per-friend nudge buttons.
//

import Foundation

enum FriendNudgeState: Equatable, Sendable {
    case idle
    case sending
    case sent
    case noRecipientToken
    case rateLimited(nextAllowedAt: Date?)
    case failed(String)
}

@MainActor
@Observable
final class FriendNudgeStore {
    private let service: FriendNudgeService
    private(set) var states: [UUID: FriendNudgeState] = [:]

    init(service: FriendNudgeService) {
        self.service = service
    }

    func state(for friend: Friend) -> FriendNudgeState {
        states[friend.profile.id] ?? .idle
    }

    func send(to friend: Friend) async {
        let friendID = friend.profile.id
        guard !isDisabled(for: friend) else { return }

        states[friendID] = .sending
        do {
            let result = try await service.sendNudge(to: friendID)
            switch result {
            case .sent:
                states[friendID] = .sent
            case .noRecipientToken:
                states[friendID] = .noRecipientToken
            case .rateLimited(let nextAllowedAt):
                states[friendID] = .rateLimited(nextAllowedAt: nextAllowedAt)
            }
        } catch {
            states[friendID] = .failed(error.localizedDescription)
        }
    }

    func resetTransientState(for friend: Friend) async {
        let friendID = friend.profile.id
        switch states[friendID] {
        case .sent, .noRecipientToken, .failed:
            states[friendID] = .idle
        case .idle, .sending, .rateLimited, nil:
            break
        }
    }

    func buttonTitle(for friend: Friend) -> String {
        switch state(for: friend) {
        case .idle, .failed:
            "Nudge"
        case .sending:
            "Sending"
        case .sent:
            "Nudged"
        case .noRecipientToken:
            "Nudge"
        case .rateLimited:
            "Nudged today"
        }
    }

    func iconName(for friend: Friend) -> String {
        switch state(for: friend) {
        case .idle, .failed, .noRecipientToken:
            "bell.badge"
        case .sending:
            "hourglass"
        case .sent, .rateLimited:
            "checkmark.circle.fill"
        }
    }

    func message(for friend: Friend) -> String? {
        switch state(for: friend) {
        case .noRecipientToken:
            "They need notifications enabled first."
        case .failed(let message):
            message
        case .rateLimited:
            "You already nudged them today."
        case .idle, .sending, .sent:
            nil
        }
    }

    func isDisabled(for friend: Friend) -> Bool {
        switch state(for: friend) {
        case .sending, .sent, .rateLimited:
            true
        case .idle, .noRecipientToken, .failed:
            false
        }
    }
}
