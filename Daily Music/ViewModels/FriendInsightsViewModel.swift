//
//  FriendInsightsViewModel.swift
//  Daily Music
//
//  Builds a friend's read-only taste mirror (their ratings joined with the shared
//  catalog) and the "you vs them" comparison (their ratings vs mine). Reuses the
//  pure TasteMirror + TasteComparison engines. Degrades gracefully — a missing
//  source yields an empty mirror / zeroed comparison rather than an error.
//

import Foundation

@MainActor
@Observable
final class FriendInsightsViewModel {
    struct Result: Equatable {
        let mirror: TasteMirror
        let comparison: TasteComparison
    }

    private(set) var state: LoadState<Result> = .loading

    private let entries: EntryService
    private let ratings: RatingService
    private let friends: FriendService

    init(entries: EntryService, ratings: RatingService, friends: FriendService) {
        self.entries = entries
        self.ratings = ratings
        self.friends = friends
    }

    func load(friendID: UUID) async {
        if case .loaded = state {} else { state = .loading }

        let history = (try? await entries.publishedHistory()) ?? []
        let theirs = (try? await friends.friendRatings(friendID: friendID)) ?? [:]
        let mine = (try? await ratings.myRatings()) ?? [:]

        let theirRated = history.compactMap { entry in
            theirs[entry.id].map { RatedSong(entry: entry, value: $0) }
        }
        let mirror = TasteMirror.build(from: theirRated)
        let comparison = TasteComparison.build(mine: mine, theirs: theirs, history: history)
        state = .loaded(Result(mirror: mirror, comparison: comparison))
    }
}
