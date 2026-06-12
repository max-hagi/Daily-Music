//
//  SpotifyPKCE.swift
//  Daily Music
//
//  Pure PKCE (RFC 7636) helpers for the Spotify OAuth flow. No secret is
//  involved anywhere — the code challenge proves the same client that started
//  the login finishes it.
//

import Foundation
import CryptoKit

enum SpotifyPKCE {
    /// 64 random bytes → 86-char base64url string (within RFC's 43–128).
    static func codeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    /// S256: base64url(SHA256(verifier)).
    static func codeChallenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
