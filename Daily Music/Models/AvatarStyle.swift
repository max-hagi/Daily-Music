//
//  AvatarStyle.swift
//  Daily Music
//
//  Pure helpers for the initials-avatar fallback: derive up to two initials from
//  a name, and pick a stable color palette from a name via a small string hash
//  (djb2) so a given name always gets the same color.
//

import Foundation

enum AvatarStyle {
    /// Up to two uppercase initials, or "?" when there's no usable name.
    static func initials(from name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let letters = trimmed.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.map(String.init).joined().uppercased()
    }

    /// Deterministic palette index in 0..<paletteCount for a given name.
    static func paletteIndex(for name: String?, paletteCount: Int) -> Int {
        guard paletteCount > 0 else { return 0 }
        var hash = 5381
        for byte in (name ?? "").lowercased().utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)   // &+ = overflow-safe add
        }
        return (hash & Int.max) % paletteCount          // mask → non-negative, no abs() trap
    }
}
