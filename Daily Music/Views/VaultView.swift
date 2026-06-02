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
    @State private var selectedVaultEntry: DailyEntry?

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
                    // Plain system spinner while the view model is built — matches
                    // Today's loading look. Kept on the vault gradient so the
                    // background doesn't flash.
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(vaultBackground)
                }
            }
            .navigationTitle("Vault")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(vaultBackground)
        }
        .task {
            if model == nil { model = VaultViewModel(entries: env.entries) }
            await model?.load()
        }
    }

    // The loaded layout. Broken into named helper functions (vaultHero, etc.) that
    // each take the entries and return a piece of the screen — keeps `body` readable.
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
        // Tapping any Vault song presents a dedicated fullscreen detail instead of
        // pushing inside this NavigationStack. This keeps the Vault list/calendar
        // state intact while letting the song screen mimic Today's immersive layout.
        .fullScreenCover(item: $selectedVaultEntry) { entry in
            VaultEntryDetail(entry: entry, onClose: { selectedVaultEntry = nil })
        }
    }

    private var vaultBackground: some View {
        LinearGradient(
            colors: Theme.Surface.vaultBackground,
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
                Button {
                    selectedVaultEntry = latest
                } label: {
                    VaultTintedEntryRow(entry: latest, eyebrow: "Latest archive pick")
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
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Surface.cardStroke, lineWidth: 1)
        }
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

            CalendarMonthView(entries: entries) { entry in
                selectedVaultEntry = entry
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Surface.cardStroke, lineWidth: 1)
        }
    }

    private func recentSection(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent picks")
                .font(.dmTitle())

            VStack(spacing: 10) {
                // `.prefix(5)` takes at most the first five; ForEach needs an Array,
                // and no `id:` is required because DailyEntry is Identifiable.
                ForEach(Array(entries.prefix(5))) { entry in
                    Button {
                        selectedVaultEntry = entry
                    } label: {
                        VaultTintedEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)   // keep our custom row look, not the default link styling
                }
            }
        }
    }

    // Count entries whose date is in the current month (toGranularity: .month).
    private func entriesThisMonth(_ entries: [DailyEntry]) -> Int {
        entries.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }

    private func releaseDateLabel(for entry: DailyEntry) -> String {
        "Released \(entry.date.formatted(.dateTime.month(.wide).day().year()))"
    }
}

// Fullscreen presentation for a single archived song.
//
// Earlier versions used a swipeable pager with its own floating chrome/backdrop.
// That created non-scrollable top/bottom regions where the album-art color wash
// could get clipped. This intentionally shows one song at a time and lets
// EntryDetailView own the scroll view + edge-to-edge artwork bleed, matching Today.
private struct VaultEntryDetail: View {
    let entry: DailyEntry
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            // Reuse the Today-style immersive detail surface, but turn off the
            // built-in share button and reaction mutation because Vault is archival.
            EntryDetailView(
                entry: entry,
                dateLabel: releaseDateLabel,
                showsNavigationTitle: false,
                albumArtHorizontalPadding: 24,
                usesImmersiveBackdrop: true,
                showsShareToolbarButton: false,
                reactionsAreReadOnly: true
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // In Vault this replaces Today's settings gear: it dismisses
                    // the fullscreen cover and returns to the archive.
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                // No trailing stat: the old "N listened" badge showed a fabricated
                // number. It stays out until a real per-entry listener count exists
                // (would need a Postgres function that totals opens for one entry).
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var releaseDateLabel: String {
        "Released \(entry.date.formatted(.dateTime.month(.wide).day().year()))"
    }
}

private struct VaultTintedEntryRow: View {
    let entry: DailyEntry
    var eyebrow: String?

    @State private var palette = ArtworkPalette()

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtView(url: entry.albumArtURL, cornerRadius: 8)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(entry.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.date.formatted(.dateTime.month().day().year()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent.opacity(0.72))
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(palette.isLoaded ? 0.28 : 0.12), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(palette.accent.opacity(palette.isLoaded ? 0.58 : 0.22))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
        .animation(.easeInOut(duration: 0.35), value: palette.accent)
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
    }

    private var rowBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                palette.accent.opacity(palette.isLoaded ? 0.20 : 0.08),
                Theme.Surface.card,
                Theme.Surface.card
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// A compact row used by both the Vault and Favorites lists.
// Defined once and reused in two screens — the payoff of small composable views.
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
