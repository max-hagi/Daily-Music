//
//  AlbumArtView.swift
//  Daily Music
//
//  Square album artwork with a graceful placeholder while it loads.
//

import SwiftUI

struct AlbumArtView: View {
    let url: URL?
    var cornerRadius: CGFloat = 16

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                placeholder.overlay { ProgressView() }
            case .failure:
                placeholder.overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            @unknown default:
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)
    }
}
