import Testing
import Foundation
@testable import Daily_Music

@MainActor
struct FriendNudgeTests {
    @Test func mockRateLimitsDeliveredNudgeForSameFriend() async throws {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A101")!
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 1_000))

        let first = try await service.sendNudge(to: friendID)
        let second = try await service.sendNudge(to: friendID)

        #expect(first == .sent)
        guard case .rateLimited(let nextAllowedAt) = second else {
            Issue.record("Expected second nudge to be rate limited")
            return
        }
        #expect(nextAllowedAt == Date(timeIntervalSince1970: 1_000 + 86_400))
    }

    @Test func mockDoesNotRateLimitNoTokenAttempt() async throws {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A102")!
        let service = MockFriendNudgeService(
            now: Date(timeIntervalSince1970: 1_000),
            recipientsWithoutTokens: [friendID]
        )

        let first = try await service.sendNudge(to: friendID)
        let second = try await service.sendNudge(to: friendID)

        #expect(first == .noRecipientToken)
        #expect(second == .noRecipientToken)
    }

    @Test func mockAllowsSameFriendAfterTwentyFourHours() async throws {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A103")!
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 1_000))

        _ = try await service.sendNudge(to: friendID)
        await service.setNow(Date(timeIntervalSince1970: 1_000 + 86_399))
        let earlyResult = try await service.sendNudge(to: friendID)
        guard case .rateLimited(let nextAllowedAt) = earlyResult else {
            Issue.record("Expected nudge before 24 hours to be rate limited")
            return
        }
        #expect(nextAllowedAt == Date(timeIntervalSince1970: 1_000 + 86_400))

        await service.setNow(Date(timeIntervalSince1970: 1_000 + 86_400))
        let result = try await service.sendNudge(to: friendID)

        #expect(result == .sent)
    }

    @Test func storeMapsSuccessAndRateLimitStates() async {
        let friend = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A104")!)
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 2_000))
        let store = FriendNudgeStore(
            service: service,
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        await store.send(to: friend)
        #expect(store.state(for: friend) == .sent)
        #expect(store.buttonTitle(for: friend) == "Nudged")
        #expect(store.isDisabled(for: friend))

        await store.resetTransientState(for: friend)
        await store.send(to: friend)

        guard case .rateLimited(let nextAllowedAt) = store.state(for: friend) else {
            Issue.record("Expected store state to be rate limited")
            return
        }
        #expect(nextAllowedAt == Date(timeIntervalSince1970: 2_000 + 86_400))
        #expect(store.buttonTitle(for: friend) == "Nudged today")
        #expect(store.isDisabled(for: friend))
    }

    @Test func storeMapsNoRecipientToken() async {
        let friendID = UUID(uuidString: "00000000-0000-0000-0000-00000000A105")!
        let friend = makeFriend(id: friendID)
        let service = MockFriendNudgeService(
            now: Date(timeIntervalSince1970: 3_000),
            recipientsWithoutTokens: [friendID]
        )
        let store = FriendNudgeStore(service: service)

        await store.send(to: friend)

        #expect(store.state(for: friend) == .noRecipientToken)
        #expect(store.message(for: friend) == "They need notifications enabled first.")
        #expect(!store.isDisabled(for: friend))
    }

    @Test func storeMapsThrownErrorToFailedState() async {
        let friend = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A108")!)
        let store = FriendNudgeStore(service: ThrowingNudgeService())

        await store.send(to: friend)

        #expect(store.state(for: friend) == .failed("Network went sideways"))
        #expect(store.buttonTitle(for: friend) == "Nudge")
        #expect(store.message(for: friend) == "Network went sideways")
        #expect(!store.isDisabled(for: friend))
    }

    @Test func storeTreatsExpiredRateLimitAsIdle() async {
        let friend = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A109")!)
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 5_000))
        var now = Date(timeIntervalSince1970: 5_000)
        let store = FriendNudgeStore(service: service, now: { now })

        await store.send(to: friend)
        await store.resetTransientState(for: friend)
        await store.send(to: friend)

        let nextAllowedAt = Date(timeIntervalSince1970: 5_000 + 86_400)
        #expect(store.state(for: friend) == .rateLimited(nextAllowedAt: nextAllowedAt))
        #expect(store.isDisabled(for: friend))
        #expect(store.buttonTitle(for: friend) == "Nudged today")
        #expect(store.message(for: friend) == "You already nudged them today.")

        now = nextAllowedAt

        #expect(store.state(for: friend) == .idle)
        #expect(!store.isDisabled(for: friend))
        #expect(store.buttonTitle(for: friend) == "Nudge")
        #expect(store.message(for: friend) == nil)
    }

    @Test func storeKeepsDifferentFriendsIndependent() async {
        let alex = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A106")!, name: "Alex")
        let sam = makeFriend(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A107")!, name: "Sam")
        let service = MockFriendNudgeService(now: Date(timeIntervalSince1970: 4_000))
        let store = FriendNudgeStore(service: service)

        await store.send(to: alex)

        #expect(store.state(for: alex) == .sent)
        #expect(store.state(for: sam) == .idle)
        #expect(!store.isDisabled(for: sam))

        await store.send(to: sam)

        #expect(store.state(for: alex) == .sent)
        #expect(store.state(for: sam) == .sent)
    }

    private func makeFriend(id: UUID, name: String = "Friend") -> Friend {
        Friend(
            friendshipID: UUID(),
            profile: UserProfile(id: id, displayName: name, avatarURL: nil)
        )
    }
}

private struct ThrowingNudgeService: FriendNudgeService {
    func sendNudge(to friendID: UUID) async throws -> FriendNudgeResult {
        throw FriendNudgeError.message("Network went sideways")
    }
}
