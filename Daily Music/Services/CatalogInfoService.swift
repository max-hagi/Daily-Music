//
//  CatalogInfoService.swift
//  Daily Music
//
//  Pulls catalog facts for a song from Apple's FREE iTunes lookup API (no auth,
//  no paid account). Used by the "more info" sheet. Parsing is separated so it's
//  unit-testable; the live impl is a plain URLSession GET.
//

import Foundation

struct CatalogInfo: Equatable {
    var album: String?
    var releaseYear: String?
    var durationSeconds: Int?
    var genre: String?
    var albumURL: URL?
    var previewURL: URL?

    /// Parse the iTunes lookup JSON (`https://itunes.apple.com/lookup?id=…`).
    static func parse(_ data: Data) -> CatalogInfo? {
        struct Response: Decodable {
            struct Result: Decodable {
                let collectionName: String?
                let releaseDate: String?
                let trackTimeMillis: Int?
                let primaryGenreName: String?
                let collectionViewUrl: String?
                let previewUrl: String?
            }
            let results: [Result]
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let first = decoded.results.first else { return nil }
        return CatalogInfo(
            album: first.collectionName,
            releaseYear: first.releaseDate.map { String($0.prefix(4)) },
            durationSeconds: first.trackTimeMillis.map { $0 / 1000 },
            genre: first.primaryGenreName,
            albumURL: first.collectionViewUrl.flatMap(URL.init(string:)),
            previewURL: first.previewUrl.flatMap(URL.init(string:))
        )
    }

    /// "m:ss" for the duration, or nil.
    var durationText: String? {
        guard let s = durationSeconds else { return nil }
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

protocol CatalogInfoService {
    func info(appleMusicID: String) async throws -> CatalogInfo
}

struct MockCatalogInfoService: CatalogInfoService {
    func info(appleMusicID: String) async throws -> CatalogInfo {
        try? await Task.sleep(for: .milliseconds(300))
        return CatalogInfo(
            album: "Automatic for the People",
            releaseYear: "1992",
            durationSeconds: 257,
            genre: "Alternative",
            albumURL: URL(string: "https://music.apple.com/us/album/automatic-for-the-people/1440947547"),
            previewURL: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/92/36/e7/9236e7aa-cf4e-0010-483d-41601131043e/mzaf_10003196158059738086.plus.aac.p.m4a")
        )
    }
}

struct LiveCatalogInfoService: CatalogInfoService {
    func info(appleMusicID: String) async throws -> CatalogInfo {
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(appleMusicID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let info = CatalogInfo.parse(data) else { throw URLError(.cannotParseResponse) }
        return info
    }
}
