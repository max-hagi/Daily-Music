//
//  InsightsView.swift
//  Daily Music
//
//  Your taste mirror. The whole screen bleeds the archetype's color; the mirror
//  itself (hero + standout tiles + genre/language rows) is rendered by the shared
//  TasteMirrorBoard, so it stays identical to a friend's read-only mirror. This
//  screen adds the personal extras: the "See your month" Wrapped button.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: InsightsViewModel?
    @State private var badges: BadgesViewModel?
    @State private var showingWrapped = false
    /// Which month the Wrapped sheet shows; the new-month moment passes last month.
    @State private var wrappedMonth = Date()
    @AppStorage("startingMood") private var startingMood = ""
    @AppStorage("startingGenre") private var startingGenre = ""
    @AppStorage("startingDecade") private var startingDecade = ""
    /// Set by MainTabView when the 1st-of-month notification is tapped.
    @AppStorage("pendingWrappedOpen") private var pendingWrappedOpen = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No ratings yet",
                        emptyMessage: "Rate songs 👍 / 👎 to start your taste mirror.",
                        onRetry: { await model.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead) }
                    ) { mirror in
                        content(mirror)
                    }
                } else {
                    MusicLoadingView(title: nil, tint: Theme.Brand.gradient[0])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(wash)
            .overlay {
                if let badge = celebrating {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { dismissCelebration() }
                    BadgeCelebrationCard(
                        badge: badge,
                        accent: badge.definition.tint,
                        onDismiss: { dismissCelebration() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: celebrating)
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids, targetMonth: wrappedMonth)
            }
            .onAppear { consumePendingWrappedOpenIfNeeded() }
            .onChange(of: pendingWrappedOpen) { _, _ in consumePendingWrappedOpenIfNeeded() }
            .fullScreenCover(item: revealBinding) { request in
                ArchetypeRevealView(request: request) {
                    model?.acknowledgeReveal()
                }
            }
        }
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(entries: env.entries, ratings: env.ratings)
            }
            await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead)
            if badges == nil {
                badges = BadgesViewModel(
                    entries: env.entries,
                    listensStore: env.listensStore,
                    favoritesStore: env.favoritesStore,
                    ratingsStore: env.ratingsStore,
                    checkIns: env.checkIns
                )
            }
            await badges?.load()
        }
    }

    // MARK: archetype color bleed

    /// The whole screen washes with the archetype's color (neutral while forming).
    private var wash: some View {
        let c = washColors
        return LinearGradient(
            colors: [c[0].opacity(0.55),
                     (c.count > 1 ? c[1] : c[0]).opacity(0.22),
                     Color(.systemBackground)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: c)
    }

    private var washColors: [Color] {
        if case .loaded(let m) = model?.state {
            return (m.archetype ?? .theShapeshifter).colors
        }
        return TasteProfile.theShapeshifter.colors
    }

    private var celebrating: EarnedBadge? { badges?.newlyEarned.first }

    private var revealBinding: Binding<ArchetypeRevealRequest?> {
        Binding(
            get: { model?.reveal },
            set: { newValue in
                if newValue == nil, model?.reveal != nil {
                    model?.acknowledgeReveal()
                }
            }
        )
    }

    // MARK: content

    private func content(_ mirror: TasteMirror) -> some View {
        let accent = (mirror.archetype ?? .theShapeshifter).colors[0]
        return ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                recapMomentBanner
                TasteMirrorBoard(
                    mirror: mirror,
                    displayArchetype: mirror.archetype,
                    onRatingChanged: { Task { await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead) } },
                    onReplay: mirror.isArchetypeUnlocked ? { model?.replayReveal() } : nil,
                    revealCountdownText: countdownText(for: mirror)
                )
                badgesSummaryCard(accent: accent)
                historySummaryCard(accent: accent)
                tasteArcCard(accent: accent)
                wrappedButton(accent)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead)
            Haptics.tap()
        }
    }

    /// The hero's quiet countdown line; nil while locked or when a reveal is due.
    private func countdownText(for mirror: TasteMirror) -> String? {
        guard mirror.isArchetypeUnlocked, let next = model?.nextRevealDate else { return nil }
        let days = max(0, Calendar.current.dateComponents([.day], from: .now, to: next).day ?? 0)
        guard days > 0 else { return nil }
        return "Next reveal in \(days) day\(days == 1 ? "" : "s")"
    }

    @ViewBuilder
    private func historySummaryCard(accent: Color) -> some View {
        let entries = model?.historyEntries ?? []
        NavigationLink {
            HistoryView(
                entries: entries,
                accent: accent,
                onRatingChanged: { Task { await model?.load(favoriteIDs: env.favoritesStore.ids, startingRead: startingRead) } }
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular.tint(accent.opacity(0.14)), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR HISTORY")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(entries.isEmpty ? "No songs yet" : "\(entries.count) songs in your history")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.primary)
                    Text(historySummaryDetail(entries))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    @ViewBuilder
    private func badgesSummaryCard(accent: Color) -> some View {
        if let summary = badges?.summary, let list = badges?.badges {
            NavigationLink {
                BadgesView(badges: list, accent: accent)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rosette")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular.tint(accent.opacity(0.14)), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR BADGES")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Text("\(summary.earnedCount) earned · \(summary.closeCount) close")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.primary)
                        if let goal = summary.nearestGoal, let tier = goal.tier, let next = tier.nextThreshold {
                            Text("\(goal.definition.title) — \(max(0, next - goal.value)) to go")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: -8) {
                        ForEach(summary.peek) { badge in
                            Text(badge.isEarned ? badge.definition.symbol : "·")
                                .font(.system(size: 16))
                                .frame(width: 28, height: 28)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                                .opacity(badge.isEarned ? 1 : 0.45)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    private func historySummaryDetail(_ entries: [HistoryEntry]) -> String {
        guard let latest = entries.first?.entry else {
            return "Your daily songs will appear here once you start listening."
        }
        return "\(latest.title) · \(latest.date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var startingRead: StartingRead {
        StartingRead(
            mood: startingMood.nilIfEmpty,
            genre: startingGenre.nilIfEmpty,
            decade: startingDecade.nilIfEmpty
        )
    }

    @ViewBuilder
    private func tasteArcCard(accent: Color) -> some View {
        if let summary = model?.tasteArcSummary,
           let eras = model?.tasteEras,
           eras.count >= 2 {
            NavigationLink {
                TasteArcTimelineView(eras: eras, accent: accent)
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: 10) {
                        Text("YOUR TASTE ARC")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .center, spacing: 10) {
                        arcCapsule(summary.origin, icon: "flag.checkered", tint: .secondary)
                        arcDots(eras: eras, accent: accent)
                        arcCapsule(summary.current, icon: "sparkles", tint: accent)
                    }

                    Text(summary.feedback)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(Theme.Spacing.md)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    private func arcCapsule(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: 112)
        .glassPillStyle(tint: tint.opacity(0.12), horizontalInset: 9, verticalInset: 7)
    }

    private func arcDots(eras: [TasteEra], accent: Color) -> some View {
        let preview = Array(eras.prefix(5))
        return HStack(spacing: 4) {
            ForEach(preview) { era in
                Circle()
                    .fill(era.profile?.colors.first ?? accent.opacity(0.72))
                    .frame(width: era.kind == .current ? 12 : 9, height: era.kind == .current ? 12 : 9)
                    .overlay {
                        Circle().stroke(.white.opacity(0.55), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private func wrappedButton(_ accent: Color) -> some View {
        Button { openWrapped(for: Date()) } label: {
            Label("See your month", systemImage: "sparkles").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: monthly recap moment

    /// The month a recap moment refers to right now: during the first 4 days of
    /// a month the finished PREVIOUS month is the story; during the last 2 days
    /// the closing current month is. Otherwise there's no moment (nil).
    private var recapMoment: (month: Date, title: String)? {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.component(.day, from: now)

        if day <= 4, let previous = calendar.date(byAdding: .month, value: -1, to: now) {
            let name = previous.formatted(.dateTime.month(.wide))
            return (previous, "Your \(name) recap is ready")
        }
        if let range = calendar.range(of: .day, in: .month, for: now), day >= range.count - 1 {
            let name = now.formatted(.dateTime.month(.wide))
            return (now, "\(name) is a wrap — see your month")
        }
        return nil
    }

    /// A short-lived banner that makes the recap an event instead of a buried
    /// button (peak-end: the month's story lands while it's still fresh).
    @ViewBuilder private var recapMomentBanner: some View {
        if let moment = recapMoment {
            Button {
                openWrapped(for: moment.month)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.22), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(moment.title)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                        Text("Songs, artists, and streaks — wrapped up.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(Theme.Spacing.md)
                .background(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: .purple.opacity(0.25), radius: 12, y: 6)
            }
            .buttonStyle(PressableCardButtonStyle())
        }
    }

    private func openWrapped(for month: Date) {
        wrappedMonth = month
        showingWrapped = true
        Haptics.tap()
    }

    private func consumePendingWrappedOpenIfNeeded() {
        guard pendingWrappedOpen else { return }
        pendingWrappedOpen = false
        // Tapped from the 1st-of-month notification → last month's story.
        let month = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        openWrapped(for: month)
    }

    private func dismissCelebration() {
        badges?.acknowledgeCelebrations()
        Haptics.success()
    }

}

private struct HistoryView: View {
    let entries: [HistoryEntry]
    let accent: Color
    let onRatingChanged: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if entries.isEmpty {
                    Text("Your daily songs will appear here once you start listening.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    ForEach(entries) { item in
                        HistoryEntryRow(item: item, accent: accent, onRatingChanged: onRatingChanged)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("History")
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

private struct TasteArcTimelineView: View {
    let eras: [TasteEra]
    let accent: Color
    @State private var expandedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(eras) { era in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            expandedID = expandedID == era.id ? nil : era.id
                        }
                        Haptics.tap()
                    } label: {
                        TasteEraRow(
                            era: era,
                            accent: accent,
                            isExpanded: expandedID == era.id
                        )
                    }
                    .buttonStyle(PressableCardButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle("Taste Arc")
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

private struct TasteEraRow: View {
    let era: TasteEra
    let accent: Color
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 12) {
                marker

                VStack(alignment: .leading, spacing: 3) {
                    Text(kindLabel)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(era.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(era.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let driverLine = era.driverLine {
                        Text(driverLine)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    ForEach(era.songs.prefix(3)) { song in
                        HStack(spacing: 10) {
                            AlbumArtView(url: song.albumArtURL, cornerRadius: Theme.Radius.chip)
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(song.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.md)
        .background(rowMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(era.kind == .current ? accent.opacity(0.45) : .white.opacity(0.16), lineWidth: 1)
        }
    }

    private var marker: some View {
        Image(systemName: symbol)
            .font(.headline.weight(.bold))
            .foregroundStyle(markerTint)
            .frame(width: 38, height: 38)
            .glassEffect(.regular.tint(markerTint.opacity(0.14)), in: Circle())
    }

    private var rowMaterial: Material {
        era.kind == .current ? .regularMaterial : .ultraThinMaterial
    }

    private var markerTint: Color {
        era.profile?.colors.first ?? (era.kind == .onboarding ? .secondary : accent)
    }

    private var symbol: String {
        switch era.kind {
        case .onboarding: "flag.checkered"
        case .monthly: "circle.hexagongrid.fill"
        case .reveal: "sparkles"
        case .current: "location.fill"
        }
    }

    private var kindLabel: String {
        switch era.kind {
        case .onboarding: "ORIGIN"
        case .monthly: era.date.formatted(.dateTime.month(.wide).year())
        case .reveal: "REVEAL"
        case .current: "NOW"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
