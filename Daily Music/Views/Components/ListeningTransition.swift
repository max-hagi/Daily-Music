//
//  ListeningTransition.swift
//  Daily Music
//
//  Pure, view-free math for the Today ↔ Listening interactive transition.
//  Kept separate so the easy-to-get-wrong commit/cancel decision and the
//  gesture→arm-progress mappings are unit-tested without spinning up a view.
//
//  Model: a pull "arms" a ring indicator (0…1). Releasing while the ring is full
//  commits the takeover; a fast flick commits early; anything else snaps back.
//

import CoreGraphics

enum ImmersiveSection: Hashable {
    case song
    case journal
}

enum TodayListeningTransitionPhase {
    case enteringListening
    case dismissingListening
}

enum TodayListeningTransitionPolicy {
    static func backingSection(for phase: TodayListeningTransitionPhase) -> ImmersiveSection {
        switch phase {
        case .enteringListening, .dismissingListening:
            return .song
        }
    }
}

enum ListeningHostPhase: Equatable {
    case idle
    case preparing
    case presenting
    case presented
    case dismissing
}

enum ListeningHostEvent {
    case presentRequested
    case hostPrepared
    case presentationCompleted
    case dismissRequested
    case dismissalCompleted
    case cancelled
}

enum ListeningHostEffect: Equatable {
    case none
    case prepareHost
    case animateIn
    case animateOut
    case detachHost
}

struct ListeningHostMachine {
    private(set) var phase: ListeningHostPhase

    init(phase: ListeningHostPhase = .idle) {
        self.phase = phase
    }

    var isMounted: Bool { phase != .idle }
    var isReady: Bool { phase == .presented }

    mutating func handle(_ event: ListeningHostEvent) -> ListeningHostEffect {
        switch (phase, event) {
        case (.idle, .presentRequested):
            phase = .preparing
            return .prepareHost
        case (.preparing, .hostPrepared):
            phase = .presenting
            return .animateIn
        case (.presenting, .presentationCompleted):
            phase = .presented
            return .none
        case (.presented, .dismissRequested):
            phase = .dismissing
            return .animateOut
        case (.dismissing, .dismissalCompleted):
            phase = .idle
            return .detachHost
        case (.preparing, .cancelled),
             (.presenting, .cancelled),
             (.presented, .cancelled),
             (.dismissing, .cancelled):
            phase = .idle
            return .detachHost
        default:
            return .none
        }
    }
}

enum TransitionOutcome: Equatable {
    case commit   // finish the takeover
    case cancel   // snap back
}

enum TransitionResolver {
    /// Velocity (points/sec, toward the intent) that commits even before the ring fills.
    static let commitVelocity = 800.0

    /// Commit once the ring is full, or on a fast flick; otherwise cancel.
    /// - Parameters:
    ///   - armProgress: 0 = no pull, 1 = ring full.
    ///   - velocity: points/sec; positive = pulling further toward the intent.
    static func resolve(armProgress: Double, velocity: Double) -> TransitionOutcome {
        if velocity >= commitVelocity { return .commit }
        return armProgress >= 1 ? .commit : .cancel
    }
}

enum TransitionMath {
    /// Over-pull distance (points) that fills the ring on enter. Tuned to a
    /// pull-to-refresh-sized tug — the journal ScrollView's rubber-band resists and
    /// snaps back, so a larger span never reaches the commit before springing back.
    static let pullSpan: Double = 80
    /// Up-drag span as a fraction of screen height that fills the ring on exit.
    static let dismissHeightFraction: Double = 0.28

    /// Journal over-pull (points, positive = pulled past the top) → ring fill 0…1.
    static func armProgress(forPull pull: Double) -> Double {
        clamp(pull / pullSpan)
    }

    /// Upward dismiss-drag (points, positive = dragged up) → ring fill 0…1, scaled to height.
    static func armProgress(forDrag drag: Double, height: CGFloat) -> Double {
        guard height > 0 else { return 0 }
        return clamp(drag / (Double(height) * dismissHeightFraction))
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
