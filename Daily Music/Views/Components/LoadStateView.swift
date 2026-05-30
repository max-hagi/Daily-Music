//
//  LoadStateView.swift
//  Daily Music
//
//  Renders any LoadState consistently: a spinner while loading, friendly copy
//  when empty, a retry button on failure, and your content when loaded. Keeps
//  every screen from re-implementing the same four branches.
//

import SwiftUI

struct LoadStateView<Value, Content: View>: View {
    let state: LoadState<Value>
    var emptyTitle: String = "Nothing here yet"
    var emptyMessage: String = "Check back soon."
    var onRetry: (() async -> Void)?
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let value):
            content(value)

        case .empty:
            ContentUnavailableView(emptyTitle, systemImage: "music.note", description: Text(emptyMessage))

        case .failed:
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Something went wrong",
                    systemImage: "exclamationmark.triangle",
                    description: Text("We couldn't load this. Please try again.")
                )
                if let onRetry {
                    Button("Retry") { Task { await onRetry() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
