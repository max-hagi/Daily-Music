//
//  Haptics.swift
//  Daily Music
//
//  One place to fire haptic feedback, gated by the user's "Haptic feedback"
//  Settings toggle. SettingsViewModel caches that toggle in UserDefaults under
//  `settings.hapticsEnabled`, so we read the same key here — every call site
//  honours the setting without needing the settings view model passed in.
//
//  Note: real haptics only fire on a physical device; these are no-ops in the
//  iOS Simulator.
//

import UIKit

enum Haptics {
    /// Mirrors the Settings "Haptic feedback" toggle. Defaults to on when unset.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.hapticsEnabled") as? Bool ?? true
    }

    /// A light physical "tap" — the default for selections, toggles, taps.
    @MainActor static func tap() { impact(.light) }

    /// A firmer thunk — good for destructive actions like removing a favorite.
    @MainActor static func thud() { impact(.medium) }

    @MainActor static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// The "selection moved" tick (e.g. flipping a pill or segment).
    @MainActor static func select() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Success / warning notification patterns.
    @MainActor static func success() { notify(.success) }
    @MainActor static func warning() { notify(.warning) }

    @MainActor static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    @MainActor @discardableResult
    static func playArchetypeReveal(pattern: ArchetypeRevealFlare.HapticPattern, reduceMotion: Bool) -> Task<Void, Never>? {
        guard isEnabled else { return nil }
        let schedule = ArchetypeHapticSchedule.crispReward(pattern: pattern, reduceMotion: reduceMotion)
        return Task { @MainActor in
            let start = Date()
            for beat in schedule.beats {
                guard !Task.isCancelled else { return }
                let delay = beat.time - Date().timeIntervalSince(start)
                if delay > 0 {
                    try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                }
                guard !Task.isCancelled else { return }
                playArchetypeBeat(beat.kind)
            }
        }
    }

    /// One immediate, archetype-flavored beat for the driver card landing.
    /// `crispReward`'s schedule is built for the reveal's multi-second arc;
    /// the board entrance needs its hit right when the #1 card settles.
    @MainActor static func driverReward(pattern: ArchetypeRevealFlare.HapticPattern) {
        switch pattern {
        case .none:          break
        case .sparkle:       impact(.light)
        case .softBloom:     impact(.soft)
        case .electric:      impact(.rigid)
        case .stageHit:      impact(.heavy)
        case .shadowPulse:   impact(.medium)
        case .triumph:       success()
        case .textureRumble: impact(.heavy)
        }
    }

    @MainActor private static func playArchetypeBeat(_ kind: ArchetypeHapticSchedule.Beat.Kind) {
        switch kind {
        case .anticipation:
            tap()
        case .flood:
            thud()
        case .accent:
            select()
        case .lockIn:
            success()
        }
    }
}
