//
//  UserSettings.swift
//  Daily Music
//
//  The user's synced preferences — the JSONB blob stored in their `profiles`
//  row. A custom decoder uses decodeIfPresent with defaults so adding a new
//  setting never breaks decoding of older saved rows (forward/backward compat).
//

import Foundation

struct UserSettings: Codable, Equatable {
    var reminderEnabled = false
    /// Reminder time is stored as hour/minute (a time-of-day), not a full Date,
    /// to avoid JSON date-encoding ambiguity.
    var reminderHour = 8
    var reminderMinute = 0
    var listeningMode = "Balanced"
    var startTab = "Today"
    var hapticsEnabled = true
    var showExplicitSongs = true
    var allowPersonalizedInsights = true
    var includeJournalInShares = true
    var includeWatermarkInShares = true
    var weeklyRecapEnabled = true

    init() {}

    enum CodingKeys: String, CodingKey {
        case reminderEnabled, reminderHour, reminderMinute, listeningMode, startTab
        case hapticsEnabled, showExplicitSongs, allowPersonalizedInsights
        case includeJournalInShares, includeWatermarkInShares, weeklyRecapEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var s = UserSettings()
        s.reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? s.reminderEnabled
        s.reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? s.reminderHour
        s.reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? s.reminderMinute
        s.listeningMode = try c.decodeIfPresent(String.self, forKey: .listeningMode) ?? s.listeningMode
        s.startTab = try c.decodeIfPresent(String.self, forKey: .startTab) ?? s.startTab
        s.hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? s.hapticsEnabled
        s.showExplicitSongs = try c.decodeIfPresent(Bool.self, forKey: .showExplicitSongs) ?? s.showExplicitSongs
        s.allowPersonalizedInsights = try c.decodeIfPresent(Bool.self, forKey: .allowPersonalizedInsights) ?? s.allowPersonalizedInsights
        s.includeJournalInShares = try c.decodeIfPresent(Bool.self, forKey: .includeJournalInShares) ?? s.includeJournalInShares
        s.includeWatermarkInShares = try c.decodeIfPresent(Bool.self, forKey: .includeWatermarkInShares) ?? s.includeWatermarkInShares
        s.weeklyRecapEnabled = try c.decodeIfPresent(Bool.self, forKey: .weeklyRecapEnabled) ?? s.weeklyRecapEnabled
        self = s
    }
}
