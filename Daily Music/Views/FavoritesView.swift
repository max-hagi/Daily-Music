//
//  FavoritesView.swift
//  Daily Music
//
//  The hearted entries, styled to match Vault/Insights: light gradient surface,
//  a compact header, and material card rows. Recomputes whenever the FavoritesStore
//  changes, so un-hearting anywhere updates the list live.
//

import SwiftUI
import UniformTypeIdentifiers

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FavoritesViewModel?
    @State private var selectedEntry: DailyEntry?
    @State private var recentlyRemoved: DailyEntry?

    // Collection state
    @State private var orderStore = FavoritesOrderStore()
    @State private var arranged: [DailyEntry] = []   // ordered, pre-filter
    @State private var filter = FavoritesFilter()
    @State private var isRearranging = false
    @State private var showingFilterSheet = false
    @State private var draggingEntry: DailyEntry?

    /// The list actually shown: manual order, then narrowed by search/filter.
    private var displayed: [DailyEntry] { arranged.filter(filter.matches) }

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    switch model.state {
                    case .loaded:  loadedContent
                    case .empty:   emptyState
                    case .failed:  failedState
                    case .loading: loadingState
                    }
                } else {
                    loadingState
                }
            }
            .navigationTitle("Favorites")
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $filter.query, prompt: "Search favorites")
            .onChange(of: filter) { _, newValue in
                if isRearranging, newValue.isActive {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isRearranging = false }
                }
            }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingFilterSheet) {
                FavoritesFilterSheet(filter: $filter, facets: favoritesFacets(in: arranged))
                    .presentationDetents([.medium, .large])
            }
            .overlay(alignment: .bottom) {
                if recentlyRemoved != nil {
                    UndoBanner(message: "Removed from favorites") { undoRemove() }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: recentlyRemoved)
            .task(id: recentlyRemoved) {
                guard recentlyRemoved != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                recentlyRemoved = nil
            }
        }
        // Re-runs whenever the favorites SET changes (hearting/un-hearting anywhere).
        .task(id: env.favoritesStore.ids) {
            if model == nil { model = FavoritesViewModel(entries: env.entries) }
            await model?.load(favoriteIDs: env.favoritesStore.ids)
            if case .loaded(let entries) = model?.state {
                arranged = orderStore.arranged(entries)
            }
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            FavoriteEntryDetail(entry: entry) { selectedEntry = nil }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isRearranging {
                Button("Done") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isRearranging = false }
                }
                .fontWeight(.semibold)
            } else {
                Button { showingFilterSheet = true } label: {
                    Image(systemName: filter.hasFacetFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .overlay(alignment: .topTrailing) {
                            let count = filter.genres.count + filter.decades.count + filter.moods.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 14, minHeight: 14)
                                    .background(.pink, in: Circle())
                                    .offset(x: 7, y: -7)
                            }
                        }
                }
                .accessibilityLabel("Filter")
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

    // .loaded can briefly hold entries before `arranged` syncs in the task; while
    // not narrowing, an empty `displayed` means that one-frame gap → show loading.
    @ViewBuilder
    private var loadedContent: some View {
        if displayed.isEmpty {
            if filter.isActive { noMatchesState } else { loadingState }
        } else {
            wall
        }
    }

    private var wall: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header(count: arranged.count)
                    .padding(.horizontal, Theme.Spacing.md)
                ForEach(shelfRows(displayed), id: \.self) { row in
                    shelf(row)
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .scrollContentBackground(.hidden)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            if isRearranging {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isRearranging = false }
            }
        }
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
                ForEach(row) { entry in recordCell(entry) }
                ForEach(0 ..< (3 - row.count), id: \.self) { _ in
                    Spacer().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            // The shelf ledge — fades while rearranging so records "lift off".
            Rectangle()
                .fill(.primary.opacity(0.12))
                .frame(height: 2)
                .padding(.horizontal, Theme.Spacing.sm)
                .opacity(isRearranging ? 0 : 1)
        }
    }

    private func recordCell(_ entry: DailyEntry) -> some View {
        let cell = VStack(spacing: 6) {
            SleeveView(entry: entry,
                       status: env.listensStore.status(for: entry),
                       size: 104,
                       missingVariant: env.variants.missingSleeve,
                       secondhandVariant: env.variants.secondhand)
            VStack(spacing: 1) {
                Text(entry.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text(entry.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(Jiggle(active: isRearranging, seed: entry.id.hashValue))

        return Group {
            if isRearranging {
                cell
                    .opacity(draggingEntry == entry ? 0 : 1)
                    .onDrag {
                        draggingEntry = entry
                        return NSItemProvider(object: entry.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: FavoriteReorderDelegate(
                        item: entry,
                        items: $arranged,
                        dragging: $draggingEntry,
                        onCommit: { orderStore.commit(arranged.map(\.id)) }
                    ))
            } else {
                Button { selectedEntry = entry } label: { cell }
                    .buttonStyle(.plain)
                    .onLongPressGesture(minimumDuration: 0.4) {
                        guard arranged.count >= 2, !filter.isActive else { return }
                        Haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isRearranging = true
                        }
                    }
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
        }
    }

    private func header(count: Int) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 2) {
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

    private var noMatchesState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.pink.opacity(0.7))
            VStack(spacing: Theme.Spacing.sm) {
                Text("No matches")
                    .font(.dmTitle())
                Text("No favorites match your search or filters.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Clear filters") {
                withAnimation { filter = FavoritesFilter() }
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private var failedState: some View {
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
        model?.remove(id: entry.id)
        arranged.removeAll { $0.id == entry.id }
        recentlyRemoved = entry
        Task { await env.favoritesStore.toggle(entry) }
    }

    private func undoRemove() {
        guard let entry = recentlyRemoved else { return }
        Haptics.tap()
        recentlyRemoved = nil
        Task { await env.favoritesStore.toggle(entry) }
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
