//
//  ReactionsBar.swift
//  Daily Music
//
//  A row of emoji you can tap to react to the day's song, with live counts.
//  One reaction per person; tapping yours again clears it. Optimistic so it
//  feels instant.
//

import SwiftUI

@MainActor
@Observable
final class ReactionsModel {
    private(set) var counts: [String: Int] = [:]
    private(set) var mine: String?

    private let service: ReactionsService

    init(service: ReactionsService) {
        self.service = service
    }

    func load(entryID: UUID) async {
        counts = (try? await service.counts(entryID: entryID)) ?? [:]
        mine = (try? await service.myReaction(entryID: entryID)) ?? nil
    }

    func toggle(_ emoji: String, entryID: UUID) async {
        if mine == emoji {
            counts[emoji, default: 1] -= 1
            mine = nil
        } else {
            if let previous = mine { counts[previous, default: 1] -= 1 }
            counts[emoji, default: 0] += 1
            mine = emoji
        }
        do {
            try await service.setReaction(mine, entryID: entryID)
        } catch {
            await load(entryID: entryID) // reconcile on failure
        }
    }
}

struct ReactionsBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]

    @Environment(AppEnvironment.self) private var env
    @State private var model: ReactionsModel?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Reaction.all, id: \.self) { emoji in
                let count = model?.counts[emoji] ?? 0
                let selected = model?.mine == emoji
                Button {
                    Task { await model?.toggle(emoji, entryID: entry.id) }
                } label: {
                    HStack(spacing: 6) {
                        Text(emoji).font(.title3)
                        if count > 0 {
                            Text("\(count)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(selected ? .white : .secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selected ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .animation(.spring(duration: 0.3), value: selected)
            }
        }
        .task(id: entry.id) {
            if model == nil { model = ReactionsModel(service: env.reactions) }
            await model?.load(entryID: entry.id)
        }
    }
}
