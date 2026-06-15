//
//  SleeveView.swift
//  Daily Music
//
//  One place that renders an entry's album art with its pressing-state treatment
//  (spec §10.3), so state reads at thumbnail size WITHOUT reading any label.
//  Critical rule: state is encoded by sleeve TREATMENT, not hue — album art is
//  already every colour, so a hue overlay would fight it. Hue lives only on the
//  calendar dots + tab badge (see `ListenStatus.indicatorColor`).
//
//  Treatments:
//   • pending    — accent border + play badge + a vinyl disc peeking out the top.
//   • mint       — clean crisp sleeve, disc peeking. The reward state, looks best.
//   • secondhand — full art, muted, with the chosen secondhand treatment.
//   • missing    — an empty sleeve (blank) or the art ghosted very faint.
//
//  The two missing/secondhand looks are taste calls routed through `VariantConfig`
//  (spec §11); callers pass the chosen variant, defaulting to the locked picks.
//

import SwiftUI

struct SleeveView: View {
    let entry: DailyEntry
    let status: ListenStatus
    var size: CGFloat = 64
    var missingVariant: MissingSleeveVariant = .blank
    var secondhandVariant: SecondhandVariant = .wornCornerStamp

    private var treatment: SleeveTreatment { SleeveTreatment(status) }
    // The art sits a little smaller than the cell so a disc can peek above it.
    private var coverSide: CGFloat { size * 0.84 }
    private var radius: CGFloat { min(Theme.Radius.chip, size * 0.13) }
    // Bottom-align the art in the cell so every state shares one baseline; the
    // headroom above is where the disc peeks (pending/mint) or stays empty.
    private var coverDrop: CGFloat { (size - coverSide) / 2 }

    var body: some View {
        ZStack {
            switch treatment {
            case .pending:    pendingSleeve
            case .mint:       mintSleeve
            case .secondhand: secondhandSleeve
            case .missing:    missingSleeve
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Treatments

    private var pendingSleeve: some View {
        ZStack {
            disc
            artCover
                .overlay(roundedStroke(Color.accentColor, lineWidth: 2))
                .overlay { playBadge }
                .offset(y: coverDrop)
        }
    }

    private var mintSleeve: some View {
        ZStack {
            disc
            artCover
                .overlay(roundedStroke(.primary.opacity(0.12), lineWidth: 0.5))
                .offset(y: coverDrop)
        }
    }

    private var secondhandSleeve: some View {
        let muted = secondhandVariant == .mutingOnly
        return artCover
            .saturation(muted ? 0.4 : 0.55)
            .brightness(muted ? -0.05 : -0.04)
            .overlay { ringWear }            // the vinyl's ghost worn into the card
            .overlay { scuffs }              // faint diagonal shelf-wear
            .overlay(alignment: .topTrailing) {
                if secondhandVariant == .wornCornerStamp { dogEar }
            }
            .overlay(alignment: .bottomTrailing) {
                if secondhandVariant == .wornCornerStamp { stamp }
            }
            .overlay(alignment: .leading) {
                if secondhandVariant == .edgeLabel { edgeLabel }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .offset(y: coverDrop)
    }

    /// A circular wear mark — the pressed record's outline ghosted into the sleeve.
    private var ringWear: some View {
        let d = coverSide * 0.74
        return ZStack {
            Circle().stroke(Color.black.opacity(0.14), lineWidth: coverSide * 0.045)
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .frame(width: d, height: d)
    }

    /// A couple of faint diagonal scuffs so the surface reads as handled.
    private var scuffs: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.07))
                .frame(width: coverSide * 0.5, height: 1)
                .rotationEffect(.degrees(-32))
                .offset(x: -coverSide * 0.1, y: -coverSide * 0.18)
            Capsule()
                .fill(Color.black.opacity(0.08))
                .frame(width: coverSide * 0.42, height: 1)
                .rotationEffect(.degrees(-32))
                .offset(x: coverSide * 0.12, y: coverSide * 0.16)
        }
    }

    private var missingSleeve: some View {
        ZStack {
            switch missingVariant {
            case .dusty:
                dustyArt
            case .ghost:
                AlbumArtView(url: entry.albumArtURL, cornerRadius: radius)
                    .frame(width: coverSide, height: coverSide)
                    .opacity(0.16)
                missingOutline
            case .blank:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: coverSide, height: coverSide)
                missingOutline
            }
        }
        .offset(y: coverDrop)
    }

    /// The real art, aged: desaturated, dimmed, under a neutral dust haze with a few
    /// specks — visible enough to be worth a look, clearly "left in the crate".
    private var dustyArt: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: radius)
            .frame(width: coverSide, height: coverSide)
            .saturation(0.18)
            .brightness(-0.06)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(.systemGray).opacity(0.28))
            }
            .overlay { dustSpecks }
            .overlay(alignment: .bottom) { rescueBadge }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// The faint outline + sleeve "mouth" + dashed border used by blank/ghost.
    private var missingOutline: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: coverSide, height: coverSide)
            // The sleeve "mouth" — a faint opening line near the top.
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: coverSide * 0.8, height: 1)
                .offset(y: -coverSide * 0.32)
            Image(systemName: "circle.dashed")
                .font(.system(size: coverSide * 0.3, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    private var dustSpecks: some View {
        ZStack {
            Circle().fill(.white.opacity(0.35)).frame(width: 2, height: 2)
                .offset(x: -coverSide * 0.28, y: -coverSide * 0.22)
            Circle().fill(.white.opacity(0.28)).frame(width: 1.5, height: 1.5)
                .offset(x: coverSide * 0.3, y: coverSide * 0.1)
            Circle().fill(.white.opacity(0.3)).frame(width: 1.5, height: 1.5)
                .offset(x: coverSide * 0.05, y: coverSide * 0.3)
        }
    }

    /// "Rescue" pill on a missed sleeve — listening it later reclaims it.
    private var rescueBadge: some View {
        Text("Rescue")
            .font(.system(size: max(9, coverSide * 0.12), weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.bottom, coverSide * 0.08)
    }

    // MARK: - Pieces

    private var artCover: some View {
        AlbumArtView(url: entry.albumArtURL, cornerRadius: radius)
            .frame(width: coverSide, height: coverSide)
    }

    private func roundedStroke(_ color: Color, lineWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(color, lineWidth: lineWidth)
    }

    /// A vinyl disc that peeks above the sleeve. Mostly hidden behind the art; only
    /// the crescent above the cover's top edge shows.
    private var disc: some View {
        let d = coverSide * 0.86
        return ZStack {
            Circle().fill(Color.black.opacity(0.85))
            Circle().fill(Color(.systemGray3)).frame(width: d * 0.34, height: d * 0.34)
            Circle().fill(Color.black).frame(width: d * 0.08, height: d * 0.08)
        }
        .frame(width: d, height: d)
        .overlay(Circle().strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
        .offset(y: -(size - d) / 2)
    }

    private var playBadge: some View {
        let s = coverSide * 0.34
        return Image(systemName: "play.fill")
            .font(.system(size: s * 0.48, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: s, height: s)
            .background(Color.accentColor, in: Circle())
    }

    private var dogEar: some View {
        DogEar()
            .fill(Color(.systemBackground).opacity(0.92))
            .overlay(DogEar().stroke(.black.opacity(0.12), lineWidth: 0.5))
            .frame(width: coverSide * 0.22, height: coverSide * 0.22)
    }

    private var stamp: some View {
        Text("2nd")
            .font(.system(size: max(9, coverSide * 0.15), weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(4)
    }

    private var edgeLabel: some View {
        Text("2ND")
            .font(.system(size: max(9, coverSide * 0.13), weight: .semibold))
            .foregroundStyle(.white)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: coverSide * 0.18)
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.42))
    }

    private var accessibilityLabel: String {
        let state: String
        switch status {
        case .heardSameDay: state = "collected"
        case .caughtUp:     state = "caught up, second pressing"
        case .missed:       state = "missed"
        case .rescuable:    state = "still available"
        case .unheard:      state = "not yet heard"
        }
        return "\(entry.title) by \(entry.artist), \(state)"
    }
}

/// A right-triangle filling the top-right corner — the "dog-eared" worn fold.
private struct DogEar: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

extension ListenStatus {
    /// Marker colour for compact surfaces (the calendar day dot + tab badge) — the
    /// one place hue is allowed, since there's no album art there to clash with.
    var indicatorColor: Color {
        switch self {
        case .heardSameDay: .teal
        case .caughtUp: .orange
        case .rescuable: .orange.opacity(0.55)
        case .missed: .gray.opacity(0.45)
        case .unheard: .accentColor
        }
    }
}

#if DEBUG
private extension DailyEntry {
    static func preview(_ i: Int) -> DailyEntry {
        DailyEntry(id: UUID(), date: Date(), title: "Song \(i)", artist: "Artist",
                   albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
                   spotifyURI: "spotify:track:1")
    }
}

#Preview("Sleeve states") {
    HStack(spacing: 18) {
        VStack { SleeveView(entry: .preview(1), status: .unheard, size: 84); Text("pending").font(.caption2) }
        VStack { SleeveView(entry: .preview(2), status: .heardSameDay, size: 84); Text("mint").font(.caption2) }
        VStack { SleeveView(entry: .preview(3), status: .caughtUp, size: 84); Text("secondhand").font(.caption2) }
        VStack { SleeveView(entry: .preview(4), status: .missed, size: 84); Text("missing").font(.caption2) }
    }
    .padding()
}

#Preview("Missing variants") {
    HStack(spacing: 18) {
        SleeveView(entry: .preview(1), status: .missed, size: 90, missingVariant: .blank)
        SleeveView(entry: .preview(2), status: .missed, size: 90, missingVariant: .ghost)
    }
    .padding()
}

#Preview("Secondhand variants") {
    HStack(spacing: 18) {
        SleeveView(entry: .preview(1), status: .caughtUp, size: 90, secondhandVariant: .wornCornerStamp)
        SleeveView(entry: .preview(2), status: .caughtUp, size: 90, secondhandVariant: .mutingOnly)
        SleeveView(entry: .preview(3), status: .caughtUp, size: 90, secondhandVariant: .edgeLabel)
    }
    .padding()
}
#endif
