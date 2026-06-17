//
//  PullArmingRing.swift
//  Daily Music
//
//  The arming indicator for the Today ↔ Listening pull transition: a circular
//  progress ring that fills as the user pulls, with a center chevron that flips
//  when the ring is full ("armed"), plus a label that flips "Keep pulling…" →
//  "Release". Pure presentation — it owns no gesture logic; callers feed it
//  `progress`/`armed` from the gesture and a `label`/`tint` for context.
//

import SwiftUI

struct PullArmingRing: View {
    /// 0 = no pull, 1 = ring full.
    let progress: Double
    /// True once the ring is full — flips the chevron and turns the ring green.
    let armed: Bool
    /// Shown under the ring (already resolved to "Keep pulling…" / "Release …").
    let label: String
    /// Base color on the host surface (dark text on Today, white on the player).
    var tint: Color = .white
    /// Resting chevron direction: down for the pull-down enter, up for the swipe-up exit.
    var pointsUp: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let armedColor = Color(red: 0.16, green: 0.78, blue: 0.55)
    private var activeColor: Color { armed ? Self.armedColor : tint }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.0001, min(1, progress)))
                    .stroke(activeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))   // start the fill from the top
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(activeColor)
                    .rotationEffect(.degrees(chevronRotation))
            }
            .frame(width: 44, height: 44)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: armed)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(activeColor)
        }
        .opacity(progress > 0.02 ? 1 : 0)
        .accessibilityHidden(true)   // the labeled buttons remain the accessible path
    }

    private var chevronRotation: Double {
        let base = pointsUp ? 180.0 : 0.0
        return armed ? base + 180 : base
    }
}
