//
//  TasteSeedDeck.swift
//  Daily Music
//
//  Pure state machine for the onboarding card stack: which StarterPack song is
//  front, which are peeking behind it, and what's been judged so far. The view
//  (TasteSeedCardStack/TasteSeedView) renders this; persistence (SeedRatings)
//  and phase changes stay in TasteSeedView.
//

import Foundation

struct TasteSeedDeck {
    let songs: [DailyEntry]
    private(set) var index = 0
    private(set) var picks: [RatedSong] = []

    init(songs: [DailyEntry]) {
        self.songs = songs
    }

    /// The front card (nil once every song is judged).
    var current: DailyEntry? {
        index < songs.count ? songs[index] : nil
    }

    /// Front card plus up to two peeking behind it, front first.
    var upcoming: [DailyEntry] {
        guard index < songs.count else { return [] }
        return Array(songs[index..<min(index + 3, songs.count)])
    }

    var isComplete: Bool { index >= songs.count }

    var positionText: String {
        "\(min(index + 1, songs.count)) of \(songs.count)"
    }

    /// Record a judgment (+1 like / -1 dislike) for the front card and advance.
    mutating func judge(_ value: Int) {
        guard let song = current else { return }
        picks.append(RatedSong(entry: song, value: value))
        index += 1
    }
}
