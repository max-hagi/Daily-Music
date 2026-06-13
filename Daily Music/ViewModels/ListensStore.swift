//
//  ListensStore.swift
//  Daily Music
//
//  One reactive source of truth for "what has the user heard, and when". Wraps
//  ListensService (the durable, cross-device store) but ALSO keeps a UserDefaults
//  cache so isHeard/status are correct SYNCHRONOUSLY on cold launch — otherwise
//  the listening ceremony could replay before the server load() returns.
//
//  markHeard is optimistic and first-listen-wins: the first mark sets heard_at,
//  repeats are no-ops. load() merges the server's rows in, keeping the earliest
//  timestamp. Supersedes CatchUpLog (it also migrates that old local set once).
//

import Foundation

@MainActor
@Observable
final class ListensStore {
    /// entry_id → earliest heard_at. Observed: views re-render on change.
    private(set) var heardAt: [UUID: Date] = [:]

    private let service: ListensService
    private let defaults: UserDefaults
    private static let cacheKey = "listens.heardAt"          // [uuidString: epochSeconds]
    private static let legacyKey = "vault.heardEntryIDs"     // old CatchUpLog set
    private static let migratedKey = "listens.migratedLegacy"

    init(service: ListensService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        hydrateFromCache()
        migrateLegacyIfNeeded()
    }

    func isHeard(_ entry: DailyEntry) -> Bool { heardAt[entry.id] != nil }

    func status(for entry: DailyEntry, asOf now: Date = Date()) -> ListenStatus {
        ListenStatus.of(entryDate: entry.date, heardAt: heardAt[entry.id], asOf: now)
    }

    /// Hero metric: records collected (every row with a heard_at).
    var collectionCount: Int { heardAt.count }

    /// Merge server rows into the cache, keeping the earliest heard_at per entry.
    func load() async {
        guard let remote = try? await service.heardEntries() else { return }
        for (id, date) in remote {
            heardAt[id] = heardAt[id].map { min($0, date) } ?? date
        }
        persist()
    }

    /// Optimistic, first-listen-wins. No-op if already heard (preserves heard_at).
    func markHeard(_ entry: DailyEntry) {
        guard heardAt[entry.id] == nil else { return }
        heardAt[entry.id] = Date()
        persist()
        Task { try? await service.markHeard(entryID: entry.id) }
    }

    private func hydrateFromCache() {
        let raw = defaults.dictionary(forKey: Self.cacheKey) as? [String: Double] ?? [:]
        heardAt = Dictionary(uniqueKeysWithValues: raw.compactMap { key, secs in
            UUID(uuidString: key).map { ($0, Date(timeIntervalSince1970: secs)) }
        })
    }

    private func persist() {
        let raw = Dictionary(uniqueKeysWithValues:
            heardAt.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
        defaults.set(raw, forKey: Self.cacheKey)
    }

    /// One-time: fold the old CatchUpLog set into listens (as catch-ups, heard now)
    /// and push each to the server so the records aren't lost on reinstall.
    private func migrateLegacyIfNeeded() {
        guard !defaults.bool(forKey: Self.migratedKey) else { return }
        let now = Date()
        for idString in defaults.stringArray(forKey: Self.legacyKey) ?? [] {
            guard let id = UUID(uuidString: idString), heardAt[id] == nil else { continue }
            heardAt[id] = now
            Task { try? await service.markHeard(entryID: id) }
        }
        persist()
        defaults.set(true, forKey: Self.migratedKey)
    }
}
