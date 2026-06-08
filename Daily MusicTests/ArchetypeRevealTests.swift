import Testing
@testable import Daily_Music

struct ArchetypeRevealTests {
    @Test func tasteProfileAllCasesHaveUniqueIDsAndLookup() {
        let ids = TasteProfile.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)

        for profile in TasteProfile.allCases {
            #expect(TasteProfile.profile(id: profile.id) == profile)
        }
        #expect(TasteProfile.profile(id: "missing") == nil)
        #expect(TasteProfile.profile(id: nil) == nil)
    }

    @Test func everyTasteProfileHasAFlare() {
        for profile in TasteProfile.allCases {
            let flare = ArchetypeRevealFlare.flare(for: profile)
            #expect(flare.id == profile.id)
            #expect(flare.particleStyle != .none)
            #expect(flare.lightStyle != .none)
            #expect(flare.texture != .none)
            #expect(flare.hapticPattern != .none)
        }
    }

    @Test func festivalGoerMapsToPartyFlare() {
        let flare = ArchetypeRevealFlare.flare(for: .euphoricFestivalKid)

        #expect(flare.particleStyle == .confetti)
        #expect(flare.lightStyle == .partyBeams)
        #expect(flare.texture == .sparkleBurst)
        #expect(flare.hapticPattern == .sparkle)
    }

    @Test func crispRewardScheduleHasDopamineBeats() {
        let schedule = ArchetypeHapticSchedule.crispReward(pattern: .sparkle, reduceMotion: false)

        #expect(schedule.beats.map(\.kind) == [.anticipation, .flood, .accent, .accent, .lockIn])
        #expect(schedule.beats.map(\.time) == [0.25, 1.15, 1.45, 2.05, 2.8])
    }

    @Test func reduceMotionScheduleKeepsOnlySuccessBeat() {
        let schedule = ArchetypeHapticSchedule.crispReward(pattern: .sparkle, reduceMotion: true)

        #expect(schedule.beats.map(\.kind) == [.lockIn])
        #expect(schedule.beats.map(\.time) == [1.1])
    }
}
