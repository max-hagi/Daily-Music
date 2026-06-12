//
//  SpotifyLibraryAPI.swift
//  Daily Music
//
//  Thin Spotify Web API client for one job: get the daily song into a private
//  "Daily Music" playlist. The playlist ID is cached after first resolution so
//  the steady-state save is a single request. Transport is injected so request
//  shapes are unit-testable offline.
//

import Foundation

struct SpotifyLibraryAPI {
    enum APIError: Error, Equatable {
        case http(Int)          // non-success status (after retries)
        case notAllowlisted     // 403 — Spotify dev-mode user cap
        case invalidResponse
    }

    private static let playlistName = "Daily Music"
    private static let cacheKey = "spotify.dailyPlaylistID"

    let defaults: UserDefaults
    var transport: (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

    func saveToDailyPlaylist(trackID: String, accessToken: String) async throws {
        if let cached = defaults.string(forKey: Self.cacheKey) {
            do {
                try await addTrack(trackID, to: cached, token: accessToken)
                return
            } catch APIError.http(404) {
                defaults.removeObject(forKey: Self.cacheKey)   // user deleted it — re-resolve
            }
        }
        let playlistID = try await findOrCreatePlaylist(token: accessToken)
        defaults.set(playlistID, forKey: Self.cacheKey)
        try await addTrack(trackID, to: playlistID, token: accessToken)
    }

    // MARK: Requests

    private func addTrack(_ trackID: String, to playlistID: String, token: String) async throws {
        var request = makeRequest("POST", path: "/v1/playlists/\(playlistID)/tracks", token: token)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["uris": ["spotify:track:\(trackID)"]])
        _ = try await send(request)
    }

    private func findOrCreatePlaylist(token: String) async throws -> String {
        struct Me: Decodable { let id: String }
        struct Playlists: Decodable {
            struct Item: Decodable { let id: String; let name: String }
            let items: [Item]
        }

        let me = try JSONDecoder().decode(Me.self, from: try await send(makeRequest("GET", path: "/v1/me", token: token)))
        let lists = try JSONDecoder().decode(
            Playlists.self,
            from: try await send(makeRequest("GET", path: "/v1/me/playlists", query: "limit=50", token: token))
        )
        if let existing = lists.items.first(where: { $0.name == Self.playlistName }) {
            return existing.id
        }

        var create = makeRequest("POST", path: "/v1/users/\(me.id)/playlists", token: token)
        create.httpBody = Data(#"{"name":"Daily Music","public":false,"description":"Your daily songs from Daily Music"}"#.utf8)
        struct Created: Decodable { let id: String }
        return try JSONDecoder().decode(Created.self, from: try await send(create)).id
    }

    // MARK: Plumbing

    private func makeRequest(_ method: String, path: String, query: String? = nil, token: String) -> URLRequest {
        var components = URLComponents(string: "https://api.spotify.com")!
        components.path = path
        components.query = query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// One 429 retry honoring Retry-After; everything else maps to APIError.
    private func send(_ request: URLRequest, isRetry: Bool = false) async throws -> Data {
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200...299:
            return data
        case 403:
            throw APIError.notAllowlisted
        case 429 where !isRetry:
            let delay = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1
            try await Task.sleep(for: .seconds(delay))
            return try await send(request, isRetry: true)
        default:
            throw APIError.http(http.statusCode)
        }
    }
}
