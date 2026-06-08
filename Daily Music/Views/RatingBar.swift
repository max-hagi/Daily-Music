//
//  RatingBar.swift
//  Daily Music
//
//  The everyday taste judgment: 👍 / 👎 on a song, as two Liquid Glass circles.
//  Reads from and writes to RatingsStore — the shared @Observable cache — so every
//  instance across the app (Today, Vault, entry detail) reflects the same value
//  instantly when any one of them changes. No per-view RatingModel needed.
//
//  Idle = clear interactive glass tinted by the artwork accent; tapping fills the
//  circle GREEN (like) or RED (dislike). Three states (like/dislike/none); tapping
//  the active one clears it. Optimistic + haptic.
//

import SwiftUI

struct RatingBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]
    var controlSize: CGFloat = 52
    var symbolSize: CGFloat = 20
    var spacing: CGFloat = 12
    var isReadOnly = false

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // GlassEffectContainer lets the two circles share one glass "pour" so they
        // refract together and morph fluidly when tapped (iOS 26 Liquid Glass).
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                circle(value: 1,  symbol: "hand.thumbsup.fill",   tint: .green, label: "Like")
                circle(value: -1, symbol: "hand.thumbsdown.fill", tint: .red,   label: "Dislike")
            }
        }
    }

    private func circle(value: Int, symbol: String, tint: Color, label: String) -> some View {
        let selected = myRating == value
        return Button {
            guard !isReadOnly, !isGuestSession else { return }
            Haptics.tap()
            Task { await env.ratingsStore.setRating(selected ? nil : value, entryID: entry.id) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .bold))
                // White on the saturated fill when chosen; the accent when idle.
                .foregroundStyle(selected ? .white : readOnlyTint)
                .frame(width: controlSize, height: controlSize)
        }
        .buttonStyle(.plain)
        // Transparent CLEAR Liquid Glass that lets the artwork show through; fills
        // green/red only when chosen. `.interactive()` adds the touch-reactive wobble.
        .glassEffect(selected ? .clear.tint(tint).interactive()
                              : .clear.interactive(),
                     in: .circle)
        .scaleEffect(selected && !reduceMotion ? 1.06 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.6), value: selected)
        .disabled(isReadOnly)
        .opacity(isReadOnly ? 0.58 : 1)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// The current user's rating for this entry, or nil if guest / read-only.
    private var myRating: Int? {
        guard !isGuestSession, !isReadOnly else { return nil }
        return env.ratingsStore.rating(for: entry.id)
    }

    private var readOnlyTint: Color {
        isReadOnly ? .secondary : accent
    }

    private var isGuestSession: Bool { env.session.session?.isGuest == true }
}
