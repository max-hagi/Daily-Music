//
//  ListensService.swift
//  Daily Music
//
//  Records the first time a user hears each entry. The seam deals in entry IDs
//  and their heard-at timestamps; ListenStatus turns (entry.date, heard_at) into
//  display state. Mirrors FavoritesService — RLS scopes everything to the user.
//

import Foundation

protocol ListensService {
    /// entry_id → the earliest time the user heard it.
    func heardEntries() async throws -> [UUID: Date]
    /// Insert-if-absent (first listen wins). A repeat call must NOT move heard_at.
    func markHeard(entryID: UUID) async throws
}

// `actor` serializes access to `heard` with no locks (see MockFavoritesService).
actor MockListensService: ListensService {
    private var heard: [UUID: Date] = [:]

    func heardEntries() async throws -> [UUID: Date] { heard }

    func markHeard(entryID: UUID) async throws {
        // First-listen-wins: only the first mark sets the timestamp.
        if heard[entryID] == nil { heard[entryID] = Date() }
    }
}
