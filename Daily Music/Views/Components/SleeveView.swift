//
//  SleeveView.swift
//  Daily Music
//
//  One place that renders an entry's album art with its ListenStatus treatment,
//  so "mint / caught-up / missed" reads consistently across the Vault crate and
//  the calendar. Asset-free: dim + desaturate + an SF-Symbol overlay.
//

import SwiftUI

struct SleeveView: View {
    let entry: DailyEntry
    let status: ListenStatus
    var size: CGFloat = 64

    private var isMissed: Bool { status == .missed }

    var body: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.chip)
            .frame(width: size, height: size)
            .saturation(isMissed ? 0 : 1)
            .opacity(isMissed ? 0.4 : 1)
            .overlay {
                if isMissed {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: size * 0.28, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if status == .caughtUp {
                    Text("2nd")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(3)
                }
            }
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let state: String
        switch status {
        case .heardSameDay: state = "collected"
        case .caughtUp: state = "caught up, second pressing"
        case .missed: state = "missed"
        case .rescuable: state = "still available"
        case .unheard: state = "not yet heard"
        }
        return "\(entry.title) by \(entry.artist), \(state)"
    }
}

extension ListenStatus {
    /// Marker colour for compact surfaces (the calendar day dot).
    var indicatorColor: Color {
        switch self {
        case .heardSameDay: .teal
        case .caughtUp: .orange
        case .rescuable: .orange.opacity(0.55)
        case .missed: .gray.opacity(0.45)
        case .unheard: .accentColor
        }
    }
}
