//
//  StreamingService.swift
//  Daily Music
//
//  The streaming services we can hand a song off to. Apple Music + Spotify use
//  the IDs we store (exact track links); Tidal has no stored ID so it opens a
//  search. Also the single source of truth for each service's display name + logo.
//

import SwiftUI

enum StreamingService: String, CaseIterable, Identifiable {
    case appleMusic = "Apple Music"
    case spotify    = "Spotify"
    case tidal      = "Tidal"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Deep link to this song in the service.
    func url(for entry: DailyEntry) -> URL? {
        switch self {
        case .appleMusic:
            return entry.appleMusicURL
        case .spotify:
            return entry.spotifyURL
        case .tidal:
            let q = "\(entry.artist) \(entry.title)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://tidal.com/search?q=\(q)")
        }
    }
}

/// Renders a service's logo at a consistent size. Apple has an SF Symbol; Spotify
/// uses a hand-built glyph (we can't ship the trademarked asset); Tidal is a
/// simple wordmark.
struct ServiceLogo: View {
    let service: StreamingService
    var size: CGFloat = 16

    var body: some View {
        Group {
            switch service {
            case .appleMusic:
                Image(systemName: "applelogo").font(.system(size: size))
            case .spotify:
                SpotifyGlyph().frame(width: size + 2, height: size + 2)
            case .tidal:
                Text("TIDAL").font(.system(size: size * 0.8, weight: .black)).tracking(0.5)
            }
        }
    }
}

// A hand-drawn Spotify-style glyph (three stacked waves in a green circle).
private struct SpotifyGlyph: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.12, green: 0.84, blue: 0.38))
            VStack(spacing: 2.2) {
                wave(width: 9.5, rotation: 7)
                wave(width: 8, rotation: 6)
                wave(width: 6.4, rotation: 5)
            }
            .foregroundStyle(.black.opacity(0.82))
        }
    }
    private func wave(width: CGFloat, rotation: Double) -> some View {
        Capsule().frame(width: width, height: 1.35).rotationEffect(.degrees(rotation)).offset(x: 0.8)
    }
}
