//
//  FavoritesStore.swift
//  Daily Music
//
//  One reactive source of truth for hearted entries so every screen updates
//  together. Wraps the FavoritesService (which does the actual storage) and
//  keeps an in-memory Set the SwiftUI views observe. Toggling is optimistic:
//  the UI flips immediately and rolls back if the write fails.
//

import Foundation

@MainActor
@Observable
final class FavoritesStore {
    private(set) var ids: Set<UUID> = []

    private let service: FavoritesService

    init(service: FavoritesService) {
        self.service = service
    }

    func load() async {
        ids = (try? await service.favoriteIDs()) ?? []
    }

    func isFavorite(_ entry: DailyEntry) -> Bool {
        ids.contains(entry.id)
    }

    func toggle(_ entry: DailyEntry) async {
        let wantFavorite = !ids.contains(entry.id)

        // Optimistic: update the UI first.
        if wantFavorite { ids.insert(entry.id) } else { ids.remove(entry.id) }

        do {
            try await service.setFavorite(wantFavorite, entryID: entry.id)
        } catch {
            // Roll back on failure.
            if wantFavorite { ids.remove(entry.id) } else { ids.insert(entry.id) }
        }
    }
}
