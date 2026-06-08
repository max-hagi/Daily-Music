//
//  TasteMirrorBoard.swift
//  Daily Music
//
//  The reusable taste-mirror visualization: archetype hero + a 2×2 grid of
//  Liquid-Glass standout tiles (Mood/Era/Theme/Energy) + slim Genre/Language rows.
//  Owns its own standout-detail sheet, so any screen that shows a mirror — yours in
//  InsightsView, a friend's in FriendInsightsView — gets tappable, read-only
//  breakdowns for free. Surrounding chrome (color wash, Wrapped button, friend
//  header) belongs to the host screen.
//

import SwiftUI

struct TasteMirrorBoard: View {
    let mirror: TasteMirror
    /// false when showing a friend's mirror → hero copy switches from "you" to "they".
    var isCurrentUser: Bool = true
    @State private var detail: StandoutDetail?

    /// Accent = the archetype's lead color (neutral default while still forming).
    private var accent: Color { (mirror.archetype ?? .balancedDefault).colors[0] }

    var body: some View {
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
        }
        .sheet(item: $detail) { StandoutDetailView(detail: $0) }
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
                    Text(unlocked ? (isCurrentUser ? "YOUR ARCHETYPE" : "THEIR ARCHETYPE") : "FORMING")
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
                              : "\(isCurrentUser ? "Your" : "Their") portrait takes shape at \(TasteMirror.Thresholds.minRatedArchetype) ratings.")
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

    /// Dynamic "why it's you" — cites the winning modifier's real stats.
    private func heroWhy(_ mirror: TasteMirror) -> String {
        let moodStat  = mirror.mood.topStandout
        let moodName  = moodStat?.name.lowercased() ?? "certain"
        let overall   = Int(mirror.overallLikeRate * 100)
        let keep      = isCurrentUser ? "you keep" : "they keep"
        let your      = isCurrentUser ? "your" : "their"

        guard let wm = mirror.winningModifier else {
            let pct = Int((moodStat?.likeRate ?? 0) * 100)
            return "Because \(keep) \(moodName) songs more than anything else (\(pct)% yes vs \(overall)% overall)."
        }

        let pct    = Int(wm.likeRate * 100)
        // WinningModifier requires likeRate >= overall + Thresholds.overIndexMargin (10pp),
        // so margin is always ≥ 10. Clamp to 1 as a defensive floor.
        let margin = max(1, Int(wm.margin * 100))
        switch wm.dimensionID {
        case "decade":
            return "Because \(keep) \(pct)% of \(wm.categoryName) songs — \(margin)pts above \(your) \(overall)% average."
        case "theme":
            return "Because \(keep) \(pct)% of songs about \(wm.categoryName.lowercased()) — \(margin)pts above \(your) \(overall)% average."
        case "genre":
            return "Because \(keep) \(pct)% of \(wm.categoryName) tracks — \(margin)pts above \(your) \(overall)% average."
        // "language" modifier exists but has no dedicated archetypes in v2 — falls through to mood fallback.
        default:
            let fallbackPct = Int((moodStat?.likeRate ?? 0) * 100)
            return "Because \(keep) \(moodName) songs more than anything else (\(fallbackPct)% yes vs \(overall)% overall)."
        }
    }

    // MARK: marquee tiles

    @ViewBuilder
    private func marqueeTile(_ dim: DimensionInsight, lead: String, accent: Color) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            tile(lead: lead,
                 headline: s.name,
                 icon: categorySymbol(dim.id, s.name) ?? dimIcon(dim.id),
                 accent: accent,
                 onTap: isCurrentUser ? { detail = makeDetail(dim: dim, accent: accent) } : nil)
        } else {
            lockedTile(lead: lead, icon: dimIcon(dim.id))
        }
    }

    @ViewBuilder
    private func energyTile(_ energy: EnergyInsight, accent: Color) -> some View {
        if energy.isUnlocked, let lean = energy.leanLabel {
            tile(lead: "Energy", headline: lean, icon: "bolt.fill", accent: accent,
                 onTap: isCurrentUser ? { detail = makeEnergyDetail(energy, accent: accent) } : nil)
        } else {
            lockedTile(lead: "Energy", icon: "bolt.fill")
        }
    }

    /// A standout tile. `onTap == nil` renders it inert (a friend's read-only mirror):
    /// no button, and non-interactive glass so it doesn't invite a tap.
    @ViewBuilder
    private func tile(lead: String, headline: String, icon: String,
                      accent: Color, onTap: (() -> Void)?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if let onTap {
            Button(action: onTap) { tileVisual(lead: lead, headline: headline, icon: icon, accent: accent) }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(accent.opacity(0.16)).interactive(), in: shape)
        } else {
            tileVisual(lead: lead, headline: headline, icon: icon, accent: accent)
                .glassEffect(.regular.tint(accent.opacity(0.16)), in: shape)
        }
    }

    private func tileVisual(lead: String, headline: String, icon: String, accent: Color) -> some View {
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
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            let row = HStack(spacing: Theme.Spacing.md) {
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
                // Chevron only when it's actually tappable (your own mirror).
                if isCurrentUser {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 15)

            if isCurrentUser {
                Button { detail = makeDetail(dim: dim, accent: accent) } label: { row }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                row.glassEffect(.regular, in: shape)
            }
        }
    }

    // MARK: detail builders

    private func makeDetail(dim: DimensionInsight, accent: Color) -> StandoutDetail? {
        guard let featured = dim.topStandout else { return nil }
        let rows = dim.categories
            .filter { $0.id != featured.id }
            .map { cat in
                StandoutRow(id: cat.id, name: cat.name,
                            symbol: categorySymbol(dim.id, cat.name),
                            likes: cat.likes, total: cat.total,
                            songs: mirror.songs(inDimension: dim, category: cat.name))
            }
        return StandoutDetail(
            id: dim.title, title: dim.title, accent: accent,
            featuredName: featured.name,
            featuredSymbol: categorySymbol(dim.id, featured.name) ?? dimIcon(dim.id),
            featuredLine: "Keeps \(featured.likes) of \(featured.total) — \(Int(featured.likeRate * 100))% yes.",
            featuredSongs: mirror.songs(inDimension: dim, category: featured.name),
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
            .map { band in
                StandoutRow(id: band.id, name: "\(band.name) energy", symbol: nil,
                            likes: band.likes, total: band.total,
                            songs: mirror.songs(forDimensionID: "energy", category: band.id))
            }
        // Map leanLabel → EnergyBand raw value for the featured songs lookup.
        let featuredBandID: String = {
            switch lean {
            case "Intimate":  return "Low"
            case "Explosive": return "High"
            default:          return "Medium"
            }
        }()
        return StandoutDetail(
            id: "Energy", title: "Energy", accent: accent,
            featuredName: lean,
            featuredSymbol: "bolt.fill",
            featuredLine: "Liked songs average \(String(format: "%.1f", mean)) out of 5.",
            featuredSongs: mirror.songs(forDimensionID: "energy", category: featuredBandID),
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
