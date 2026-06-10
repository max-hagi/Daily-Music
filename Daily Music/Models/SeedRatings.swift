//
//  SeedRatings.swift
//  Daily Music
//
//  Persists the onboarding taste-seed picks (👍/👎 on the bundled StarterPack) so
//  they seed the user's REAL taste mirror — the profile is established at onboarding
//  and then evolves as daily ratings accumulate. Stored locally (per device) in
//  UserDefaults; the starter songs aren't catalog entries, so they never touch the
//  song_ratings table — they're merged into the mirror computation in code.
//

import Foundation

enum SeedRatings {
    private static let key = "tasteSeedRatings"

    static func save(_ ratings: [RatedSong]) {
        let now = Date()
        let stamped = ratings.map {
            RatedSong(entry: $0.entry, value: $0.value, isFavorite: $0.isFavorite, ratedAt: $0.ratedAt ?? now)
        }
        guard let data = try? JSONEncoder().encode(stamped) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> [RatedSong] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let ratings = try? JSONDecoder().decode([RatedSong].self, from: data) else { return [] }
        return ratings
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
