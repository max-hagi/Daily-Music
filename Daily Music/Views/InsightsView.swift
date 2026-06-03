//
//  InsightsView.swift
//  Daily Music
//
//  The taste mirror. The whole screen bleeds the archetype's color. At a glance:
//  the archetype hero + a 2×2 grid of Liquid-Glass standout tiles (Mood/Era/
//  Theme/Energy) plus slim Genre/Language rows. Tap any standout to open an
//  editorial detail sheet (StandoutDetailView). No charts anywhere.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: InsightsViewModel?
    @State private var showingWrapped = false
    @State private var detail: StandoutDetail?

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
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(wash)
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
            .sheet(item: $detail) { StandoutDetailView(detail: $0) }
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
        if case .loaded(let m) = model?.state { return (m.archetype ?? .balancedDefault).colors }
        return TasteProfile.balancedDefault.colors
    }

    // MARK: content

    private func content(_ mirror: TasteMirror) -> some View {
        let accent = (mirror.archetype ?? .balancedDefault).colors[0]
        return ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero(mirror)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    marqueeTile(mirror.mood, lead: "Mood", accent: accent)
                    marqueeTile(mirror.decade, lead: "Era", accent: accent)
                    marqueeTile(mirror.theme, lead: "Theme", accent: accent)
                    energyTile(mirror.energy, accent: accent)
                }

                secondaryRow(mirror.genre, lead: "Genre", accent: accent)
                secondaryRow(mirror.language, lead: "Language", accent: accent)

                wrappedButton(accent)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: hero

    private func hero(_ mirror: TasteMirror) -> some View {
        let profile = mirror.archetype ?? .balancedDefault
        let unlocked = mirror.archetype != nil
        let remaining = max(TasteMirror.Thresholds.minRatedArchetype - mirror.totalRated, 0)
        return ZStack(alignment: .bottomTrailing) {
            Image(systemName: profile.symbol)
                .font(.system(size: 168, weight: .bold))
                .foregroundStyle(.white.opacity(0.13))
                .offset(x: 28, y: 22)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Image(systemName: profile.symbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Spacer()
                    Text(unlocked ? "YOUR ARCHETYPE" : "FORMING")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text(unlocked ? profile.title : "\(remaining) to go")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(unlocked ? heroWhy(mirror)
                              : "Your portrait takes shape at \(TasteMirror.Thresholds.minRatedArchetype) ratings.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.lg)
        .background(LinearGradient(colors: profile.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: profile.colors[0].opacity(0.35), radius: 20, y: 10)
    }

    /// Templated "why it's you" from the real standouts — never generated text.
    private func heroWhy(_ mirror: TasteMirror) -> String {
        let mood = mirror.mood.topStandout
        let pct = Int((mood?.likeRate ?? 0) * 100)
        let overall = Int(mirror.overallLikeRate * 100)
        let moodName = mood?.name.lowercased() ?? "the songs you keep"
        let era = mirror.decade.topStandout.map { " \($0.name)" } ?? ""
        return "Because you keep \(moodName)\(era) songs more than anything else (\(pct)% yes vs \(overall)% overall)."
    }

    // MARK: marquee tiles

    @ViewBuilder
    private func marqueeTile(_ dim: DimensionInsight, lead: String, accent: Color) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            tileButton(lead: lead,
                       headline: s.name,
                       icon: categorySymbol(dim.id, s.name) ?? dimIcon(dim.id),
                       accent: accent) {
                detail = makeDetail(dim: dim, accent: accent)
            }
        } else {
            lockedTile(lead: lead, icon: dimIcon(dim.id))
        }
    }

    @ViewBuilder
    private func energyTile(_ energy: EnergyInsight, accent: Color) -> some View {
        if energy.isUnlocked, let lean = energy.leanLabel {
            tileButton(lead: "Energy", headline: lean, icon: "bolt.fill", accent: accent) {
                detail = makeEnergyDetail(energy, accent: accent)
            }
        } else {
            lockedTile(lead: "Energy", icon: "bolt.fill")
        }
    }

    private func tileButton(lead: String, headline: String, icon: String,
                            accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Spacer(minLength: 0)
                Text(lead.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(accent.opacity(0.85))
                Text(headline)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(Theme.Spacing.md)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(accent.opacity(0.16)).interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func lockedTile(lead: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(lead.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
            Text("Keep rating")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(Theme.Spacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(0.85)
    }

    // MARK: secondary rows (genre / language)

    @ViewBuilder
    private func secondaryRow(_ dim: DimensionInsight, lead: String, accent: Color) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            Button {
                detail = makeDetail(dim: dim, accent: accent)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: dimIcon(dim.id))
                        .font(.headline)
                        .foregroundStyle(accent)
                        .frame(width: 26)
                    Text(lead)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(s.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: wrapped

    private func wrappedButton(_ accent: Color) -> some View {
        Button { showingWrapped = true } label: {
            Label("See your month", systemImage: "sparkles").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: accent))
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: detail builders

    private func makeDetail(dim: DimensionInsight, accent: Color) -> StandoutDetail? {
        guard let featured = dim.topStandout else { return nil }
        let rows = dim.categories
            .filter { $0.id != featured.id }
            .map { StandoutRow(id: $0.id, name: $0.name, symbol: categorySymbol(dim.id, $0.name),
                               likes: $0.likes, total: $0.total) }
        return StandoutDetail(
            id: dim.title, title: dim.title, accent: accent,
            featuredName: featured.name,
            featuredSymbol: categorySymbol(dim.id, featured.name) ?? dimIcon(dim.id),
            featuredLine: "You keep \(featured.likes) of \(featured.total) — \(Int(featured.likeRate * 100))% yes.",
            rows: rows,
            standoutID: dim.overIndex?.id,
            skipID: dim.skip?.id
        )
    }

    private func makeEnergyDetail(_ energy: EnergyInsight, accent: Color) -> StandoutDetail? {
        guard let lean = energy.leanLabel, let mean = energy.likedMean else { return nil }
        let order = ["Low": 0, "Medium": 1, "High": 2]
        let rows = energy.bands
            .sorted { (order[$0.name] ?? 9) < (order[$1.name] ?? 9) }
            .map { StandoutRow(id: $0.id, name: "\($0.name) energy", symbol: nil,
                               likes: $0.likes, total: $0.total) }
        return StandoutDetail(
            id: "Energy", title: "Energy", accent: accent,
            featuredName: lean,
            featuredSymbol: "bolt.fill",
            featuredLine: "Your liked songs average \(String(format: "%.1f", mean)) out of 5.",
            rows: rows, standoutID: nil, skipID: nil
        )
    }

    // MARK: symbols

    private func dimIcon(_ dimID: String) -> String {
        switch dimID {
        case "mood":     "theatermasks.fill"
        case "decade":   "calendar"
        case "theme":    "text.quote"
        case "genre":    "guitars.fill"
        case "language": "globe"
        case "energy":   "bolt.fill"
        default:         "star.fill"
        }
    }

    /// Per-category SF Symbol from the taxonomy (mood/theme only); nil otherwise.
    private func categorySymbol(_ dimID: String, _ name: String) -> String? {
        switch dimID {
        case "mood":  Mood(rawValue: name)?.symbol
        case "theme": SongTheme(rawValue: name)?.symbol
        default:      nil
        }
    }
}
