//
//  FavoritesOrderStore.swift
//  Daily Music
//
//  Local-only manual ordering for the Favorites collection. Until the user drags
//  to reorder, there is no saved order and favorites render in the order given
//  (newest-first). After the first reorder we persist an explicit id list to
//  UserDefaults; newly hearted songs prepend on top, un-hearted ones drop out.
//

import Foundation

@MainActor
@Observable
final class FavoritesOrderStore {
    private let defaults: UserDefaults
    private let key = "favorites.manual_order.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved manual order, or nil if the user hasn't reordered yet.
    private var savedOrder: [UUID]? {
        guard let strings = defaults.array(forKey: key) as? [String] else { return nil }
        return strings.compactMap(UUID.init(uuidString:))
    }

    /// Pure. No saved order → `favorites` unchanged. Otherwise: favorites present
    /// in the saved list follow its order; favorites NOT in it (newly hearted)
    /// prepend on top in their incoming order; saved ids absent from `favorites`
    /// are dropped.
    func arranged(_ favorites: [DailyEntry]) -> [DailyEntry] {
        guard let order = savedOrder else { return favorites }
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        let known = favorites
            .filter { position[$0.id] != nil }
            .sorted { position[$0.id]! < position[$1.id]! }
        let fresh = favorites.filter { position[$0.id] == nil }
        return fresh + known
    }

    /// Persist an explicit manual order. Stores exactly `ids`, so passing the live
    /// arranged ids both establishes the order and trims any stale ids.
    func commit(_ ids: [UUID]) {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }
}
