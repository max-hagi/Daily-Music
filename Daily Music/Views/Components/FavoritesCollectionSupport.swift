//
//  FavoritesCollectionSupport.swift
//  Daily Music
//
//  Helpers for the Favorites collection: the rearrange-mode jiggle, the
//  drag-and-drop reorder delegate, and the genre/decade/mood filter sheet.
//

import SwiftUI

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

/// Collects each record's frame (in the wall's coordinate space) so the custom
/// drag-to-reorder can hit-test the finger against cells and size the lifted one.
struct FavoriteCellFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
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
