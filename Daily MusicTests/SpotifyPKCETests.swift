import Testing
import Foundation
@testable import Daily_Music

struct SpotifyPKCETests {
    @Test func verifierIsWithinRFCLengthAndCharset() {
        let verifier = SpotifyPKCE.codeVerifier()
        #expect(verifier.count >= 43 && verifier.count <= 128)
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect(verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    @Test func verifiersAreUnique() {
        #expect(SpotifyPKCE.codeVerifier() != SpotifyPKCE.codeVerifier())
    }

    // RFC 7636 Appendix B test vector.
    @Test func challengeMatchesRFCTestVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(SpotifyPKCE.codeChallenge(for: verifier)
                == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
}
