import Testing
import Foundation
@testable import Daily_Music

struct AvatarStyleTests {
    @Test func twoWordInitials() { #expect(AvatarStyle.initials(from: "Maxime Save") == "MS") }
    @Test func oneWordInitial() { #expect(AvatarStyle.initials(from: "Maxime") == "M") }
    @Test func trimsAndUppercases() { #expect(AvatarStyle.initials(from: "  ada lovelace ") == "AL") }
    @Test func emptyFallsBackToQuestionMark() {
        #expect(AvatarStyle.initials(from: "   ") == "?")
        #expect(AvatarStyle.initials(from: nil) == "?")
    }
    @Test func paletteIndexIsDeterministicAndInRange() {
        let a = AvatarStyle.paletteIndex(for: "Maxime", paletteCount: 6)
        let b = AvatarStyle.paletteIndex(for: "Maxime", paletteCount: 6)
        #expect(a == b)
        #expect((0..<6).contains(a))
    }
    @Test func paletteIndexHandlesEmptyPalette() {
        #expect(AvatarStyle.paletteIndex(for: "x", paletteCount: 0) == 0)
    }
}
