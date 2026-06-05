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
    private(set) var isSaving = false

    private let service: ReactionsService

    init(service: ReactionsService) {
        self.service = service
    }

    func load(entryID: UUID, includesMine: Bool = true) async {
        counts = (try? await service.counts(entryID: entryID)) ?? [:]
        mine = includesMine ? ((try? await service.myReaction(entryID: entryID)) ?? nil) : nil
    }

    func toggle(_ emoji: String, entryID: UUID, allowsPersistence: Bool = true) async {
        guard !isSaving else { return }

        let previous = mine
        let next = previous == emoji ? nil : emoji

        applyOptimisticChange(from: previous, to: next)

        if !allowsPersistence { return }

        isSaving = true

        do {
            try await service.setReaction(next, entryID: entryID)
            await load(entryID: entryID)
        } catch {
            // If the write failed, re-fetch the truth from the server so the UI
            // doesn't keep showing our optimistic guess.
            await load(entryID: entryID)
        }

        isSaving = false
    }

    private func applyOptimisticChange(from previous: String?, to next: String?) {
        if let previous {
            counts[previous] = max((counts[previous] ?? 1) - 1, 0)
        }

        if let next {
            counts[next, default: 0] += 1
        }

        mine = next
    }
}

struct ReactionsBar: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]
    // Today passes false: reactions are interactive. Vault passes true: show the
    // historical reaction state, but do not allow old entries to be changed.
    var isReadOnly = false
    var spacing: CGFloat = 10
    var emojiFont: Font = .title3
    var countFont: Font = .footnote.weight(.semibold)
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 8
    var onSelection: ((String?) -> Void)? = nil

    @Environment(AppEnvironment.self) private var env
    @State private var model: ReactionsModel?

    var body: some View {
        HStack(spacing: spacing) {
            // One pill per emoji in the fixed palette. We always show the WHOLE
            // palette — in read-only Vault mode the unclicked ones stay visible
            // (dimmed, no number) so the row reads as a complete reaction summary.
            ForEach(Reaction.all, id: \.self) { emoji in
                // `let` inside a ViewBuilder is allowed — handy for per-item derived values.
                let count = model?.counts[emoji] ?? 0
                let selected = model?.mine == emoji

                if isReadOnly {
                    // Static pill only; no Button wrapper means no mutation path.
                    reactionPill(emoji: emoji, count: count, selected: selected)
                } else {
                    Button {
                        Haptics.tap()
                        Task {
                            await model?.toggle(
                                emoji,
                                entryID: entry.id,
                                allowsPersistence: !isGuestSession
                            )
                            onSelection?(model?.mine)
                        }
                    } label: {
                        reactionPill(emoji: emoji, count: count, selected: selected)
                    }
                    .buttonStyle(.plain)   // no default blue tint; we style it ourselves
                    .disabled(model?.isSaving == true)
                    .animation(.spring(duration: 0.3), value: selected)
                }
            }
        }
        // `.task(id:)` re-runs whenever the id changes — so navigating to a
        // different entry reloads its reactions (and cancels the previous load).
        .task(id: reactionLoadID) {
            if model == nil { model = ReactionsModel(service: env.reactions) }
            await model?.load(entryID: entry.id, includesMine: !isGuestSession)
        }
    }

    private var isGuestSession: Bool {
        env.session.session?.isGuest == true
    }

    private var reactionLoadID: String {
        "\(entry.id.uuidString)-\(env.session.session?.userID.uuidString ?? "signed-out")-\(isGuestSession)"
    }

    private func reactionPill(emoji: String, count: Int, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(emojiFont)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 24, minHeight: 24)
            if count > 0 {
                Text("\(count)")
                    .font(countFont)
                    .foregroundStyle(selected ? .white : .secondary)
                    .contentTransition(.numericText())   // animate the number ticking
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        // AnyShapeStyle TYPE-ERASES the two different fills (a Color vs the
        // `.quaternary` material) so both branches of the ternary have the
        // same type — the conditional wouldn't compile otherwise.
        .background(
            selected ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary),
            in: Capsule()
        )
        .opacity(isReadOnly && count == 0 ? 0.48 : 1)
    }
}
