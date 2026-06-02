//
//  RatingBar.swift
//  Daily Music
//
//  The everyday taste judgment: 👍 / 👎 on a song, as two Liquid Glass circles.
//  Idle = clear interactive glass tinted by the artwork accent; tapping fills the
//  circle GREEN (like) or RED (dislike). Three states (like/dislike/none); tapping
//  the active one clears it. Optimistic + haptic. The primary signal behind the
//  Insights taste mirror.
//

import SwiftUI

@MainActor
@Observable
final class RatingModel {
    private(set) var mine: Int?
    private(set) var isSaving = false
    private let service: RatingService

    init(service: RatingService) { self.service = service }

    func load(entryID: UUID, includesMine: Bool = true) async {
        mine = includesMine ? ((try? await service.myRating(entryID: entryID)) ?? nil) : nil
    }

    func tap(_ value: Int, entryID: UUID, allowsPersistence: Bool = true) async {
        guard allowsPersistence, !isSaving else { return }
        let next = (mine == value) ? nil : value
        mine = next                       // optimistic
        isSaving = true
        do { try await service.setRating(next, entryID: entryID) }
        catch { await load(entryID: entryID) }   // re-sync on failure
        isSaving = false
    }
}

struct RatingBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]

    @Environment(AppEnvironment.self) private var env
    @State private var model: RatingModel?

    var body: some View {
        // GlassEffectContainer lets the two circles share one glass "pour" so they
        // refract together and morph fluidly when tapped (iOS 26 Liquid Glass).
        // Compact (not full-width) so it sits beside the favorite button.
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                circle(value: 1,  symbol: "hand.thumbsup.fill",   tint: .green, label: "Like")
                circle(value: -1, symbol: "hand.thumbsdown.fill", tint: .red,   label: "Dislike")
            }
        }
        // Light haptic whenever the selection changes (incl. clearing).
        .sensoryFeedback(.impact(weight: .light), trigger: model?.mine ?? 0)
        .task(id: loadID) {
            if model == nil { model = RatingModel(service: env.ratings) }
            await model?.load(entryID: entry.id, includesMine: !isGuestSession)
        }
    }

    private func circle(value: Int, symbol: String, tint: Color, label: String) -> some View {
        let selected = model?.mine == value
        return Button {
            Task { await model?.tap(value, entryID: entry.id, allowsPersistence: !isGuestSession) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                // White on the saturated fill when chosen; the accent when idle.
                .foregroundStyle(selected ? .white : accent)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        // Transparent CLEAR Liquid Glass that lets the artwork show through; fills
        // green/red only when chosen. `.interactive()` adds the touch-reactive wobble.
        .glassEffect(selected ? .clear.tint(tint).interactive()
                              : .clear.interactive(),
                     in: .circle)
        .scaleEffect(selected ? 1.06 : 1.0)
        .animation(.spring(response: 0.34, dampingFraction: 0.6), value: selected)
        .disabled(model?.isSaving == true || isGuestSession)
        .opacity(isGuestSession ? 0.5 : 1)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var isGuestSession: Bool { env.session.session?.isGuest == true }
    private var loadID: String {
        "\(entry.id.uuidString)-\(env.session.session?.userID.uuidString ?? "signed-out")"
    }
}
