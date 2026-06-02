//
//  InsightsView.swift
//  Daily Music
//
//  The taste mirror: synthesized archetype hero, a "what stands out" strip, and a
//  per-dimension like-rate breakdown — all from real 👍/👎 data via TasteMirror.
//  Progressive reveal: each piece stays "forming" until it has enough ratings.
//  Insights uses the archetype's color, not album art.
//

import SwiftUI

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InsightsViewModel?
    @State private var showingWrapped = false

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
                        .background(pageBackground)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(pageBackground)
            .fullScreenCover(isPresented: $showingWrapped) {
                WrappedView(favoriteIDs: env.favoritesStore.ids)
            }
        }
        .task(id: env.favoritesStore.ids) {
            if model == nil {
                model = InsightsViewModel(entries: env.entries, ratings: env.ratings)
            }
            await model?.load()
        }
    }

    private var pageBackground: some View {
        LinearGradient(colors: Theme.Surface.insightsBackground,
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private func content(_ mirror: TasteMirror) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero(mirror)
                standoutStrip(mirror)
                breakdown(mirror)
                wrappedButton(mirror)
            }
            .padding()
        }
        .background(pageBackground)
    }

    // MARK: hero

    @ViewBuilder
    private func hero(_ mirror: TasteMirror) -> some View {
        if let archetype = mirror.archetype {
            heroCard(profile: archetype, headline: archetype.title,
                     subtitle: heroWhy(mirror), badge: "YOUR ARCHETYPE")
        } else {
            let remaining = max(TasteMirror.Thresholds.minRatedArchetype - mirror.totalRated, 0)
            heroCard(profile: .balancedDefault, headline: "\(remaining) to go",
                     subtitle: "Your portrait takes shape at \(TasteMirror.Thresholds.minRatedArchetype) ratings.",
                     badge: "FORMING")
        }
    }

    private func heroCard(profile: TasteProfile, headline: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer()
                Text(badge).font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.72))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(headline)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: profile.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: profile.colors[0].opacity(0.28), radius: 18, y: 10)
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

    // MARK: standout strip

    private func standoutStrip(_ mirror: TasteMirror) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            tile(mirror.mood, lead: "Top mood")
            tile(mirror.decade, lead: "The era you live in")
            tile(mirror.theme, lead: "Your recurring theme")
            energyTile(mirror.energy)
        }
    }

    @ViewBuilder
    private func tile(_ dim: DimensionInsight, lead: String) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            standoutCard(lead: lead, headline: s.name,
                         detail: "You keep \(s.likes) of \(s.total) (\(Int(s.likeRate * 100))%).")
        } else {
            lockedCard(lead: lead)
        }
    }

    @ViewBuilder
    private func energyTile(_ energy: EnergyInsight) -> some View {
        if energy.isUnlocked, let lean = energy.leanLabel, let mean = energy.likedMean {
            standoutCard(lead: "Your energy lean", headline: lean,
                         detail: "Your liked songs average \(String(format: "%.1f", mean))/5.")
        } else {
            lockedCard(lead: "Your energy lean")
        }
    }

    private func standoutCard(lead: String, headline: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lead.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(headline).font(.system(size: 22, weight: .heavy, design: .rounded))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Surface.cardStroke, lineWidth: 1) }
    }

    private func lockedCard(lead: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead).font(.subheadline.weight(.semibold))
                Text("Keep rating to reveal this.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Surface.cardStroke, lineWidth: 1) }
    }

    // MARK: breakdown

    @ViewBuilder
    private func breakdown(_ mirror: TasteMirror) -> some View {
        let dims = [mirror.mood, mirror.theme, mirror.genre, mirror.decade, mirror.language]
            .filter { $0.isUnlocked && !$0.categories.isEmpty }
        if !dims.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("The breakdown").font(.dmTitle())
                ForEach(dims) { dim in dimensionSection(dim) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Surface.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.Surface.cardStroke, lineWidth: 1) }
        }
    }

    private func dimensionSection(_ dim: DimensionInsight) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(dim.title).font(.subheadline.weight(.bold))
            ForEach(dim.categories.prefix(6)) { cat in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let symbol = categorySymbol(dim: dim, category: cat.name) {
                            Image(systemName: symbol)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                        }
                        Text(cat.name).font(.footnote.weight(.semibold))
                        if dim.overIndex?.id == cat.id {
                            Text("↑ stands out").font(.caption2.weight(.bold)).foregroundStyle(.green)
                        } else if dim.skip?.id == cat.id {
                            Text("you skip").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(cat.likes)/\(cat.total) · \(Int(cat.likeRate * 100))%")
                            .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Surface.subtleTrack)
                            Capsule().fill((dim.overIndex?.id == cat.id ? Color.green : Color.accentColor).gradient)
                                .frame(width: max(8, proxy.size.width * cat.likeRate))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    /// Per-category SF Symbol from the taxonomy (mood/theme dimensions only).
    private func categorySymbol(dim: DimensionInsight, category: String) -> String? {
        switch dim.id {
        case "mood":  return Mood(rawValue: category)?.symbol
        case "theme": return SongTheme(rawValue: category)?.symbol
        default:      return nil
        }
    }

    // MARK: wrapped

    private func wrappedButton(_ mirror: TasteMirror) -> some View {
        Button { showingWrapped = true } label: {
            Label("See your month", systemImage: "sparkles").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: (mirror.archetype ?? .balancedDefault).colors[0]))
        .padding(.top, Theme.Spacing.xs)
    }
}
