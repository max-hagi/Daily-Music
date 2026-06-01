//
//  AlbumArtView.swift
//  Daily Music
//
//  Square album artwork with a graceful placeholder while it loads.
//

import SwiftUI

// A reusable subview. `let url` is required at the call site; `var cornerRadius`
// has a default, so callers may override it or not. SwiftUI views are cheap
// structs recreated constantly — never put expensive work in their init.
struct AlbumArtView: View {
    let url: URL?
    var cornerRadius: CGFloat = 16

    // Every View must provide `body`, the description of what to draw.
    var body: some View {
        // AsyncImage downloads + caches the image for us. Its closure receives a
        // `phase` describing where the load is, and we draw a different view for each.
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                // `.resizable()` lets it scale; `.scaledToFill()` fills the square
                // (cropping overflow) rather than letterboxing.
                image.resizable().scaledToFill()
            case .empty:
                // Still loading → placeholder with a spinner overlaid on top.
                placeholder.overlay { ProgressView() }
            case .failure:
                // Download failed → placeholder with a music-note glyph.
                placeholder.overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            @unknown default:
                // Future-proofing: AsyncImage's enum could gain cases in later iOS.
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)   // force a 1:1 square
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))   // rounded corners
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    // A computed sub-view, factored out because it's reused in two branches above.
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)   // a faint adaptive gray
    }
}
