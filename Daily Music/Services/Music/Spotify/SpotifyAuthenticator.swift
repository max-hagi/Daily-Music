//
//  SpotifyAuthenticator.swift
//  Daily Music
//
//  The PKCE OAuth dance + token lifecycle for Spotify. SpotifySession talks
//  to the SpotifyAuthenticating protocol so the state machine is unit-testable;
//  this file holds the live implementation (ASWebAuthenticationSession +
//  accounts.spotify.com) and the mock.
//

import Foundation
import AuthenticationServices

struct SpotifyTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum SpotifyAuthError: Error, Equatable {
    case cancelled          // user closed the login sheet — not an error to surface
    case stateMismatch      // callback state didn't match; treat as failed login
    case needsReconnect     // refresh token rejected — user must connect again
    case invalidResponse
}

protocol SpotifyAuthenticating: Sendable {
    /// Whether tokens are stored (drives silent restore — no network).
    var hasStoredTokens: Bool { get }
    /// Run the full interactive PKCE flow. Throws SpotifyAuthError.cancelled
    /// if the user dismisses the sheet.
    func authorize() async throws
    /// A fresh access token — refreshes (and rotates) behind the scenes.
    /// Throws .needsReconnect when the refresh token is rejected.
    func validAccessToken() async throws -> String
    func clearTokens()
}

final class SpotifyAuthenticator: NSObject, SpotifyAuthenticating, @unchecked Sendable {
    private let keychain = KeychainStore(service: "daily-music.spotify")
    private static let tokensKey = "tokens"
    /// Refresh 5 min early so a token never expires mid-request.
    private static let expirySkew: TimeInterval = 300

    var hasStoredTokens: Bool { storedTokens() != nil }

    func clearTokens() {
        keychain.delete(Self.tokensKey)
    }

    // MARK: Interactive flow

    @MainActor
    func authorize() async throws {
        let verifier = SpotifyPKCE.codeVerifier()
        let state = UUID().uuidString

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: SpotifyConfig.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            .init(name: "scope", value: SpotifyConfig.scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: SpotifyPKCE.codeChallenge(for: verifier)),
            .init(name: "state", value: state),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: SpotifyConfig.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: SpotifyAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? SpotifyAuthError.invalidResponse)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        guard items?.first(where: { $0.name == "state" })?.value == state else {
            throw SpotifyAuthError.stateMismatch
        }
        guard let code = items?.first(where: { $0.name == "code" })?.value else {
            throw SpotifyAuthError.invalidResponse   // includes ?error=access_denied
        }

        let tokens = try await exchange(form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "client_id": SpotifyConfig.clientID,
            "code_verifier": verifier,
        ], existingRefreshToken: nil)
        try persist(tokens)
    }

    // MARK: Token lifecycle

    func validAccessToken() async throws -> String {
        guard let tokens = storedTokens() else { throw SpotifyAuthError.needsReconnect }
        if tokens.expiresAt.timeIntervalSinceNow > Self.expirySkew {
            return tokens.accessToken
        }
        // Token-endpoint rejection (400/401) is mapped to .needsReconnect inside
        // exchange(); plain network errors rethrow untouched so a dead wifi
        // moment never wipes a healthy connection.
        let refreshed = try await exchange(form: [
            "grant_type": "refresh_token",
            "refresh_token": tokens.refreshToken,
            "client_id": SpotifyConfig.clientID,
        ], existingRefreshToken: tokens.refreshToken)
        try persist(refreshed)
        return refreshed.accessToken
    }

    // MARK: Helpers

    private func storedTokens() -> SpotifyTokens? {
        keychain.data(for: Self.tokensKey).flatMap { try? JSONDecoder().decode(SpotifyTokens.self, from: $0) }
    }

    private func persist(_ tokens: SpotifyTokens) throws {
        try keychain.set(try JSONEncoder().encode(tokens), for: Self.tokensKey)
    }

    /// POST accounts.spotify.com/api/token. Spotify rotates refresh tokens —
    /// when the response omits one (refresh grant sometimes does), keep the
    /// existing token.
    private func exchange(form: [String: String], existingRefreshToken: String?) async throws -> SpotifyTokens {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAuthError.invalidResponse }
        guard http.statusCode == 200 else {
            // 400/401 from the token endpoint = grant rejected (revoked/expired).
            throw (400...401).contains(http.statusCode)
                ? SpotifyAuthError.needsReconnect
                : SpotifyAuthError.invalidResponse
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Double
            let refresh_token: String?
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refresh = decoded.refresh_token ?? existingRefreshToken else {
            throw SpotifyAuthError.invalidResponse
        }
        return SpotifyTokens(
            accessToken: decoded.access_token,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(decoded.expires_in)
        )
    }
}

extension SpotifyAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

/// Test/sim stand-in: connects instantly, hands out a fixed token.
final class MockSpotifyAuthenticator: SpotifyAuthenticating, @unchecked Sendable {
    var hasStoredTokens: Bool
    var authorizeError: SpotifyAuthError?
    var tokenError: SpotifyAuthError?
    private(set) var clearCount = 0

    init(hasStoredTokens: Bool = false) {
        self.hasStoredTokens = hasStoredTokens
    }

    func authorize() async throws {
        if let authorizeError { throw authorizeError }
        hasStoredTokens = true
    }

    func validAccessToken() async throws -> String {
        if let tokenError { throw tokenError }
        return "mock-access-token"
    }

    func clearTokens() {
        hasStoredTokens = false
        clearCount += 1
    }
}
