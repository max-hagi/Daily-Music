//
//  NewDropPromptRule.swift
//  Daily Music
//
//  Pure rule for the in-app "your song of the day is ready" pop-up. It appears
//  when today's drop is still uncollected and the user hasn't dismissed it this
//  session. Once collected (or dismissed), the song zone's own affordances take
//  over and we don't nag again.
//

import Foundation

enum NewDropPromptRule {
    static func shouldShow(isCollected: Bool, dismissedThisSession: Bool) -> Bool {
        !isCollected && !dismissedThisSession
    }
}
