//
//  SleeveTreatment.swift
//  Daily Music
//
//  How a sleeve LOOKS, derived from its ListenStatus. The status has 5 cases;
//  the sleeve renders 4 visual treatments (spec §10.3). This is the collapse:
//  the two "invitation" states (today's unheard drop, and a still-rescuable
//  missed one) both render `pending` — a rescuable drop is an invitation, never
//  a gap (spec §1). The "still available" tap affordance is the crate's job, off
//  the raw ListenStatus; the sleeve only carries the look.
//
//  Treatment is encoded by sleeve TREATMENT, not hue — album art is already every
//  colour, so a hue overlay would fight it. Hue lives only on calendar dots and
//  the tab badge (see ListenStatus.indicatorColor).
//

import Foundation

enum SleeveTreatment: Equatable {
    case pending      // today's drop, or still rescuable — an invitation
    case mint         // heard on its own day — the reward state, looks the best
    case secondhand   // caught up within the window — a lightly used copy
    case salvaged     // heard after the window closed — a battered, reclaimed copy
    case missing      // window closed, never heard — an empty sleeve

    init(_ status: ListenStatus) {
        switch status {
        case .unheard, .rescuable: self = .pending
        case .heardSameDay:        self = .mint
        case .caughtUp:            self = .secondhand
        case .rescued:             self = .salvaged
        case .missed:              self = .missing
        }
    }
}
