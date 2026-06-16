//
//  FavoritesCollectionSupport.swift
//  Daily Music
//
//  Helpers for the Favorites collection: the rearrange-mode jiggle, the
//  drag-and-drop reorder delegate, and the genre/decade/mood filter sheet.
//

import SwiftUI
import UniformTypeIdentifiers

/// A gentle continuous wobble used to signal "rearrange mode" (like the iOS home
/// screen). `seed` phase-offsets each record so the wall doesn't wobble in sync.
struct Jiggle: ViewModifier {
    let active: Bool
    let seed: Int
    @State private var wobble = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (wobble ? 1.3 : -1.3) : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.13 + Double(abs(seed) % 5) * 0.01).repeatForever(autoreverses: true)
                    : .default,
                value: wobble
            )
            .onAppear { wobble = active }
            .onChange(of: active) { _, now in wobble = now }
    }
}

/// Live drag-to-reorder for the favorites wall. As the dragged record hovers over
/// another, the two swap immediately so the wall reshuffles under the finger; the
/// new order is committed on drop.
struct FavoriteReorderDelegate: DropDelegate {
    let item: DailyEntry
    @Binding var items: [DailyEntry]
    @Binding var dragging: DailyEntry?
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item,
              let from = items.firstIndex(of: dragging),
              let to = items.firstIndex(of: item) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.move(fromOffsets: IndexSet(integer: from),
                       toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        onCommit()
        return true
    }
}

/// Sheet of genre/decade/mood facets. Only dimensions with values are shown.
struct FavoritesFilterSheet: View {
    @Binding var filter: FavoritesFilter
    let facets: (genres: [String], decades: [String], moods: [String])
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                section("Genre", values: facets.genres, keyPath: \.genres)
                section("Decade", values: facets.decades, keyPath: \.decades)
                section("Mood", values: facets.moods, keyPath: \.moods)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        filter.genres = []; filter.decades = []; filter.moods = []
                    }
                    .disabled(!filter.hasFacetFilters)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, values: [String],
                         keyPath: WritableKeyPath<FavoritesFilter, Set<String>>) -> some View {
        if !values.isEmpty {
            Section(title) {
                ForEach(values, id: \.self) { value in
                    Button {
                        if filter[keyPath: keyPath].contains(value) {
                            filter[keyPath: keyPath].remove(value)
                        } else {
                            filter[keyPath: keyPath].insert(value)
                        }
                    } label: {
                        HStack {
                            Text(value).foregroundStyle(.primary)
                            Spacer()
                            if filter[keyPath: keyPath].contains(value) {
                                Image(systemName: "checkmark").foregroundStyle(.pink)
                            }
                        }
                    }
                }
            }
        }
    }
}
