//
//  InsightsViewModel.swift
//  Daily Music
//
//  Feeds the pure TasteMirror engine: joins the user's 👍/👎 ratings with the
//  tagged published catalog, then exposes the resulting mirror as a LoadState.
//  Degrades gracefully — missing sources yield an empty mirror, not an error.
//

import Foundation

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var state: LoadState<TasteMirror> = .loading

    private let entries: EntryService
    private let ratings: RatingService

    init(entries: EntryService, ratings: RatingService) {
        self.entries = entries
        self.ratings = ratings
    }

    func load() async {
        state = .loading
        let history = (try? await entries.publishedHistory()) ?? []
        let myRatings = (try? await ratings.myRatings()) ?? [:]
        let rated = history.compactMap { entry in
            myRatings[entry.id].map { RatedSong(entry: entry, value: $0) }
        }
        state = .loaded(TasteMirror.build(from: rated))
    }
}
