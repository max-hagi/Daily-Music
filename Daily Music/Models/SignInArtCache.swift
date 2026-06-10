//
//  SignInArtCache.swift
//  Daily Music
//
//  Persists the sign-in cover wall's art URLs so the backdrop renders instantly
//  on later launches instead of waiting on a Supabase history fetch. The images
//  themselves are cached by URLSession/AsyncImage; this only remembers which
//  covers to show. Refreshed in the background after each successful fetch.
//

import Foundation

enum SignInArtCache {
    private static let key = "signInArtURLs"

    static func load(defaults: UserDefaults = .standard) -> [URL] {
        (defaults.stringArray(forKey: key) ?? []).compactMap(URL.init(string:))
    }

    static func save(_ urls: [URL], defaults: UserDefaults = .standard) {
        defaults.set(urls.map(\.absoluteString), forKey: key)
    }
}
