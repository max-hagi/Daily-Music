//
//  InsightsViewModel.swift
//  Daily Music
//
//  Feeds the pure TasteMirror engine: joins the user's 👍/👎 ratings with the
//  tagged published catalog, then exposes the resulting mirror as a LoadState.
//  Degrades gracefully — missing sources yield an empty mirror, not an error.
//

import Foundation

struct HistoryEntry: Identifiable {
    let entry: DailyEntry
    var rating: Int?   // +1 liked / -1 disliked / nil unrated
    var id: UUID { entry.id }
}

struct TasteEra: Identifiable, Equatable {
    enum Kind: Equatable {
        case onboarding
        case monthly
        case reveal
        case current
    }

    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let subtitle: String
    let profile: TasteProfile?
    let mirror: TasteMirror?
    let driverLine: String?
    let songs: [DailyEntry]
}

struct TasteArcSummary: Equatable {
    let origin: String
    let current: String
    let feedback: String
}

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var state: LoadState<TasteMirror> = .loading
    private(set) var stableArchetype: TasteProfile?
    private(set) var nextRevealDate: Date?
    private(set) var historyEntries: [HistoryEntry] = []
    private(set) var tasteEras: [TasteEra] = []
    private(set) var tasteArcSummary: TasteArcSummary?
    var reveal: ArchetypeRevealRequest?

    private let entries: EntryService
    private let ratings: RatingService
    private let snapshotStore: ArchetypeSnapshotStore
    private let defaults: UserDefaults

    init(
        entries: EntryService,
        ratings: RatingService,
        snapshotStore: ArchetypeSnapshotStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.entries = entries
        self.ratings = ratings
        self.snapshotStore = snapshotStore ?? ArchetypeSnapshotStore()
        self.defaults = defaults
        let snapshot = self.snapshotStore.load()
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
    }

    func load(favoriteIDs: Set<UUID> = [], startingRead: StartingRead = StartingRead()) async {
        if case .loaded = state {} else { state = .loading }

        let history = (try? await entries.publishedHistory()) ?? []
        let myRatings = (try? await ratings.myRatings()) ?? [:]
        // Thumbed songs carry their heart; favorited-but-unrated songs join as
        // heart-only signal (value 0) — the scorer hears them, the tiles don't.
        let rated = history.compactMap { entry -> RatedSong? in
            let value = myRatings[entry.id]
            let fav = favoriteIDs.contains(entry.id)
            guard value != nil || fav else { return nil }
            return RatedSong(entry: entry, value: value ?? 0, isFavorite: fav)
        }
        // Onboarding seed is a cold-start fallback, not a current/month signal.
        // Once real daily ratings exist, the user's live mirror comes from those.
        let mirror = Self.buildCurrentMirror(
            realRated: rated,
            seedRatings: SeedRatings.load(),
            incumbentID: snapshotStore.load().stableArchetypeID
        )
        historyEntries = history
            .sorted { $0.date > $1.date }
            .map { HistoryEntry(entry: $0, rating: myRatings[$0.id]) }
        let snapshot = snapshotStore.evaluate(
            candidate: mirror.archetype,
            hasCompletedOnboarding: defaults.bool(forKey: "hasCompletedOnboarding")
        )
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
        nextRevealDate = snapshot.lastEvaluatedAt.map { $0.addingTimeInterval(ArchetypeSnapshotEvaluator.cadence) }
        tasteEras = Self.buildTasteEras(
            history: history,
            ratings: myRatings,
            favoriteIDs: favoriteIDs,
            startingRead: startingRead,
            currentMirror: mirror,
            snapshot: snapshot
        )
        tasteArcSummary = Self.buildTasteArcSummary(
            startingRead: startingRead,
            currentMirror: mirror,
            eras: tasteEras
        )
        reveal = makeReveal(from: snapshot, mirror: mirror)
        state = .loaded(mirror)
    }

    func replayReveal() {
        guard case .loaded(let mirror) = state,
              let profile = stableArchetype ?? mirror.archetype else { return }
        reveal = ArchetypeRevealRequest(
            previousProfile: nil,
            newProfile: profile,
            reason: revealReason(for: mirror, fallback: profile),
            kind: .firstUnlock
        )
    }

    func acknowledgeReveal() {
        let snapshot = snapshotStore.acknowledgeReveal()
        stableArchetype = TasteProfile.profile(id: snapshot.stableArchetypeID)
        reveal = nil
    }

    private func makeReveal(from snapshot: ArchetypeSnapshot, mirror: TasteMirror) -> ArchetypeRevealRequest? {
        guard let pending = snapshot.pendingRevealArchetypeID,
              let newProfile = TasteProfile.profile(id: pending) else { return nil }
        let previous = TasteProfile.profile(id: snapshot.previousArchetypeID)
        let kind: ArchetypeRevealRequest.Kind = previous == nil ? .firstUnlock : .weeklyChange
        return ArchetypeRevealRequest(
            previousProfile: previous,
            newProfile: newProfile,
            reason: revealReason(for: mirror, fallback: newProfile),
            kind: kind
        )
    }

    private func revealReason(for mirror: TasteMirror, fallback: TasteProfile) -> String {
        if let evidence = mirror.evidence,
           let receipts = archetypeReceiptsCopy(evidence: evidence, isCurrentUser: true) {
            return receipts
        }
        guard let modifier = mirror.winningModifier else {
            if let mood = mirror.mood.topStandout?.name.lowercased() {
                return "Your \(mood) picks are shaping the center of your taste."
            }
            return "Your recent ratings shifted the shape of your taste."
        }

        switch modifier.dimensionID {
        case "decade":
            return "\(modifier.categoryName) songs are glowing brighter in your daily picks."
        case "theme":
            return "Songs about \(modifier.categoryName.lowercased()) are rising through your taste."
        case "genre":
            return "\(modifier.categoryName) tracks are taking the lead in your mirror."
        default:
            return "\(fallback.title) is where your taste is landing this week."
        }
    }
}

extension InsightsViewModel {
    nonisolated static func buildCurrentMirror(
        realRated: [RatedSong],
        seedRatings: [RatedSong],
        incumbentID: String? = nil
    ) -> TasteMirror {
        TasteMirror.build(
            from: realRated.isEmpty ? seedRatings : realRated,
            incumbentID: incumbentID
        )
    }

    nonisolated static func buildTasteEras(
        history: [DailyEntry],
        ratings: [UUID: Int],
        favoriteIDs: Set<UUID>,
        startingRead: StartingRead,
        currentMirror: TasteMirror,
        snapshot: ArchetypeSnapshot,
        calendar: Calendar = .current
    ) -> [TasteEra] {
        let sortedHistory = history.sorted { $0.date > $1.date }
        let latestDate = sortedHistory.first?.date ?? Date()
        let currentMonth = calendar.dateInterval(of: .month, for: latestDate)?.start
        var eras: [TasteEra] = []

        let currentProfile = currentMirror.archetype
            ?? TasteProfile.profile(id: snapshot.stableArchetypeID)
            ?? TasteProfile.theShapeshifter
        eras.append(TasteEra(
            id: "current-\(currentProfile.id)-\(Self.monthID(for: latestDate, calendar: calendar))",
            kind: .current,
            date: latestDate,
            title: currentProfile.title,
            subtitle: "Where your taste is landing now",
            profile: currentProfile,
            mirror: currentMirror,
            driverLine: driverLine(for: currentMirror),
            songs: signalSongs(for: currentMirror)
        ))

        if let revealID = snapshot.lastRevealedArchetypeID,
           let revealed = TasteProfile.profile(id: revealID),
           let date = snapshot.lastEvaluatedAt {
            eras.append(TasteEra(
                id: "reveal-\(revealID)-\(Int(date.timeIntervalSince1970))",
                kind: .reveal,
                date: date,
                title: "Reveal: \(revealed.title)",
                subtitle: "A real archetype reveal milestone",
                profile: revealed,
                mirror: nil,
                driverLine: nil,
                songs: []
            ))
        }

        let grouped = Dictionary(grouping: sortedHistory) { entry in
            calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
        }

        let monthly = grouped.compactMap { monthStart, entries -> TasteEra? in
            if let currentMonth,
               calendar.isDate(monthStart, equalTo: currentMonth, toGranularity: .month) {
                return nil
            }

            let rated = entries.compactMap { entry -> RatedSong? in
                let value = ratings[entry.id]
                let favorite = favoriteIDs.contains(entry.id)
                guard value != nil || favorite else { return nil }
                return RatedSong(entry: entry, value: value ?? 0, isFavorite: favorite)
            }
            guard rated.count >= 3 else { return nil }

            let mirror = TasteMirror.build(from: rated)
            let monthName = monthStart.formatted(.dateTime.month(.wide))
            let subtitle = monthlySubtitle(for: mirror)
            return TasteEra(
                id: "month-\(Self.monthID(for: monthStart, calendar: calendar))",
                kind: .monthly,
                date: monthStart,
                title: "\(monthName) era",
                subtitle: subtitle,
                profile: mirror.archetype,
                mirror: mirror,
                driverLine: driverLine(for: mirror),
                songs: signalSongs(
                    for: mirror,
                    fallback: rated.sorted { $0.entry.date > $1.entry.date }
                )
            )
        }
        .sorted { $0.date > $1.date }
        eras.append(contentsOf: monthly)

        if !startingRead.isEmpty {
            let parts: [String] = [startingRead.mood, startingRead.genre, startingRead.decade].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            let originDate = sortedHistory.last?.date.addingTimeInterval(-1) ?? Date.distantPast
            eras.append(TasteEra(
                id: "onboarding-\(parts.joined(separator: "-").lowercased())",
                kind: .onboarding,
                date: originDate,
                title: "You started here",
                subtitle: parts.joined(separator: " · "),
                profile: nil,
                mirror: nil,
                driverLine: "Your first read set the baseline for the arc.",
                songs: []
            ))
        }

        return eras
    }

    nonisolated private static func signalSongs(
        for mirror: TasteMirror,
        fallback: [RatedSong]? = nil
    ) -> [DailyEntry] {
        if let fact = mirror.evidence?.facts.first {
            let matching = mirror.songs(forDimensionID: fact.dimensionID, category: fact.category)
            if !matching.isEmpty {
                return matching.prefix(3).map(\.entry)
            }
        }

        return (fallback ?? mirror.ratedSongs)
            .prefix(3)
            .map(\.entry)
    }

    nonisolated static func buildTasteArcSummary(
        startingRead: StartingRead,
        currentMirror: TasteMirror,
        eras: [TasteEra]
    ) -> TasteArcSummary? {
        guard !eras.isEmpty else { return nil }
        let originParts: [String] = [startingRead.mood, startingRead.genre, startingRead.decade].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        let origin = originParts.isEmpty ? "First era" : originParts.joined(separator: " · ")
        let current = (currentMirror.archetype ?? .theShapeshifter).title
        let feedback: String

        if let start = startingRead.mood,
           let now = currentMirror.mood.topStandout?.name,
           !start.isEmpty,
           start != now {
            feedback = "You moved from \(start) toward \(now) picks."
        } else if let start = startingRead.genre,
                  let now = currentMirror.genre.topStandout?.name,
                  !start.isEmpty,
                  start != now {
            feedback = "Your center shifted from \(start) into \(now)."
        } else if let energy = currentMirror.energy.leanLabel {
            feedback = "Your recent picks lean \(energy.lowercased())."
        } else {
            feedback = "Your taste has been building new shape since day one."
        }

        return TasteArcSummary(origin: origin, current: current, feedback: feedback)
    }

    nonisolated private static func monthID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    nonisolated private static func monthlySubtitle(for mirror: TasteMirror) -> String {
        if let profile = mirror.archetype {
            return profile.title
        }
        if let mood = mirror.mood.topStandout?.name {
            return "\(mood) shaped this month"
        }
        if let genre = mirror.genre.topStandout?.name {
            return "\(genre) shaped this month"
        }
        if let energy = mirror.energy.leanLabel {
            return "\(energy) energy"
        }
        return "A small but real pocket of taste"
    }

    nonisolated private static func driverLine(for mirror: TasteMirror) -> String? {
        if let evidence = mirror.evidence,
           let receipts = archetypeReceiptsCopy(evidence: evidence, isCurrentUser: true) {
            return receipts
        }
        if let modifier = mirror.winningModifier {
            return "\(modifier.categoryName) shaped this era."
        }
        if let mood = mirror.mood.topStandout?.name {
            return "\(mood) picks set the tone."
        }
        if let genre = mirror.genre.topStandout?.name {
            return "\(genre) kept showing up."
        }
        if let energy = mirror.energy.leanLabel {
            return "\(energy) energy carried the month."
        }
        return nil
    }
}
