//
//  WrappedViewModel.swift
//  Daily Music
//
//  Builds a "your month" recap (Spotify-Wrapped style) from existing data — no
//  new backend. The peak-end / retrospective-narrative lever: a periodic,
//  shareable summary of what you discovered.
//

import Foundation

@MainActor
@Observable
final class WrappedViewModel {
    struct Recap {
        var monthName: String
        var songsHeard: Int
        var artistsDiscovered: Int
        var favourites: Int
        var topArtist: String?
        var topArtistPlays: Int
        var profile: TasteProfile
    }

    private(set) var state: LoadState<Recap> = .loading

    private let entries: EntryService
    private let checkIns: CheckInService
    private let ratings: RatingService

    init(entries: EntryService, checkIns: CheckInService, ratings: RatingService) {
        self.entries = entries
        self.checkIns = checkIns
        self.ratings = ratings
    }

    func load(favoriteIDs: Set<UUID>) async {
        if case .loaded = state {} else { state = .loading }

        do {
            let history = try await entries.publishedHistory()
            // check_ins is optional context; don't let a missing table fail the recap.
            let dates = (try? await checkIns.checkInDates()) ?? []

            let calendar = Calendar.current
            let now = Date()
            // Local helper: is this date in the current month/year? `toGranularity:
            // .month` means "same month AND year", ignoring the day.
            func thisMonth(_ date: Date) -> Bool {
                calendar.isDate(date, equalTo: now, toGranularity: .month)
            }

            // Songs this month that the user actually opened (in history AND checked in).
            let seen = history.filter {
                thisMonth($0.date) && dates.contains(calendar.startOfDay(for: $0.date))
            }
            // No qualifying songs → nothing to recap. (`; return` exits early.)
            guard !seen.isEmpty else { state = .empty; return }

            let entriesThisMonth = history.filter { thisMonth($0.date) }
            let top = Self.mostFrequentArtist(in: seen)

            // Archetype comes from the same rating-based taste mirror as Insights:
            // join the user's 👍/👎 ratings with the tagged catalog, then resolve.
            let myRatings = (try? await ratings.myRatings()) ?? [:]
            let rated = history.compactMap { entry in
                myRatings[entry.id].map { RatedSong(entry: entry, value: $0) }
            }
            let mirror = TasteMirror.build(from: rated + SeedRatings.load())

            state = .loaded(Recap(
                // `.formatted(.dateTime.month(.wide))` → full month name, e.g. "June".
                monthName: now.formatted(.dateTime.month(.wide)),
                songsHeard: seen.count,
                artistsDiscovered: Set(seen.map(\.artist)).count,
                favourites: entriesThisMonth.filter { favoriteIDs.contains($0.id) }.count,
                // `top` is an optional tuple; `?.artist` / `?? 0` unwrap it safely.
                topArtist: top?.artist,
                topArtistPlays: top?.count ?? 0,
                // `?? .balancedDefault` covers the "not enough ratings yet" case.
                profile: mirror.archetype ?? .balancedDefault
            ))
        } catch {
            state = .failed(error)
        }
    }

    // Returns the most-played artist and their play count, or nil if empty.
    // `Dictionary(grouping:by:)` buckets entries by artist; `.mapValues(\.count)`
    // turns each bucket (an array) into its length; `.max { … }` finds the biggest;
    // `.map { ... }` reshapes the winning (key, value) pair into a named tuple.
    private static func mostFrequentArtist(in entries: [DailyEntry]) -> (artist: String, count: Int)? {
        let tally = Dictionary(grouping: entries, by: \.artist).mapValues(\.count)
        return tally.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
}
