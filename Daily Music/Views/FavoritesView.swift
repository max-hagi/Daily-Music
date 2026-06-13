//
//  FavoritesView.swift
//  Daily Music
//
//  The hearted entries, styled to match Vault/Insights: light gradient surface,
//  a compact header, and material card rows. Recomputes whenever the FavoritesStore
//  changes, so un-hearting anywhere updates the list live.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FavoritesViewModel?
    @State private var selectedEntry: DailyEntry?
    @State private var recentlyRemoved: DailyEntry?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    // Unlike the other screens (which use LoadStateView), this one
                    // switches the state by hand so each case gets its own bespoke,
                    // on-brand layout instead of the generic placeholders.
                    switch model.state {
                    case .loaded(let entries): loaded(entries)
                    case .empty: emptyState
                    case .failed: failedState
                    case .loading: loadingState
                    }
                } else {
                    loadingState
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if recentlyRemoved != nil {
                    UndoBanner(message: "Removed from favorites") { undoRemove() }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: recentlyRemoved)
            // Auto-dismiss the undo banner ~4s after the most recent removal.
            .task(id: recentlyRemoved) {
                guard recentlyRemoved != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                recentlyRemoved = nil
            }
        }
        // KEY: `.task(id: env.favoritesStore.ids)` re-runs whenever the favorites
        // SET changes. So un-hearting a song on the detail screen flips the shared
        // store, which changes `ids`, which re-runs this task → the list updates
        // live without any manual refresh wiring.
        .task(id: env.favoritesStore.ids) {
            if model == nil { model = FavoritesViewModel(entries: env.entries) }
            await model?.load(favoriteIDs: env.favoritesStore.ids)
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            FavoriteEntryDetail(entry: entry) {
                selectedEntry = nil
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: Theme.Surface.favoritesBackground,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingState: some View {
        MusicLoadingView(title: nil, tint: .pink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
    }

    private func loaded(_ entries: [DailyEntry]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header(count: entries.count)
                    .padding(.horizontal, Theme.Spacing.md)
                ForEach(shelfRows(entries), id: \.self) { row in
                    shelf(row)
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .background(background)
        .refreshable {
            await env.favoritesStore.load()
            Haptics.tap()
        }
    }

    // Chunk the wall into rows of three records.
    private func shelfRows(_ entries: [DailyEntry]) -> [[DailyEntry]] {
        stride(from: 0, to: entries.count, by: 3).map {
            Array(entries[$0 ..< min($0 + 3, entries.count)])
        }
    }

    private func shelf(_ row: [DailyEntry]) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                ForEach(row) { entry in
                    framedRecord(entry)
                }
                ForEach(0 ..< (3 - row.count), id: \.self) { _ in
                    Spacer().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            // The shelf ledge.
            Rectangle()
                .fill(.primary.opacity(0.12))
                .frame(height: 2)
                .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    private func framedRecord(_ entry: DailyEntry) -> some View {
        Button { selectedEntry = entry } label: {
            VStack(spacing: 6) {
                AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.chip)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                VStack(spacing: 1) {
                    Text(entry.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(entry.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { selectedEntry = entry } label: {
                Label("Open Entry", systemImage: "arrow.up.forward.app")
            }
            Button(role: .destructive) { removeFavorite(entry) } label: {
                Label("Remove Favorite", systemImage: "heart.slash.fill")
            }
        } preview: {
            FavoriteEntryPeek(entry: entry)
        }
    }

    // Compact header instead of a gradient hero: the count is trivia, so the
    // songs themselves stay the visual lead of the screen.
    private func header(count: Int) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 2) {
                // Inline ternary handles singular/plural ("1 favorite" vs "3 favorites").
                Text("\(count) \(count == 1 ? "favorite" : "favorites")")
                    .font(.dmTitle())
                Text("The songs that stopped you in your tracks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .glassCardStyle(tint: .pink.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "heart.slash")
                .font(.system(size: 56))
                .foregroundStyle(.pink.opacity(0.7))
            VStack(spacing: Theme.Spacing.sm) {
                Text("No favorites yet")
                    .font(.dmTitle())
                Text("Tap the heart on any song to save it to your collection.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private var failedState: some View {
        // The label/actions closure form of ContentUnavailableView lets us add a
        // custom Retry button alongside the standard "empty" presentation.
        ContentUnavailableView {
            Label("Couldn't load favorites", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("Retry") {
                Task { await model?.load(favoriteIDs: env.favoritesStore.ids) }
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
        .background(background)
    }

    // MARK: - Remove + undo

    private func removeFavorite(_ entry: DailyEntry) {
        Haptics.thud()
        model?.remove(id: entry.id)                       // animate the row out now
        recentlyRemoved = entry                           // show the Undo banner
        Task { await env.favoritesStore.toggle(entry) }   // persist the un-favorite
    }

    private func undoRemove() {
        guard let entry = recentlyRemoved else { return }
        Haptics.tap()
        recentlyRemoved = nil
        Task { await env.favoritesStore.toggle(entry) }   // re-favorite → list reloads it back
    }
}

private struct FavoriteEntryPeek: View {
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.control)
                    .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).month().day().year()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(entry.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)

                    Text(entry.artist)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !metadataChips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(metadataChips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.pink.opacity(0.12), in: Capsule())
                            .foregroundStyle(.pink)
                    }
                }
            }

            Text(journalExcerpt)
                .font(.callout)
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .frame(width: 340, alignment: .leading)
        .glassCardStyle(tint: .pink.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var metadataChips: [String] {
        [entry.genre, entry.decade, entry.mood, entry.theme]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
    }

    private var journalExcerpt: String {
        let cleaned = entry.journalMarkdown
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > 180 else { return cleaned }
        let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return String(cleaned[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private struct FavoriteEntryDetail: View {
    let entry: DailyEntry
    let onClose: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var showingListen = false
    /// Real cross-user check-in count for the entry's day; badge hidden until loaded.
    @State private var listenerCount: Int?

    var body: some View {
        NavigationStack {
            EntryDetailView(
                entry: entry,
                dateLabel: releaseDateLabel,
                showsNavigationTitle: false,
                albumArtHorizontalPadding: 24,
                usesImmersiveBackdrop: true,
                reactionsAreReadOnly: !Calendar.current.isDateInToday(entry.date)
            )
            .simultaneousGesture(closeSwipeGesture)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingListen = true } label: {
                        Image(systemName: "headphones")
                    }
                    .accessibilityLabel("Listen")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let listenerCount, listenerCount > 0 {
                        VaultToolbarListenedBadge(count: listenerCount)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(id: entry.id) {
                listenerCount = try? await env.sharedStats.listenerCount(on: entry.date)
            }
            // Manual listen for a favorited song — the immersive player, opened on tap.
            .fullScreenCover(isPresented: $showingListen) {
                ListeningView(
                    entry: entry,
                    advanceLabel: "Done",
                    advanceSystemImage: "checkmark",
                    autoAdvanceOnFinish: false
                ) {
                    Task { await env.musicPlayer.stop() }
                    showingListen = false
                }
            }
        }
    }

    private func dismiss() {
        Task { await env.musicPlayer.stop() }
        onClose()
    }

    private var releaseDateLabel: String {
        entry.date.formatted(.dateTime.weekday(.wide).month().day())
    }

    private var closeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard value.translation.height > 120, abs(value.translation.width) < 90 else { return }
                dismiss()
            }
    }
}
