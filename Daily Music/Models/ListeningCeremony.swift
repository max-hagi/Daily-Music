//
//  ListeningCeremony.swift
//  Daily Music
//
//  Pure rule for the "first-listen ceremony": auto-open the immersive Listening
//  screen only the first time a user encounters today's drop. Once they've heard
//  it, opening the app lands on Today (with a manual "Listen" toggle still there).
//

import Foundation

enum ListeningCeremony {
    /// `heardEntryID` is the stored uuidString of the last entry the user listened
    /// to (nil if none yet). Auto-open unless it already equals today's entry.
    static func shouldAutoOpen(todayEntryID: UUID, heardEntryID: String?) -> Bool {
        heardEntryID != todayEntryID.uuidString
    }

    /// How long Today settles on screen before the ceremony rises. Day one —
    /// arriving straight from the onboarding reveal — skips the beat so the
    /// arc (rate songs → archetype → first song) is unbroken.
    static func autoOpenDelay(launchingFromOnboarding: Bool) -> Duration {
        launchingFromOnboarding ? .zero : .seconds(0.6)
    }
}
