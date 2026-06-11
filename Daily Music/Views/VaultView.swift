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
    // Days the user opened the app — drives the data-driven catch-up hero.
    @State private var checkInDays: Set<Date> = []

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
            checkInDays = (try? await env.checkIns.checkInDates()) ?? []
            openPendingEntry()
        }
        .onChange(of: entryToOpen?.id) { _, _ in
            openPendingEntry()
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
        .refreshable {
            await model?.load()
            reactions = (try? await env.reactions.myReactions()) ?? [:]
            checkInDays = (try? await env.checkIns.checkInDates()) ?? []
            Haptics.tap()
        }
        
        // Tapping any Vault song presents a dedicated fullscreen detail instead of
        // pushing inside this NavigationStack. This keeps the Vault list/calendar
        // state intact while letting the song screen mimic Today's immersive layout.
        .fullScreenCover(item: $selectedVaultEntry) { entry in
            VaultEntryDetail(entry: entry, onClose: closeSelectedVaultEntry)
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

    /// Shared rule (also drives the Vault tab badge): last week's drops on
    /// days with no check-in, minus the ones already caught up on here.
    private func missedRecentEntries(_ entries: [DailyEntry]) -> [DailyEntry] {
        CatchUp.missedEntries(
            in: entries,
            checkInDays: checkInDays,
            heardEntryIDs: env.catchUpLog.heardEntryIDs,
            calendar: calendar
        )
    }

    // Data-driven hero: same gradient stage, but the copy reflects THIS user's
    // week — N drops to catch up on, or a small win when they caught them all.
    // Static marketing copy goes stale by visit three; a mirror never does.
    private func vaultHero(_ entries: [DailyEntry]) -> some View {
        let missed = missedRecentEntries(entries)

        return VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: missed.isEmpty ? "checkmark.seal.fill" : "archivebox.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer()

                Text(missed.isEmpty ? "ALL CAUGHT UP" : "CATCH-UP MODE")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(heroTitle(missedCount: missed.count))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(heroSubtitle(missedCount: missed.count))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let featured = missed.first ?? entries.first {
                Button {
                    openVaultEntry(featured)
                } label: {
                    VaultTintedEntryRow(entry: featured, eyebrow: heroRowEyebrow(for: featured, isMissed: !missed.isEmpty))
                }
                .buttonStyle(PressableCardButtonStyle())
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

    private func heroTitle(missedCount: Int) -> String {
        switch missedCount {
        case 0: "You caught every drop this week"
        case 1: "One drop slipped past you"
        default: "\(missedCount) drops slipped past you"
        }
    }

    private func heroSubtitle(missedCount: Int) -> String {
        missedCount == 0
            ? "Every pick from the past week, heard. The Vault keeps the older ones ready whenever you want to dig."
            : "The live moment belongs to Today — but this week's missed picks are still right here, waiting."
    }

    private func heroRowEyebrow(for entry: DailyEntry, isMissed: Bool) -> String {
        guard isMissed else { return "Latest archive pick" }
        let weekday = entry.date.formatted(.dateTime.weekday(.wide))
        return "\(weekday)'s pick — tap to catch up"
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
        .glassCardStyle(tint: tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

            CalendarMonthView(entries: entries, reactions: reactions) { entry in
                openVaultEntry(entry)
            }
        }
        .padding(Theme.Spacing.lg)
        .glassCardStyle(tint: .teal.opacity(0.08))
    }

    private func recentSection(_ entries: [DailyEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent picks")
                    .font(.dmTitle())

                Spacer()

                // The archive's browse/search entry point — without it, anything
                // older than the five rows below is only reachable date-by-date
                // through the calendar.
                NavigationLink {
                    VaultAllSongsView(entries: entries)
                } label: {
                    HStack(spacing: 3) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                }
            }

            VStack(spacing: 10) {
                // `.prefix(5)` takes at most the first five; ForEach needs an Array,
                // and no `id:` is required because DailyEntry is Identifiable.
                ForEach(Array(entries.prefix(5))) { entry in
                    Button {
                        openVaultEntry(entry)
                    } label: {
                        VaultTintedEntryRow(entry: entry)
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
        }
    }

    // Count entries whose date is in the current month (toGranularity: .month).
    private func entriesThisMonth(_ entries: [DailyEntry]) -> Int {
        entries.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
    }

    private func openVaultEntry(_ entry: DailyEntry, openedFromExternalSource: Bool = false) {
        selectedVaultEntryOpenedFromExternalSource = openedFromExternalSource
        selectedVaultEntry = entry
        // Opening counts as catching up — the hero and tab badge clear live.
        env.catchUpLog.markHeard(entry)
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

    private func releaseDateLabel(for entry: DailyEntry) -> String {
        "Released \(entry.date.formatted(.dateTime.month(.wide).day().year()))"
    }
}

/// Every published entry, searchable by title, artist, genre, or mood — the
/// "where's that song from a while ago?" screen. Pushed from Recent picks.
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
                        env.catchUpLog.markHeard(entry)   // counts as catching up
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
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .glassPillStyle(tint: .red.opacity(0.08))
        .accessibilityLabel("\(count) people opened the app that day")
        .onAppear { isPulsing = !reduceMotion }
    }
}

private struct VaultTintedEntryRow: View {
    let entry: DailyEntry
    var eyebrow: String?

    @Environment(AppEnvironment.self) private var env
    @State private var palette = ArtworkPalette()

    // Reactive: reads from the shared RatingsStore — updates instantly when any
    // other view (e.g. CategorySongsSheet) writes a new value.
    private var myRating: Int? { env.ratingsStore.rating(for: entry.id) }

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

            if let r = myRating {
                Text(r > 0 ? "👍" : "👎")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent.opacity(0.72))
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardStyle(
            tint: palette.accent.opacity(palette.isLoaded ? 0.16 : 0.06),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(palette.accent.opacity(palette.isLoaded ? 0.58 : 0.22))
                .frame(width: 3)
                .padding(.vertical, 14)
        }
        .animation(.easeInOut(duration: 0.35), value: palette.accent)
        .task(id: entry.id) { await palette.load(from: entry.albumArtURL) }
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
