//
//  VaultView.swift
//  Daily Music
//
//  The archive: every published entry, newest first. Tap one to read it again
//  via the shared EntryDetailView.
//

import SwiftUI

struct VaultView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: VaultViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "Your vault is empty",
                        emptyMessage: "Past songs will collect here day by day.",
                        onRetry: { await model.load() }
                    ) { entries in
                        ScrollView {
                            CalendarMonthView(entries: entries)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Vault")
            .navigationDestination(for: DailyEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        .task {
            if model == nil { model = VaultViewModel(entries: env.entries) }
            await model?.load()
        }
    }
}

/// A compact row used by both the Vault and Favorites lists.
struct EntryRow: View {
    let entry: DailyEntry

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtView(url: entry.albumArtURL, cornerRadius: 8)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.headline)
                Text(entry.artist).font(.subheadline).foregroundStyle(.secondary)
                Text(entry.date.formatted(.dateTime.month().day().year()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
