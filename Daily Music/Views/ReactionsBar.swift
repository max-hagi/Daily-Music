//
//  ReactionsBar.swift
//  Daily Music
//
//  A row of emoji you can tap to react to the day's song, with live counts.
//  One reaction per person; tapping yours again clears it. Optimistic so it
//  feels instant.
//

import SwiftUI

// A small view model living in the same file as the view it serves. Holds the
// reaction counts + which one is mine, and does optimistic toggling.
@MainActor
@Observable
final class ReactionsModel {
    private(set) var counts: [String: Int] = [:]   // emoji → tally
    private(set) var mine: String?                  // my current pick (nil = none)

    private let service: ReactionsService

    init(service: ReactionsService) {
        self.service = service
    }

    func load(entryID: UUID) async {
        counts = (try? await service.counts(entryID: entryID)) ?? [:]
        mine = (try? await service.myReaction(entryID: entryID)) ?? nil
    }

    func toggle(_ emoji: String, entryID: UUID) async {
        // Optimistic update FIRST (so the UI reacts instantly), persist after.
        if mine == emoji {
            // Tapped my current reaction → clear it.
            counts[emoji, default: 1] -= 1
            mine = nil
        } else {
            // Switching: take a vote off my previous emoji (if any), add to the new.
            if let previous = mine { counts[previous, default: 1] -= 1 }
            counts[emoji, default: 0] += 1
            mine = emoji
        }
        do {
            try await service.setReaction(mine, entryID: entryID)
        } catch {
            // If the write failed, re-fetch the truth from the server so the UI
            // doesn't keep showing our optimistic guess.
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
            // One pill button per emoji in the fixed palette.
            ForEach(Reaction.all, id: \.self) { emoji in
                // `let` inside a ViewBuilder is allowed — handy for per-item derived values.
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
                                .contentTransition(.numericText())   // animate the number ticking
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // AnyShapeStyle TYPE-ERASES the two different fills (a Color vs the
                    // `.quaternary` material) so both branches of the ternary have the
                    // same type — the conditional wouldn't compile otherwise.
                    .background(
                        selected ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)   // no default blue tint; we style it ourselves
                .animation(.spring(duration: 0.3), value: selected)
            }
        }
        // `.task(id:)` re-runs whenever the id changes — so navigating to a
        // different entry reloads its reactions (and cancels the previous load).
        .task(id: entry.id) {
            if model == nil { model = ReactionsModel(service: env.reactions) }
            await model?.load(entryID: entry.id)
        }
    }
}
