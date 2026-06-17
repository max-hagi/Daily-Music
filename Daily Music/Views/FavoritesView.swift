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

    // Collection state
    @State private var orderStore = FavoritesOrderStore()
    @State private var arranged: [DailyEntry] = []   // ordered, pre-filter
    @State private var filter = FavoritesFilter()
    @State private var isRearranging = false
    @State private var showingFilterSheet = false

    // Custom drag-to-reorder state. We drive reordering ourselves rather than
    // .onDrag/.onDrop so the lifted record keeps its real (async-loaded) album
    // art and the swap stays smooth — the system drag preview snapshotted the
    // sleeve before its artwork loaded, and re-chunking the shelves under a
    // system drop session was janky.
    @State private var draggingID: UUID?
    @State private var dragLocation: CGPoint = .zero
    @State private var cellFrames: [UUID: CGRect] = [:]
    private let wallSpace = "favoritesWall"

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
                    endRearranging()
                }
            }
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingFilterSheet) {
                FavoritesFilterSheet(filter: $filter, facets: favoritesFacets(in: arranged))
                    .presentationDetents([.medium, .large])
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
                    endRearranging()
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
            .coordinateSpace(name: wallSpace)
            .onPreferenceChange(FavoriteCellFrameKey.self) { cellFrames = $0 }
            // The lifted record floats above the wall, following the finger, so it
            // keeps its real artwork while the others reshuffle underneath it.
            .overlay(alignment: .topLeading) { draggingOverlay }
            // One gesture on the stable container. `.subviews` while not arranging
            // lets the cells' tap/long-press through (and the ScrollView scroll);
            // `.all` while arranging hands reordering to this gesture.
            .gesture(wallReorderGesture(),
                     including: isRearranging ? .all : .subviews)
        }
        // While arranging, the per-record drag gesture owns vertical motion;
        // scrolling re-enables on Done.
        .scrollDisabled(isRearranging)
        .scrollContentBackground(.hidden)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            if isRearranging {
                endRearranging()
            }
        }
        .refreshable {
            await env.favoritesStore.load()
            Haptics.tap()
        }
    }

    /// The record currently being dragged, rendered as a real (art-bearing) view
    /// floating at the finger. Nil unless a drag is in flight.
    @ViewBuilder
    private var draggingOverlay: some View {
        if let id = draggingID,
           let entry = arranged.first(where: { $0.id == id }),
           let frame = cellFrames[id] {
            recordCellBody(entry, jiggling: false)
                .frame(width: frame.width)
                .scaleEffect(1.06)
                .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
                .position(dragLocation)
                .allowsHitTesting(false)
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

    /// The visual record (sleeve + title/artist), with the rearrange wobble.
    /// Shared by the in-grid cell and the floating drag overlay.
    private func recordCellBody(_ entry: DailyEntry, jiggling: Bool) -> some View {
        VStack(spacing: 6) {
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
        .modifier(Jiggle(active: jiggling, seed: entry.id.hashValue))
    }

    private func recordCell(_ entry: DailyEntry) -> some View {
        Group {
            if isRearranging {
                recordCellBody(entry, jiggling: true)
                    // Hidden in-place while lifted — its slot stays as the gap the
                    // others flow around; the floating overlay shows the real art.
                    // The drag gesture lives on the wall container, not here: cells
                    // are rebuilt as rows re-chunk mid-drag, which would cancel a
                    // cell-hosted gesture and strand the lift (no .onEnded).
                    .opacity(draggingID == entry.id ? 0 : 1)
                    .background(frameReader(entry))
            } else {
                // A plain tappable cell, not a Button: SwiftUI's Button installs
                // its own press-gesture recognizer that swallows an attached
                // .onLongPressGesture, so the long-press-to-rearrange never fired.
                // A tap gesture + long-press gesture on a plain view disambiguate
                // cleanly — a quick tap opens the detail, a hold enters rearrange.
                recordCellBody(entry, jiggling: false)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedEntry = entry }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        guard arranged.count >= 2, !filter.isActive else { return }
                        Haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isRearranging = true
                        }
                    }
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    /// Publishes each record's frame in the wall's coordinate space so the drag
    /// can hit-test the finger against cells.
    private func frameReader(_ entry: DailyEntry) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: FavoriteCellFrameKey.self,
                value: [entry.id: geo.frame(in: .named(wallSpace))]
            )
        }
    }

    /// Drives the custom reorder from the stable wall container: on the first
    /// movement it lifts whichever record the drag began on, reshuffles live as
    /// the finger crosses others, and commits the new order on release. Living on
    /// the container (not a cell) guarantees `.onEnded` fires even as rows rebuild.
    private func wallReorderGesture() -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(wallSpace))
            .onChanged { value in
                if draggingID == nil {
                    guard let hit = arranged.first(where: {
                        cellFrames[$0.id]?.contains(value.startLocation) == true
                    }) else { return }
                    draggingID = hit.id
                    Haptics.tap()
                }
                dragLocation = value.location
                moveIfNeeded(to: value.location)
            }
            .onEnded { _ in
                guard draggingID != nil else { return }
                draggingID = nil
                orderStore.commit(arranged.map(\.id))
            }
    }

    /// If the finger is over a different record, swap the dragged one into its
    /// slot. Filter is inactive while arranging, so `arranged` == what's shown.
    private func moveIfNeeded(to point: CGPoint) {
        guard let dragID = draggingID,
              let target = arranged.first(where: { cellFrames[$0.id]?.contains(point) == true }),
              target.id != dragID,
              let from = arranged.firstIndex(where: { $0.id == dragID }),
              let to = arranged.firstIndex(where: { $0.id == target.id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            arranged.move(fromOffsets: IndexSet(integer: from),
                          toOffset: to > from ? to + 1 : to)
        }
    }

    /// Leaves rearrange mode, always clearing any in-flight lift so a dropped or
    /// interrupted drag can never strand the floating record on screen.
    private func endRearranging() {
        draggingID = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isRearranging = false }
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
