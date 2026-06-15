//
//  PersonName.swift
//  Daily Music
//
//  Shared rule for the friendly first-name greeting, so Today and onboarding
//  ("You're all set, Max") agree. Strips any email @domain, then takes the
//  first whitespace-separated word.
//

import Foundation

enum PersonName {
    /// The first name to greet with, or nil when there's nothing usable.
    static func firstName(from raw: String) -> String? {
        let beforeAt = raw.split(separator: "@").first.map(String.init) ?? raw
        let firstWord = beforeAt
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstWord, !firstWord.isEmpty else { return nil }
        return firstWord
    }
}
