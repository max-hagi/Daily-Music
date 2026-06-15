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
    @Binding private var entryToOpen: DailyEntry?
    var onReturnFromOpenedEntry: (() -> Void)? = nil

    @State private var model: VaultViewModel?
    @State private var selectedVaultEntry: DailyEntry?
    @State private var selectedVaultEntryOpenedFromExternalSource = false
    // entryID → my reaction emoji, used to stamp the calendar days.
    @State private var reactions: [UUID: String] = [:]
    // Which lens the hero shows: the Crate (browse) or the calendar (alternate lens).
    @State private var lens: VaultLens = .crate
    // Current streak, loaded from check-in history, for the milestone nudge.
    @State private var streak: Streak?
    // Collection share card presentation + pre-loaded covers.
    @State private var showingCollectionShare = false
    @State private var shareCovers: [UIImage] = []
    // Drives the zoom transition: a tapped sleeve expands into the detail view.
    @Namespace private var zoomNamespace

    init(
        entryToOpen: Binding<DailyEntry?> = .constant(nil),
        onReturnFromOpenedEntry: (() -> Void)? = nil
    ) {
        _entryToOpen = entryToOpen
        self.onReturnFromOpenedEntry = onReturnFromOpenedEntry
    }

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
                    MusicLoadingView(title: nil, tint: .orange)
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
            // Stamp the calendar with this user's reactions (best-effort; empty on failure).
            reactions = (try? await env.reactions.myReactions()) ?? [:]
            streak = Streak.compute(from: (try? await env.checkIns.checkInDates()) ?? [])
            openPendingEntry()
        }
        .onChange(of: entryToOpen?.id) { _, _ in
            openPendingEntry()
        }
    }

    // The loaded layout. The crate lens fills the screen (the dig is the hero);
    // the calendar lens scrolls. The header (count, catch-up, toggle) is shared.
    @ViewBuilder
    private func content(_ entries: [DailyEntry]) -> some View {
        Group {
            switch lens {
            case .crate:
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        vaultHeader(entries)
                            .padding(.horizontal)
                        crateSection(entries)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await model?.load()
                    reactions = (try? await env.reactions.myReactions()) ?? [:]
                    Haptics.tap()
                }
            case .calendar:
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        vaultHeader(entries)
                        calendarCard(entries)
                    }
                    .padding()
                }
                .refreshable {
                    await model?.load()
                    reactions = (try? await env.reactions.myReactions()) ?? [:]
                    Haptics.tap()
                }
            }
        }
        .background(vaultBackground)
        .toolbar {
            // The Crate is the full browse, so search replaces the old "See all"
            // entry point on the deleted Recent picks module.
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    VaultAllSongsView(entries: entries)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search the vault")
            }
        }
        // Tapping any Vault song presents a dedicated fullscreen detail instead of
        // pushing inside this NavigationStack. The cover zooms out of the tapped
        // sleeve (a square expanding) rather than sliding up from the bottom.
        .fullScreenCover(item: $selectedVaultEntry) { entry in
            VaultEntryDetail(entry: entry, onClose: closeSelectedVaultEntry)
                .navigationTransition(.zoom(sourceID: entry.id, in: zoomNamespace))
        }
        .sheet(isPresented: $showingCollectionShare) {
            CollectionShareSheet(
                count: env.listensStore.collectionCount,
                subtitle: nudgeLine(entries),
                covers: shareCovers
            )
        }
    }

    @ViewBuilder
    private func vaultHeader(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your collection")
                    .font(.title.weight(.semibold))
                Spacer()
                shareButton(entries)
            }
            HStack(spacing: Theme.Spacing.md) {
                Text(nudgeLine(entries))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                Spacer(minLength: Theme.Spacing.sm)
                lensHeader
            }
        }
    }

    /// Vault redesign §4 — the context-aware nudge under the title.
    private func nudgeLine(_ entries: [DailyEntry]) -> String {
        let rescuable = missedRecentEntries(entries).count
        let collectedToday = env.listensStore.collectedThisMonth() > 0
            && Calendar.current.isDate(
                env.listensStore.heardAt.values.max() ?? .distantPast,
                inSameDayAs: Date()
            )
        let started = env.listensStore.heardAt.values.min()
            .map { Calendar.current.dateInterval(of: .month, for: $0)?.start ?? $0 }
        return VaultNudge.line(
            total: env.listensStore.collectionCount,
            rescuable: rescuable,
            collectedToday: collectedToday,
            daysToNextMilestone: streak?.daysToNextMilestone,
            startedMonth: started
        )
    }

    /// Vault redesign §4 — the compact Shelf / Month lens toggle.
    private var lensHeader: some View {
        Picker("Lens", selection: $lens) {
            Image(systemName: "rectangle.stack").tag(VaultLens.crate)
            Image(systemName: "calendar").tag(VaultLens.calendar)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 92)
    }

    private func shareButton(_ entries: [DailyEntry]) -> some View {
        Button {
            Task { await prepareAndShowShare(entries) }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title3)
        }
        .accessibilityLabel("Share your collection")
    }

    /// Pre-load up to 9 recent collected covers, then present the share sheet.
    private func prepareAndShowShare(_ entries: [DailyEntry]) async {
        let collected = entries.filter { env.listensStore.isHeard($0) }
        let urls = collected.prefix(9).compactMap(\.albumArtURL)
        var images: [UIImage] = []
        for url in urls {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        shareCovers = images
        showingCollectionShare = true
    }

    /// The Crate: a vertical scroll of month shelves (Vault redesign §1).
    private func crateSection(_ entries: [DailyEntry]) -> some View {
        MonthShelvesView(
            entries: entries,
            missingVariant: env.variants.missingSleeve,
            secondhandVariant: env.variants.secondhand,
            status: { env.listensStore.status(for: $0) },
            onSelect: { openVaultEntry($0) },
            namespace: zoomNamespace
        )
    }

    private var vaultBackground: some View {
        LinearGradient(
            colors: Theme.Surface.vaultBackground,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// Shared rule (also drives the Vault tab badge): last week's drops on
    /// days with no check-in, minus the ones already caught up on here.
    private func missedRecentEntries(_ entries: [DailyEntry]) -> [DailyEntry] {
        CatchUp.missedEntries(
            in: entries,
            heardAt: env.listensStore.heardAt,
            calendar: calendar
        )
    }

    // §10.1.4 / §10.4 — the calendar as an alternate lens, behind the toggle.
    private func calendarCard(_ entries: [DailyEntry]) -> some View {
        CalendarMonthView(entries: entries, reactions: reactions,
                          status: { env.listensStore.status(for: $0) },
                          missingVariant: env.variants.missingSleeve,
                          secondhandVariant: env.variants.secondhand) { entry in
            openVaultEntry(entry)
        }
        .padding(Theme.Spacing.md)
        .glassCardStyle(tint: .teal.opacity(0.08))
    }

    private func openVaultEntry(_ entry: DailyEntry, openedFromExternalSource: Bool = false) {
        selectedVaultEntryOpenedFromExternalSource = openedFromExternalSource
        selectedVaultEntry = entry
        // Opening counts as catching up — the hero and tab badge clear live.
        env.listensStore.markHeard(entry)
    }

    private func openPendingEntry() {
        guard let entryToOpen else { return }
        openVaultEntry(entryToOpen, openedFromExternalSource: true)
        self.entryToOpen = nil
    }

    private func closeSelectedVaultEntry() {
        selectedVaultEntry = nil
        guard selectedVaultEntryOpenedFromExternalSource else { return }
        selectedVaultEntryOpenedFromExternalSource = false
        onReturnFromOpenedEntry?()
    }

}

private enum VaultLens {
    case crate, calendar
}

/// Every published entry, searchable by title, artist, genre, or mood — the
/// "where's that song from a while ago?" screen. Reached from the Vault search.
struct VaultAllSongsView: View {
    let entries: [DailyEntry]

    @Environment(AppEnvironment.self) private var env
    @State private var query = ""
    @State private var selectedEntry: DailyEntry?

    private var filtered: [DailyEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(trimmed)
                || entry.artist.localizedCaseInsensitiveContains(trimmed)
                || (entry.genre?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (entry.mood?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(filtered) { entry in
                    Button {
                        selectedEntry = entry
                        env.listensStore.markHeard(entry)   // counts as catching up
                    } label: {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(
            LinearGradient(
                colors: Theme.Surface.vaultBackground,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .searchable(text: $query, prompt: "Song, artist, genre, or mood")
        .navigationTitle("All songs")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedEntry) { entry in
            VaultEntryDetail(entry: entry) { selectedEntry = nil }
        }
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

    @Environment(AppEnvironment.self) private var env
    @State private var showingListen = false
    /// Real cross-user check-in count for the entry's day; badge hidden until loaded.
    @State private var listenerCount: Int?

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
                showsShareToolbarButton: true,
                reactionsAreReadOnly: !Calendar.current.isDateInToday(entry.date)
            )
            .simultaneousGesture(closeSwipeGesture)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // In Vault this replaces Today's settings gear: it dismisses
                    // the fullscreen cover and returns to the archive.
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
            // Manual listen for archived songs — the immersive player, opened on
            // tap (never auto, unlike Today's first-open ceremony).
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
        "Released \(entry.date.formatted(.dateTime.month(.wide).day().year()))"
    }

    private var closeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard value.translation.height > 120, abs(value.translation.width) < 90 else { return }
                dismiss()
            }
    }
}

struct VaultToolbarListenedBadge: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.18))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.35 : 0.8)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)

                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            }

            Text("\(count.formatted()) listened")
                .font(.caption.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .glassPillStyle(tint: .red.opacity(0.08))
        .accessibilityLabel("\(count) people opened the app that day")
        .onAppear { isPulsing = !reduceMotion }
    }
}

/// A compact row used by both the Vault and Favorites lists.
// Defined once and reused in two screens — the payoff of small composable views.
struct EntryRow: View {
    let entry: DailyEntry

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtView(url: entry.albumArtURL, cornerRadius: Theme.Radius.chip)
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
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
