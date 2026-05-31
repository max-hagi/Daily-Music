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

    init(entries: EntryService, checkIns: CheckInService) {
        self.entries = entries
        self.checkIns = checkIns
    }

    func load(favoriteIDs: Set<UUID>) async {
        state = .loading
        do {
            let history = try await entries.publishedHistory()
            // check_ins is optional context; don't let a missing table fail the recap.
            let dates = (try? await checkIns.checkInDates()) ?? []

            let calendar = Calendar.current
            let now = Date()
            func thisMonth(_ date: Date) -> Bool {
                calendar.isDate(date, equalTo: now, toGranularity: .month)
            }

            let seen = history.filter {
                thisMonth($0.date) && dates.contains(calendar.startOfDay(for: $0.date))
            }
            guard !seen.isEmpty else { state = .empty; return }

            let entriesThisMonth = history.filter { thisMonth($0.date) }
            let top = Self.mostFrequentArtist(in: seen)

            state = .loaded(Recap(
                monthName: now.formatted(.dateTime.month(.wide)),
                songsHeard: seen.count,
                artistsDiscovered: Set(seen.map(\.artist)).count,
                favourites: entriesThisMonth.filter { favoriteIDs.contains($0.id) }.count,
                topArtist: top?.artist,
                topArtistPlays: top?.count ?? 0,
                profile: .from(seen: seen, favorites: favoriteIDs.count)
            ))
        } catch {
            state = .failed(error)
        }
    }

    private static func mostFrequentArtist(in entries: [DailyEntry]) -> (artist: String, count: Int)? {
        let tally = Dictionary(grouping: entries, by: \.artist).mapValues(\.count)
        return tally.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
}
