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
        guard !isSaving else { return }
        let next = (mine == value) ? nil : value
        mine = next                       // optimistic

        if !allowsPersistence { return }

        isSaving = true
        do { try await service.setRating(next, entryID: entryID) }
        catch { await load(entryID: entryID) }   // re-sync on failure
        isSaving = false
    }
}

struct RatingBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]
    var controlSize: CGFloat = 52
    var symbolSize: CGFloat = 20
    var spacing: CGFloat = 12
    var isReadOnly = false

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: RatingModel?

    var body: some View {
        // GlassEffectContainer lets the two circles share one glass "pour" so they
        // refract together and morph fluidly when tapped (iOS 26 Liquid Glass).
        // Compact (not full-width) so it sits beside the favorite button.
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                circle(value: 1,  symbol: "hand.thumbsup.fill",   tint: .green, label: "Like")
                circle(value: -1, symbol: "hand.thumbsdown.fill", tint: .red,   label: "Dislike")
            }
        }
        .task(id: loadID) {
            if model == nil { model = RatingModel(service: env.ratings) }
            await model?.load(entryID: entry.id, includesMine: !isGuestSession && !isReadOnly)
        }
    }

    private func circle(value: Int, symbol: String, tint: Color, label: String) -> some View {
        let selected = model?.mine == value
        return Button {
            guard !isReadOnly else { return }
            Haptics.tap()
            Task { await model?.tap(value, entryID: entry.id, allowsPersistence: !isGuestSession) }
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
        .disabled(model?.isSaving == true || isReadOnly)
        .opacity(isReadOnly ? 0.58 : 1)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var readOnlyTint: Color {
        isReadOnly ? .secondary : accent
    }

    private var isGuestSession: Bool { env.session.session?.isGuest == true }
    private var loadID: String {
        "\(entry.id.uuidString)-\(env.session.session?.userID.uuidString ?? "signed-out")-\(isReadOnly)"
    }
}
