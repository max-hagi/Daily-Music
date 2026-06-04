import Testing
@testable import Daily_Music

struct FriendCodeTests {
    @Test func generatesSixAllowedChars() {
        let code = FriendCode.generate()
        #expect(code.count == 6)
        #expect(code.allSatisfy { FriendCode.alphabet.contains($0) })
    }
    @Test func alphabetExcludesAmbiguous() {
        for c in "01OI" { #expect(!FriendCode.alphabet.contains(c)) }
    }
    @Test func normalizeUppercasesAndStrips() {
        #expect(FriendCode.normalize(" mx4k2p ") == "MX4K2P")
        #expect(FriendCode.normalize("a-b!c") == "ABC")   // strips non-alphabet
    }
}
