//
//  ListeningTransition.swift
//  Daily Music
//
//  Pure, view-free math for the Today ↔ Listening interactive transition.
//  Kept separate so the easy-to-get-wrong commit/cancel decision and the
//  gesture→progress mappings are unit-tested without spinning up a SwiftUI view.
//

import CoreGraphics

enum TransitionOutcome: Equatable {
    case commit   // finish the gesture's intent
    case cancel   // snap back to where the gesture started
}

enum TransitionResolver {
    /// Fraction of the gesture's intent that must be reached to commit on release alone.
    static let commitFraction = 0.4
    /// Velocity (points/sec, toward the intent) that commits even below `commitFraction`;
    /// the same magnitude in reverse cancels even above it.
    static let commitVelocity = 800.0

    /// Decide whether a released gesture should complete or snap back.
    /// - Parameters:
    ///   - committedFraction: 0 = at the gesture's start, 1 = intent fully achieved.
    ///   - velocity: points/sec; positive = moving toward the intent.
    static func resolve(committedFraction: Double, velocity: Double) -> TransitionOutcome {
        if velocity >= commitVelocity { return .commit }
        if velocity <= -commitVelocity { return .cancel }
        return committedFraction >= commitFraction ? .commit : .cancel
    }
}

enum TransitionMath {
    /// Over-pull distance (points) that maps to a full enter (progress 1).
    static let pullSpan: Double = 160
    /// Dismiss-drag span as a fraction of the screen height (so it feels the same on any device).
    static let dismissHeightFraction: Double = 0.35

    /// Journal over-pull (points, positive = pulled down past the top) → 0...1.
    static func progress(forPull pull: Double) -> Double {
        clamp(pull / pullSpan)
    }

    /// Downward dismiss-drag (points, positive = down) → 0...1, scaled to screen height.
    static func dismissFraction(forDrag drag: Double, height: CGFloat) -> Double {
        guard height > 0 else { return 0 }
        let span = Double(height) * dismissHeightFraction
        return clamp(drag / span)
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
}
