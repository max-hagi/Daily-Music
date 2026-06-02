//
//  RatingBar.swift
//  Daily Music
//
//  The everyday taste judgment: 👍 / 👎 on a song. Three states (like/dislike/
//  none); tapping the active one clears it. Optimistic, mirrors ReactionsBar.
//  This is the primary signal behind the Insights taste mirror.
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
        mine = next
        isSaving = true
        do { try await service.setRating(next, entryID: entryID) }
        catch { await load(entryID: entryID) }
        isSaving = false
    }
}

struct RatingBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]

    @Environment(AppEnvironment.self) private var env
    @State private var model: RatingModel?

    var body: some View {
        HStack(spacing: 10) {
            button(value: 1, symbol: "hand.thumbsup", filled: "hand.thumbsup.fill", label: "Like")
            button(value: -1, symbol: "hand.thumbsdown", filled: "hand.thumbsdown.fill", label: "Dislike")
        }
        .padding(.horizontal)
        .task(id: loadID) {
            if model == nil { model = RatingModel(service: env.ratings) }
            await model?.load(entryID: entry.id, includesMine: !isGuestSession)
        }
    }

    private func button(value: Int, symbol: String, filled: String, label: String) -> some View {
        let selected = model?.mine == value
        return Button {
            Task { await model?.tap(value, entryID: entry.id, allowsPersistence: !isGuestSession) }
        } label: {
            Image(systemName: selected ? filled : symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(selected ? .white : accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(model?.isSaving == true || isGuestSession)
        .animation(.spring(duration: 0.3), value: selected)
        .accessibilityLabel(label)
    }

    private var isGuestSession: Bool { env.session.session?.isGuest == true }
    private var loadID: String {
        "\(entry.id.uuidString)-\(env.session.session?.userID.uuidString ?? "signed-out")"
    }
}
