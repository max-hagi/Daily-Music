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
    /// Insights passes the weekly-stable archetype here; friend mirrors leave it nil.
    var displayArchetype: TasteProfile? = nil
    var onRatingChanged: (() -> Void)? = nil
    @State private var detail: StandoutDetail?

    // MARK: entrance animation state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// Accent = the archetype's lead color (neutral default while still forming).
    private var accent: Color { (displayArchetype ?? mirror.archetype ?? .theShapeshifter).colors[0] }

    /// The archetype ID being displayed — changing it re-triggers the entrance.
    private var currentArchetypeID: String? { (displayArchetype ?? mirror.archetype)?.id }

    /// Driver map for the displayed archetype; empty while forming, for the
    /// Shapeshifter, or when the stable archetype lags the live winner.
    private var highlights: [String: DriverHighlight] {
        DriverHighlights.compute(
            evidence: mirror.evidence,
            displayedArchetypeID: currentArchetypeID,
            liveArchetypeID: mirror.archetype?.id
        )
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // ── Act 1: Hero ── punches in first, big spring
            hero(mirror)
                .modifier(EntranceModifier(
                    appeared: appeared, reduceMotion: reduceMotion,
                    scale: 0.88, offsetY: 28, delay: 0,
                    response: 0.50, damping: 0.60
                ))

            // ── Section label: fades in just after hero settles ──
            sectionLabel("WHY YOU'RE YOU")
                .modifier(FadeInModifier(
                    appeared: appeared, reduceMotion: reduceMotion, delay: 0.08
                ))

            let highlights = self.highlights
            let anyHighlights = !highlights.isEmpty

            // ── Act 2: Tile grid — staggered spring pop ──
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)], spacing: 14) {
                marqueeTile(mirror.mood,   lead: "Mood",   accent: accent,
                            highlight: highlights["mood"], anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.10,
                        response: 0.44, damping: 0.56
                    ))
                // Era never drives the archetype (decade isn't a scorer input),
                // but it still recedes alongside the other non-drivers.
                marqueeTile(mirror.decade, lead: "Era",    accent: accent,
                            highlight: nil, anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.16,
                        response: 0.44, damping: 0.56
                    ))
                marqueeTile(mirror.theme,  lead: "Theme",  accent: accent,
                            highlight: highlights["theme"], anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.22,
                        response: 0.44, damping: 0.56
                    ))
                energyTile(mirror.energy, accent: accent,
                           highlight: highlights["energy"], anyHighlights: anyHighlights)
                    .modifier(EntranceModifier(
                        appeared: appeared, reduceMotion: reduceMotion,
                        scale: 0.80, offsetY: 16, delay: 0.28,
                        response: 0.44, damping: 0.56
                    ))
            }

            // ── Act 3: Secondary rows drift in last ──
            secondaryRow(mirror.genre,    lead: "Genre",    accent: accent,
                         highlight: highlights["genre"])
                .modifier(FadeInModifier(
                    appeared: appeared, reduceMotion: reduceMotion, delay: 0.34
                ))
            secondaryRow(mirror.language, lead: "Language", accent: accent)
                .modifier(FadeInModifier(
                    appeared: appeared, reduceMotion: reduceMotion, delay: 0.38
                ))
        }
        .sheet(item: $detail) { StandoutDetailView(detail: $0, onRatingChanged: onRatingChanged) }
        .onAppear {
            guard !appeared else { return }
            appeared = true
        }
        .onChange(of: currentArchetypeID) { _, _ in
            guard !reduceMotion else { return }
            appeared = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 40_000_000) // 40 ms gap
                appeared = true
            }
        }
    }

    // MARK: hero

    private func hero(_ mirror: TasteMirror) -> some View {
        let profile = displayArchetype ?? mirror.archetype ?? .theShapeshifter
        let unlocked = displayArchetype != nil || mirror.archetype != nil
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
                        .foregroundStyle(profile.heroTopTint)
                        .frame(width: 52, height: 52)
                        .background(profile.heroTopTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                if unlocked {
                    Text(profile.tagline)
                        .font(.callout.italic())
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(unlocked ? archetypeHeroCopy(profile: profile, winningModifier: mirror.winningModifier, isCurrentUser: isCurrentUser)
                              : "\(isCurrentUser ? "Your" : "Their") portrait takes shape at \(TasteMirror.Thresholds.minRatedArchetype) ratings.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                if unlocked, profile.id == mirror.archetype?.id,
                   let evidence = mirror.evidence,
                   let receipts = archetypeReceiptsCopy(evidence: evidence, isCurrentUser: isCurrentUser) {
                    Text(receipts)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.lg)
        .background(ArchetypeHeroBackground(profile: profile))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: profile.colors[0].opacity(0.35), radius: 20, y: 10)
    }

    // MARK: section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: marquee tiles

    @ViewBuilder
    private func marqueeTile(_ dim: DimensionInsight, lead: String, accent: Color,
                             highlight: DriverHighlight?, anyHighlights: Bool) -> some View {
        if dim.isUnlocked, let s = dim.topStandout {
            // A driver tile headlines the category that shaped the archetype,
            // which may differ from the dimension's own standout. Heart-only
            // driver categories can be absent from the tile data — fall back
            // to the standout name (badge stays).
            let driverStat = highlight.flatMap { h in dim.categories.first { $0.name == h.fact.category } }
            let headline = driverStat?.name ?? s.name
            tile(lead: lead,
                 headline: headline,
                 icon: categorySymbol(dim.id, headline) ?? dimIcon(dim.id),
                 accent: accent,
                 highlight: highlight,
                 receded: highlight == nil && anyHighlights,
                 onTap: isCurrentUser ? { detail = makeDetail(dim: dim, accent: accent, featured: driverStat) } : nil)
        } else {
            lockedTile(lead: lead, icon: dimIcon(dim.id))
        }
    }

    @ViewBuilder
    private func energyTile(_ energy: EnergyInsight, accent: Color,
                            highlight: DriverHighlight?, anyHighlights: Bool) -> some View {
        if energy.isUnlocked, let lean = energy.leanLabel {
            // When energy drove the archetype, headline the driving band itself
            // ("High energy"), not the mean-based lean label.
            let headline = highlight.map { "\($0.fact.category) energy" } ?? lean
            tile(lead: "Energy", headline: headline, icon: "bolt.fill", accent: accent,
                 highlight: highlight, receded: highlight == nil && anyHighlights,
                 onTap: isCurrentUser ? { detail = makeEnergyDetail(energy, accent: accent) } : nil)
        } else {
            lockedTile(lead: "Energy", icon: "bolt.fill")
        }
    }

    /// A standout tile. `onTap == nil` renders it inert (a friend's read-only mirror):
    /// no button, and non-interactive glass so it doesn't invite a tap.
    /// Drivers get a louder tint + accent ring; when any driver is showing,
    /// the rest recede so the hierarchy reads at a glance.
    @ViewBuilder
    private func tile(lead: String, headline: String, icon: String,
                      accent: Color, highlight: DriverHighlight?, receded: Bool,
                      onTap: (() -> Void)?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let tint = accent.opacity(highlight != nil ? 0.30 : (receded ? 0.10 : 0.16))
        let visual = tileVisual(lead: lead, headline: headline, icon: icon,
                                accent: accent, highlight: highlight, receded: receded)
            .overlay {
                if highlight != nil {
                    shape.strokeBorder(accent.opacity(0.5), lineWidth: 1)
                }
            }
        if let onTap {
            Button(action: onTap) { visual }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else {
            visual
                .glassEffect(.regular.tint(tint), in: shape)
        }
    }

    private func tileVisual(lead: String, headline: String, icon: String, accent: Color,
                            highlight: DriverHighlight?, receded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Spacer(minLength: 0)
                if let highlight {
                    driverBadge(highlight, accent: accent)
                }
            }
            Spacer(minLength: 0)
            Text(lead.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accent.opacity(0.85))
            Text(headline)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(receded ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(Theme.Spacing.md)
    }

    /// The "this shaped your archetype" pill: rank 1 gets the number, the rest
    /// just the claim (a leaderboard of #2/#3 would read as noise).
    private func driverBadge(_ highlight: DriverHighlight, accent: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .black))
            Text(highlight.rank == 1 ? "#1" : "SHAPED YOU")
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(accent, in: Capsule())
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
            Text("Rate more to unlock")
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
    private func secondaryRow(_ dim: DimensionInsight, lead: String, accent: Color,
                              highlight: DriverHighlight? = nil) -> some View {
        if dim.isUnlocked, let s = dim.dominant {
            // Genre can drive the archetype (e.g. The Pophead): show the driving
            // category and the same badge the tiles use. Language never gets one.
            let driverStat = highlight.flatMap { h in dim.categories.first { $0.name == h.fact.category } }
            let shown = driverStat ?? s
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            let row = HStack(spacing: Theme.Spacing.md) {
                Image(systemName: dimIcon(dim.id))
                    .font(.headline)
                    .foregroundStyle(accent)
                    .frame(width: 26)
                Text(lead)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let highlight {
                    driverBadge(highlight, accent: accent)
                }
                Spacer()
                Text(shown.name)
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
            .overlay {
                if highlight != nil {
                    shape.strokeBorder(accent.opacity(0.5), lineWidth: 1)
                }
            }

            if isCurrentUser {
                Button { detail = makeDetail(dim: dim, accent: accent, featured: shown) } label: { row }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                row.glassEffect(.regular, in: shape)
            }
        }
    }

    // MARK: detail builders

    private func makeDetail(dim: DimensionInsight, accent: Color, featured: CategoryStat? = nil) -> StandoutDetail? {
        guard let featured = featured ?? dim.topStandout else { return nil }
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
            featuredLine: featuredLineString(likes: featured.likes, total: featured.total, likeRate: featured.likeRate),
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
            featuredLine: "\(isCurrentUser ? "Your" : "Their") saved songs lean \(lean), averaging a \(String(format: "%.1f", mean)) out of 5 on energy.",
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

// MARK: - Entrance animation helpers

/// Punchy spring scale + lift + fade. Used for the hero card and each tile.
private struct EntranceModifier: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    var scale: CGFloat = 0.88
    var offsetY: CGFloat = 20
    var delay: Double = 0
    var response: Double = 0.50
    var damping: Double = 0.62

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : scale)
            .offset(y: appeared ? 0 : offsetY)
            .opacity(appeared ? 1 : 0)
            .animation(
                reduceMotion
                    ? .none
                    : .spring(response: response, dampingFraction: damping).delay(delay),
                value: appeared
            )
    }
}

/// Simple opacity drift. Used for labels and secondary rows.
private struct FadeInModifier: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(
                reduceMotion
                    ? .none
                    : .easeOut(duration: 0.35).delay(delay),
                value: appeared
            )
    }
}
