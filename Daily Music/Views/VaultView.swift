//
//  VaultView.swift
//  Daily Music
//
//  The archive: every published entry, newest first. The live moment belongs to
//  Today; Vault gives missed songs a useful second life without changing backend
//  tracking semantics.
//

import SwiftUI

struct VaultView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: VaultViewModel?

    private let calendar = Calendar.current

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
                        content(entries)
                    }
                } else {
                    MusicLoadingView(title: "Opening the vault", tint: .orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(vaultBackground)
                }
            }
            .navigationTitle("Vault")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: DailyEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        .task {
            if model == nil { model = VaultViewModel(entries: env.entries) }
            await model?.load()
        }
    }

    private func content(_ entries: [DailyEntry]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                vaultHero(entries)
                archiveStats(entries)
                calendarSection(entries)
                recentSection(entries)
            }
            .padding()
        }
        .background(vaultBackground)
    }

    private var vaultBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.96, blue: 0.92),
                Color(red: 0.9, green: 0.97, blue: 0.96),
                Color(red: 0.98, green: 0.9, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func vaultHero(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer()

                Text("CATCH-UP MODE")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Missed the live drop?")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The live moment belongs to Today. The Vault keeps every past pick ready for catching up, saving favorites, and finding the ones that got away.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let latest = entries.first {
                NavigationLink(value: latest) {
                    HStack(spacing: Theme.Spacing.md) {
                        AlbumArtView(url: latest.albumArtURL, cornerRadius: 12)
                            .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest archive pick")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.68))
                            Text(latest.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(latest.artist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(Theme.Spacing.md)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.33, blue: 0.42),
                    Color(red: 0.9, green: 0.38, blue: 0.26),
                    Color(red: 0.98, green: 0.66, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: Color(red: 0.9, green: 0.38, blue: 0.26).opacity(0.2), radius: 18, y: 10)
    }

    private func archiveStats(_ entries: [DailyEntry]) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            vaultMetric(value: "\(entries.count)", label: "songs", symbol: "music.note.list", tint: .teal)
            vaultMetric(value: "\(entriesThisMonth(entries))", label: "this month", symbol: "calendar", tint: .orange)
        }
    }

    private func vaultMetric(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func calendarSection(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Archive calendar")
                        .font(.dmTitle())
                    Text("Dots mark days with a published pick.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "circle.grid.3x3.fill")
                    .foregroundStyle(.teal)
            }

            CalendarMonthView(entries: entries)
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func recentSection(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent picks")
                .font(.dmTitle())

            VStack(spacing: 10) {
                ForEach(Array(entries.prefix(5))) { entry in
                    NavigationLink(value: entry) {
                        EntryRow(entry: entry)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.md)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func entriesThisMonth(_ entries: [DailyEntry]) -> Int {
        entries.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
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

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
