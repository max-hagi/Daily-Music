//
//  TasteComparison.swift
//  Daily Music
//
//  Pure "you vs them" engine: given two users' 👍/👎 maps and the shared catalog,
//  computes how much their tastes match, which songs they both love, and which
//  they clash on. No I/O — a sibling to TasteMirror. Fully unit-tested.
//

import Foundation

struct TasteComparison: Equatable {
    let coRatedCount: Int        // songs BOTH people rated
    let agreedCount: Int         // co-rated songs where the 👍/👎 sign matches
    let matchPercent: Int?       // agreed/coRated %, or nil until coRatedCount >= minShared
    let bothLoved: [DailyEntry]  // both 👍, in publishedHistory order
    let clashed: [DailyEntry]    // one 👍, one 👎, in publishedHistory order

    /// Below this many shared ratings, a match % is statistically meaningless.
    static let minShared = 3

    static func build(mine: [UUID: Int], theirs: [UUID: Int], history: [DailyEntry]) -> TasteComparison {
        // Counts come straight from the rating maps so the % stays accurate even
        // for songs that aren't in `history`.
        let sharedIDs = Set(mine.keys).intersection(theirs.keys)
        let agreed = sharedIDs.filter { isLike(mine[$0]) == isLike(theirs[$0]) }.count
        let coRated = sharedIDs.count
        let pct = coRated >= minShared
            ? Int((Double(agreed) / Double(coRated) * 100).rounded())
            : nil

        // Resolve the display lists by walking history (stable, newest-first order);
        // any shared id we can't resolve to an entry is simply skipped.
        var bothLoved: [DailyEntry] = []
        var clashed: [DailyEntry] = []
        for entry in history {
            guard let m = mine[entry.id], let t = theirs[entry.id] else { continue }
            if isLike(m) && isLike(t) {
                bothLoved.append(entry)
            } else if isLike(m) != isLike(t) {
                clashed.append(entry)
            }
        }

        return TasteComparison(coRatedCount: coRated, agreedCount: agreed,
                               matchPercent: pct, bothLoved: bothLoved, clashed: clashed)
    }

    /// A rating is a "like" when positive; anything else (−1, 0, missing) is not.
    private static func isLike(_ value: Int?) -> Bool { (value ?? 0) > 0 }
}
