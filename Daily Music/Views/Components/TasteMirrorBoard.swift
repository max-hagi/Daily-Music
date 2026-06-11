//
//  TasteMirrorBoard.swift
//  Daily Music
//
//  The reusable taste-mirror visualization, driver-first: archetype hero +
//  "what made you" driver cards (the categories that actually decided the
//  archetype, sized by importance) + quiet one-line rows for everything else.
//  Owns its own standout-detail sheet, so any screen that shows a mirror —
//  yours in InsightsView, a friend's in FriendInsightsView — gets tappable,
//  read-only breakdowns for free. Surrounding chrome (color wash, Wrapped
//  button, friend header) belongs to the host screen.
//

import SwiftUI

struct TasteMirrorBoard: View {
    let mirror: TasteMirror
    /// false when showing a friend's mirror → copy switches from "you" to "they".
    var isCurrentUser: Bool = true
    /// Insights passes the weekly-stable archetype here; friend mirrors leave it nil.
    var displayArchetype: TasteProfile? = nil
    var onRatingChanged: (() -> Void)? = nil
    /// Insights wires the hero's replay icon; friend mirrors leave it nil.
    var onReplay: (() -> Void)? = nil
    /// "Next reveal in N days" line inside the hero; nil hides it.
    var revealCountdownText: String? = nil
    @State private var detail: StandoutDetail?

    // MARK: entrance animation state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// True while the one-shot full choreography (bloom + shimmer + haptic) runs.
    @State private var rewardPlaying = false
    @State private var bloom = false
    @State private var shimmer = false

    /// Archetype IDs that already played the full choreography this app session —
    /// the hit stays special; re-visits get the quick entrance.
    @MainActor private static var rewardedIDs = Set<String>()

    private var displayProfile: TasteProfile { displayArchetype ?? mirror.archetype ?? .theShapeshifter }

    /// Accent = the archetype's lead color (neutral default while still forming).
    private var accent: Color { displayProfile.colors[0] }

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

    private var flare: ArchetypeRevealFlare { .flare(for: displayProfile) }

    var body: some View {
        let highlights = self.highlights
        VStack(spacing: Theme.Spacing.lg) {
            // ── Act 1: Hero ── punches in first, big spring, then blooms once
            hero(mirror)
                .modifier(EntranceModifier(
                    appeared: appeared, reduceMotion: reduceMotion,
                    scale: 0.88, offsetY: 28, delay: 0,
                    response: 0.50, damping: 0.60
                ))

            // ── Act 2: The drivers — what actually decided the archetype ──
            if !highlights.isEmpty {
                driverSection(highlights)
            }

            // ── Act 3: Everything else recedes into quiet rows ──
            quietRows(highlights)
        }
        .sheet(item: $detail) { StandoutDetailView(detail: $0, onRatingChanged: onRatingChanged) }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            playRewardIfEarned()
        }
        .onChange(of: currentArchetypeID) { _, _ in
            guard !reduceMotion else { return }
            appeared = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 40_000_000) // 40 ms gap
                appeared = true
                playRewardIfEarned()
            }
        }
    }

    // MARK: one-shot reward choreography

    /// Bloom + shimmer + haptic, only when earned (first time this session per
    /// archetype). Timings line up with the entrance springs below.
    @MainActor private func playRewardIfEarned() {
        guard let id = currentArchetypeID, !highlights.isEmpty,
              !Self.rewardedIDs.contains(id) else { return }
        Self.rewardedIDs.insert(id)
        let flavor = BoardEntranceFlavor.flavor(for: flare.lightStyle)
        let pattern = flare.hapticPattern
        rewardPlaying = true
        Task { @MainActor in
            // Hero has settled (~0.45 s) → bloom swells.
            try? await Task.sleep(for: .milliseconds(420))
            if !reduceMotion {
                withAnimation(.easeOut(duration: flavor.bloomDuration * 0.45)) { bloom = true }
            }
            // #1 driver card lands (~0.7 s) → reward beat + shimmer.
            try? await Task.sleep(for: .milliseconds(300))
            if isCurrentUser { Haptics.driverReward(pattern: pattern) }
            guard !reduceMotion else { rewardPlaying = false; return }
            shimmer = true
            try? await Task.sleep(for: .milliseconds(Int(flavor.bloomDuration * 450)))
            withAnimation(.easeInOut(duration: flavor.bloomDuration * 0.55)) { bloom = false }
            try? await Task.sleep(for: .milliseconds(1_200))
            rewardPlaying = false
            shimmer = false
        }
    }

    // MARK: hero

    private func hero(_ mirror: TasteMirror) -> some View {
        let profile = displayProfile
        let unlocked = displayArchetype != nil || mirror.archetype != nil
        let remaining = max(TasteMirror.Thresholds.minRatedArchetype - mirror.totalRated, 0)
        let flavor = BoardEntranceFlavor.flavor(for: flare.lightStyle)
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
                    if unlocked, let onReplay {
                        Button(action: onReplay) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 28, height: 28)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Replay reveal")
                    }
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
                if unlocked, let revealCountdownText {
                    Text(revealCountdownText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.lg)
        .background(ArchetypeHeroBackground(profile: profile))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: profile.colors[0].opacity(bloom ? flavor.bloomOpacity : Theme.Shadow.glowOpacity),
                radius: bloom ? flavor.bloomRadius : 20, y: Theme.Shadow.glowY)
    }

    // MARK: section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: driver section

    @ViewBuilder
    private func driverSection(_ highlights: [String: DriverHighlight]) -> some View {
        let ranked = highlights.values.sorted { $0.rank < $1.rank }
        let title = displayProfile.title.uppercased()

        sectionLabel(isCurrentUser ? "WHAT MADE YOU \(title)" : "WHAT MADE THEM \(title)")
            .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.08))

        if let first = ranked.first {
            primaryDriverCard(first)
                .modifier(EntranceModifier(
                    appeared: appeared, reduceMotion: reduceMotion,
                    scale: 0.82, offsetY: 18, delay: 0.12,
                    response: 0.45, damping: 0.55
                ))
        }

        if ranked.count > 1 {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(ranked.dropFirst().prefix(2).enumerated()), id: \.element.rank) { index, h in
                    secondaryDriverCard(h)
                        .modifier(TiltEntranceModifier(
                            appeared: appeared, reduceMotion: reduceMotion,
                            angle: index == 0 ? 2 : -2,
                            delay: 0.22 + Double(index) * 0.06
                        ))
                }
                // A lone #2 stays half-width, leading-aligned.
                if ranked.count == 2 {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                }
            }
        }
    }

    private func primaryDriverCard(_ h: DriverHighlight) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .black))
                Text("#1 DRIVER · \(dimensionLabel(h.fact.dimensionID).uppercased())")
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(accent)
            Text(headline(for: h))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(driverReceiptCopy(fact: h.fact, isCurrentUser: isCurrentUser))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(Theme.Spacing.md)
        .overlay { shape.strokeBorder(accent.opacity(0.5), lineWidth: 1) }
        .overlay { shimmerOverlay(in: shape) }

        return Group {
            if let onTap = driverTap(h) {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(accent.opacity(0.30)).interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular.tint(accent.opacity(0.30)), in: shape)
            }
        }
    }

    private func secondaryDriverCard(_ h: DriverHighlight) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let content = VStack(alignment: .leading, spacing: 6) {
            Text("#\(h.rank) · \(dimensionLabel(h.fact.dimensionID).uppercased())")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(accent.opacity(0.85))
            Spacer(minLength: 0)
            Text(headline(for: h))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(Theme.Spacing.md)

        return Group {
            if let onTap = driverTap(h) {
                Button(action: onTap) { content }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(accent.opacity(0.30)).interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular.tint(accent.opacity(0.30)), in: shape)
            }
        }
    }

    /// A single shimmer sweep across the #1 card during the reward moment.
    @ViewBuilder
    private func shimmerOverlay(in shape: RoundedRectangle) -> some View {
        if rewardPlaying && !reduceMotion {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, accent.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width / 2.5)
                    .offset(x: shimmer ? geo.size.width * 1.2 : -geo.size.width * 0.6)
                    .animation(.easeInOut(duration: 0.7), value: shimmer)
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }

    /// The driving category as a headline; energy phrases the band itself.
    private func headline(for h: DriverHighlight) -> String {
        h.fact.dimensionID == "energy" ? "\(h.fact.category) energy" : h.fact.category
    }

    private func dimensionLabel(_ id: String) -> String {
        switch id {
        case "mood":   "Mood"
        case "theme":  "Theme"
        case "genre":  "Genre"
        case "energy": "Energy"
        default:       id.capitalized
        }
    }

    /// Tap-through for a driver card: detail sheet featured on the driving
    /// category; falls back to the dimension's standout when the category is
    /// heart-only (absent from tile data); nil when locked or a friend's mirror.
    private func driverTap(_ h: DriverHighlight) -> (() -> Void)? {
        guard isCurrentUser else { return nil }
        if h.fact.dimensionID == "energy" {
            guard mirror.energy.isUnlocked else { return nil }
            return { detail = makeEnergyDetail(mirror.energy, accent: accent) }
        }
        guard let dim = dimension(for: h.fact.dimensionID), dim.isUnlocked else { return nil }
        let featured = dim.categories.first { $0.name == h.fact.category }
        return { detail = makeDetail(dim: dim, accent: accent, featured: featured) }
    }

    private func dimension(for id: String) -> DimensionInsight? {
        switch id {
        case "mood":  mirror.mood
        case "theme": mirror.theme
        case "genre": mirror.genre
        default:      nil
        }
    }

    // MARK: quiet rows

    @ViewBuilder
    private func quietRows(_ highlights: [String: DriverHighlight]) -> some View {
        sectionLabel(highlights.isEmpty ? "YOUR TASTE" : "MORE ABOUT YOUR TASTE")
            .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: 0.30))

        VStack(spacing: 10) {
            if highlights["mood"] == nil { dimensionRow(mirror.mood, lead: "Mood", delay: 0.32) }
            if highlights["theme"] == nil { dimensionRow(mirror.theme, lead: "Theme", delay: 0.35) }
            if highlights["genre"] == nil { dimensionRow(mirror.genre, lead: "Genre", delay: 0.38) }
            if highlights["energy"] == nil { energyRow(mirror.energy, delay: 0.41) }
            dimensionRow(mirror.decade, lead: "Era", delay: 0.44)
            dimensionRow(mirror.language, lead: "Language", delay: 0.47)
        }
    }

    @ViewBuilder
    private func dimensionRow(_ dim: DimensionInsight, lead: String, delay: Double) -> some View {
        Group {
            if dim.isUnlocked, let s = dim.topStandout {
                quietRow(lead: lead, icon: dimIcon(dim.id), value: s.name,
                         onTap: isCurrentUser ? { detail = makeDetail(dim: dim, accent: accent) } : nil)
            } else {
                lockedRow(lead: lead)
            }
        }
        .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: delay))
    }

    @ViewBuilder
    private func energyRow(_ energy: EnergyInsight, delay: Double) -> some View {
        Group {
            if energy.isUnlocked, let lean = energy.leanLabel {
                quietRow(lead: "Energy", icon: "bolt.fill", value: lean,
                         onTap: isCurrentUser ? { detail = makeEnergyDetail(energy, accent: accent) } : nil)
            } else {
                lockedRow(lead: "Energy")
            }
        }
        .modifier(FadeInModifier(appeared: appeared, reduceMotion: reduceMotion, delay: delay))
    }

    /// One compact stat row. `onTap == nil` renders it inert (friend mirrors).
    @ViewBuilder
    private func quietRow(lead: String, icon: String, value: String,
                          onTap: (() -> Void)?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let row = HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
                .frame(width: 26)
            Text(lead)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            // Chevron only when it's actually tappable (your own mirror).
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 15)

        if let onTap {
            Button(action: onTap) { row }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            row.glassEffect(.regular, in: shape)
        }
    }

    private func lockedRow(lead: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(lead)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Rate more")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 15)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(0.85)
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

/// Punchy spring scale + lift + fade. Used for the hero card and driver cards.
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

/// Spring pop with a slight rotation settle — the #2/#3 driver cards.
private struct TiltEntranceModifier: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    var angle: Double = 2
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(appeared ? 0 : angle))
            .scaleEffect(appeared ? 1 : 0.85)
            .offset(y: appeared ? 0 : 14)
            .opacity(appeared ? 1 : 0)
            .animation(
                reduceMotion
                    ? .none
                    : .spring(response: 0.45, dampingFraction: 0.6).delay(delay),
                value: appeared
            )
    }
}

/// Simple opacity drift. Used for labels and quiet rows.
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
