//
//  InsightsView.swift
//  Daily Music
//
//  Your taste mirror. The whole screen bleeds the archetype's color; the mirror
//  itself (hero + standout tiles + genre/language rows) is rendered by the shared
//  TasteMirrorBoard, so it stays identical to a friend's read-only mirror. This
//  screen adds the personal extras: the "See your month" Wrapped button.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: InsightsViewModel?
    @State private var showingWrapped = false
    @AppStorage("startingMood") private var startingMood = ""
    @AppStorage("startingGenre") private var startingGenre = ""

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No ratings yet",
                        emptyMessage: "Rate songs 👍 / 👎 to start your taste mirror.",
                        onRetry: { await model.load() }
                    ) { mirror in
                        content(mirror)
                    }
                } else {
                    MusicLoadingView(title: nil, tint: Theme.Brand.gradient[0])
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(wash)
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
            .fullScreenCover(item: revealBinding) { request in
                ArchetypeRevealView(request: request) {
                    model?.acknowledgeReveal()
                }
            }
        }
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(entries: env.entries, ratings: env.ratings)
            }
            await model?.load()
        }
    }

    // MARK: archetype color bleed

    /// The whole screen washes with the archetype's color (neutral while forming).
    private var wash: some View {
        let c = washColors
        return LinearGradient(
            colors: [c[0].opacity(0.55),
                     (c.count > 1 ? c[1] : c[0]).opacity(0.22),
                     Color(.systemBackground)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: c)
    }

    private var washColors: [Color] {
        if case .loaded(let m) = model?.state {
            return (model?.stableArchetype ?? m.archetype ?? .balancedDefault).colors
        }
        return TasteProfile.balancedDefault.colors
    }

    private var revealBinding: Binding<ArchetypeRevealRequest?> {
        Binding(
            get: { model?.reveal },
            set: { newValue in
                if newValue == nil, model?.reveal != nil {
                    model?.acknowledgeReveal()
                }
            }
        )
    }

    // MARK: content

    private func content(_ mirror: TasteMirror) -> some View {
        let accent = (model?.stableArchetype ?? mirror.archetype ?? .balancedDefault).colors[0]
        return ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                startedHereCard
                TasteMirrorBoard(
                    mirror: mirror,
                    displayArchetype: model?.stableArchetype,
                    onRatingChanged: { Task { await model?.load() } }
                )
                wrappedButton(accent)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await model?.load()
            Haptics.tap()
        }
    }

    private func wrappedButton(_ accent: Color) -> some View {
        Button { showingWrapped = true } label: {
            Label("See your month", systemImage: "sparkles").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        .padding(.top, Theme.Spacing.xs)
    }

    @ViewBuilder private var startedHereCard: some View {
        let parts = [startingMood, startingGenre].filter { !$0.isEmpty }
        if !parts.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU STARTED HERE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.secondary)
                    Text(parts.joined(separator: " · "))
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
