//
//  LoadStateView.swift
//  Daily Music
//
//  Renders any LoadState consistently: a spinner while loading, friendly copy
//  when empty, a retry button on failure, and your content when loaded. Keeps
//  every screen from re-implementing the same four branches.
//

import SwiftUI

// A GENERIC view with two type parameters:
//   • Value      — the payload type inside LoadState (DailyEntry, [DailyEntry]…)
//   • Content    — the view the caller builds from a loaded Value; constrained to
//                  `: View` so the compiler knows `content(value)` returns a view.
// This is how one component handles loading/empty/error for every screen while
// letting each screen supply only the "loaded" UI.
struct LoadStateView<Value, Content: View>: View {
    let state: LoadState<Value>
    var emptyTitle: String = "Nothing here yet"
    var emptyMessage: String = "Check back soon."
    // Optional async callback for the retry button (nil → no button shown).
    var onRetry: (() async -> Void)?
    // @ViewBuilder lets the caller write normal SwiftUI (multiple views, if/else)
    // inside the trailing closure and have it assembled into one `Content`.
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        // Exhaustively switch the state → exactly one branch renders.
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let value):
            // `let value` binds the associated value out of the enum case.
            content(value)   // hand it to the caller's builder

        case .empty:
            // Apple's standard "nothing here" placeholder view.
            ContentUnavailableView(emptyTitle, systemImage: "music.note", description: Text(emptyMessage))

        case .failed:
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Something went wrong",
                    systemImage: "exclamationmark.triangle",
                    description: Text("We couldn't load this. Please try again.")
                )
                // Only show Retry if a handler was provided. `Task { … }` bridges the
                // synchronous button action to the async onRetry call.
                if let onRetry {
                    Button("Retry") { Task { await onRetry() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
