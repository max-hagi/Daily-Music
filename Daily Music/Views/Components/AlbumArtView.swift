//
//  AlbumArtView.swift
//  Daily Music
//
//  Square album artwork with a graceful placeholder while it loads.
//
//  We back the load with a small in-memory cache of decoded images rather than
//  using AsyncImage directly: a remounted AsyncImage resets to its `.empty`
//  phase and reloads, which flashed the gray placeholder back in whenever a
//  sleeve was rebuilt (e.g. when the favorites wall reshuffles records across
//  rows). Seeding the view's state from the cache in `init` means the very first
//  frame after a remount already shows the art — no flash.
//

import SwiftUI
import UIKit

/// Process-wide cache of decoded album art, keyed by URL. NSCache self-evicts
/// under memory pressure, so this stays a cache, not a leak.
private enum AlbumArtCache {
    static let images = NSCache<NSURL, UIImage>()
}

struct AlbumArtView: View {
    let url: URL?
    var cornerRadius: CGFloat = 16

    // Pre-seeded from the cache in init, so a cache hit draws on the first frame.
    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL?, cornerRadius: CGFloat = 16) {
        self.url = url
        self.cornerRadius = cornerRadius
        if let url {
            _image = State(initialValue: AlbumArtCache.images.object(forKey: url as NSURL))
        }
    }

    var body: some View {
        Group {
            if let image {
                // `.resizable()` lets it scale; `.scaledToFill()` fills the square
                // (cropping overflow) rather than letterboxing.
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed {
                // Load failed → placeholder with a music-note glyph.
                placeholder.overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Still loading → placeholder with a spinner overlaid on top.
                placeholder.overlay { ProgressView() }
            }
        }
        .aspectRatio(1, contentMode: .fit)   // force a 1:1 square
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))   // rounded corners
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        // Re-runs if the URL changes; cancels automatically on disappear.
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            image = nil
            failed = true
            return
        }
        // Cache hit → show immediately (also covers a URL change after init).
        if let cached = AlbumArtCache.images.object(forKey: url as NSURL) {
            image = cached
            failed = false
            return
        }
        // Miss → placeholder while we fetch + decode once, then cache it.
        image = nil
        failed = false
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled else { return }
            guard let decoded = UIImage(data: data) else {
                failed = true
                return
            }
            AlbumArtCache.images.setObject(decoded, forKey: url as NSURL)
            image = decoded
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    // A computed sub-view, factored out because it's reused in the branches above.
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)   // a faint adaptive gray
    }
}
