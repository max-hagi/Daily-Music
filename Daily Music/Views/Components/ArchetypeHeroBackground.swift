//
//  ArchetypeHeroBackground.swift
//  Daily Music
//
//  Per-archetype decorative background for the hero card.
//  Drop-in replacement for the generic LinearGradient.
//

import SwiftUI

// MARK: - Entry point

struct ArchetypeHeroBackground: View {
    let profile: TasteProfile

    @ViewBuilder var body: some View {
        switch profile.id {
        case "party_animal":                 PartyAnimalBg()
        case "flower_child":                 FlowerChildBg()
        case "hopeless_romantic":            RomanticBg()
        case "the_hippie":                   HippieBg()
        case "the_stargazer":                StargazerBg()
        case "born_in_the_wrong_generation": BornWrongGenBg()
        case "the_melancholic":              MelancholicBg()
        case "loud_and_proud":               LoudBg()
        case "the_outsider":                 OutsiderBg()
        case "the_pophead":                  PopheadBg()
        default:                             ShapeshifterBg()
        }
    }
}

// MARK: - Party Animal (spinning AngularGradient burst, top-right)

private struct PartyAnimalBg: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate / 8.0
            let deg = (t - t.rounded(.down)) * 360
            ZStack {
                LinearGradient(
                    colors: [Color(red: 1, green: 0.584, blue: 0.141),
                             Color(red: 1, green: 0.271, blue: 0),
                             Color(red: 0.788, green: 0.047, blue: 0)],
                    startPoint: .top, endPoint: .bottom
                )
                GeometryReader { geo in
                    AngularGradient(
                        colors: [.clear, .white.opacity(0.22), .clear,
                                 .white.opacity(0.15), .clear, .white.opacity(0.18), .clear],
                        center: .center
                    )
                    .rotationEffect(.degrees(deg))
                    .frame(width: geo.size.width * 2, height: geo.size.width * 2)
                    .position(x: geo.size.width * 0.85, y: -geo.size.height * 0.15)
                    .blendMode(.overlay)
                    .clipped()
                }
            }
        }
    }
}

// MARK: - Flower Child (radial bloom + bokeh dots)

private struct FlowerChildBg: View {
    private let dots: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.12, 0.18, 18), (0.82, 0.09, 14), (0.55, 0.62, 22),
        (0.90, 0.52, 16), (0.28, 0.80, 12), (0.70, 0.85, 20)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1, green: 0.843, blue: 0),
                         Color(red: 1, green: 0.671, blue: 0)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.white.opacity(0.35), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 200
            )
            GeometryReader { geo in
                ForEach(dots.indices, id: \.self) { i in
                    let d = dots[i]
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: d.r * 2, height: d.r * 2)
                        .blur(radius: d.r * 0.55)
                        .position(x: geo.size.width * d.x, y: geo.size.height * d.y)
                }
            }
        }
    }
}

// MARK: - Hopeless Romantic (light-to-dark gradient + heart tile pattern)

private struct RomanticBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1, green: 0.839, blue: 0.910),
                         Color(red: 1, green: 0.373, blue: 0.655),
                         Color(red: 0.690, green: 0.094, blue: 0.431),
                         Color(red: 0.369, green: 0, blue: 0.220)],
                startPoint: .top, endPoint: .bottom
            )
            Canvas { _, size in }    // force-size canvas to card bounds
            Canvas { ctx, size in
                let spacing: CGFloat = 32
                let rows = Int(size.height / (spacing * 0.85)) + 2
                let cols = Int(size.width / spacing) + 3
                for row in 0 ..< rows {
                    for col in 0 ..< cols {
                        let x = CGFloat(col) * spacing - spacing * 0.5
                                + (row % 2 == 0 ? 0 : spacing * 0.5)
                        let y = CGFloat(row) * spacing * 0.85
                        ctx.fill(heartPath(cx: x, cy: y, s: 7),
                                 with: .color(.white.opacity(0.07)))
                    }
                }
            }
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
                center: .init(x: 0.1, y: 0.0),
                startRadius: 0,
                endRadius: 180
            )
        }
    }

    private func heartPath(cx: CGFloat, cy: CGFloat, s: CGFloat) -> Path {
        var p = Path()
        let r = s * 0.28
        // top left lobe
        p.addArc(center: CGPoint(x: cx - r, y: cy - r * 0.4),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        // top right lobe
        p.addArc(center: CGPoint(x: cx + r, y: cy - r * 0.4),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        // right side down to bottom point
        p.addLine(to: CGPoint(x: cx, y: cy + s * 0.45))
        p.closeSubpath()
        return p
    }
}

// MARK: - The Hippie (concentric ripple rings, bottom-right)

private struct HippieBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.130, green: 0.698, blue: 0.671),
                         Color(red: 0, green: 0.502, blue: 0.502)],
                startPoint: .top, endPoint: .bottom
            )
            Canvas { ctx, size in
                let cx = size.width * 0.88
                let cy = size.height * 0.88
                for i in 1 ... 3 {
                    let r = CGFloat(i) * 46.0
                    ctx.stroke(
                        Circle().path(in: CGRect(x: cx - r, y: cy - r,
                                                 width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(0.12)),
                        lineWidth: 1.5
                    )
                }
            }
        }
    }
}

// MARK: - The Stargazer (deep cosmic radial + stars + aurora wash)

private struct StargazerBg: View {
    private let stars: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.15, 0.12, 1.5), (0.72, 0.08, 2.0), (0.45, 0.20, 1.2),
        (0.88, 0.25, 1.8), (0.30, 0.30, 1.4), (0.60, 0.15, 1.6),
        (0.80, 0.40, 1.2), (0.20, 0.45, 2.0), (0.50, 0.35, 1.0),
        (0.10, 0.55, 1.5)
    ]

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.429, green: 0.310, blue: 0.788),
                         Color(red: 0.165, green: 0.063, blue: 0.376),
                         Color(red: 0.020, green: 0.004, blue: 0.063)],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 400
            )
            RadialGradient(
                colors: [Color(red: 0.3, green: 0.7, blue: 0.9).opacity(0.22), .clear],
                center: .init(x: 0.25, y: 0.1),
                startRadius: 0,
                endRadius: 200
            )
            .blendMode(.screen)
            Canvas { ctx, size in
                for s in stars {
                    let r = s.r
                    ctx.fill(
                        Circle().path(in: CGRect(x: size.width  * s.x - r,
                                                 y: size.height * s.y - r,
                                                 width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(0.88))
                    )
                }
            }
        }
    }
}

// MARK: - Born in the Wrong Generation (amber gradient + warm vignette)

private struct BornWrongGenBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.831, green: 0.541, blue: 0.102),
                         Color(red: 0.549, green: 0.373, blue: 0.239)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.40)],
                center: .center,
                startRadius: 90,
                endRadius: 300
            )
            .blendMode(.multiply)
        }
    }
}

// MARK: - The Melancholic (animated rain streaks + moon glow)

private struct MelancholicBg: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.431, green: 0.565, blue: 0.784),
                             Color(red: 0.176, green: 0.306, blue: 0.565),
                             Color(red: 0.067, green: 0.106, blue: 0.306),
                             Color(red: 0.020, green: 0.031, blue: 0.094)],
                    startPoint: .top, endPoint: .bottom
                )
                Canvas { ctx2, size in
                    let speed = 60.0
                    for i in 0 ..< 22 {
                        let xi = size.width * (CGFloat(i) / 22.0)
                                + CGFloat((i * 11) % 19) - 8
                        let offset = t * speed + Double(i * 41)
                        let y = CGFloat(offset.truncatingRemainder(
                                    dividingBy: Double(size.height) + 30)) - 15
                        var path = Path()
                        path.move(to: CGPoint(x: xi, y: y))
                        path.addLine(to: CGPoint(x: xi + 5, y: y + 16))
                        ctx2.stroke(path, with: .color(.white.opacity(0.14)),
                                    lineWidth: 1)
                    }
                }
                RadialGradient(
                    colors: [.white.opacity(0.22), .clear],
                    center: .init(x: 0.85, y: 0.05),
                    startRadius: 0,
                    endRadius: 100
                )
            }
        }
    }
}

// MARK: - Loud & Proud (edge burn + diagonal energy lines)

private struct LoudBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.800, green: 0.118, blue: 0.118),
                         Color(red: 0.400, green: 0.020, blue: 0.020)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 75,
                endRadius: 300
            )
            .blendMode(.multiply)
            Canvas { ctx, size in
                for i in 0 ..< 3 {
                    let x0 = size.width * 0.55 + CGFloat(i) * 22
                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: 0))
                    path.addLine(to: CGPoint(x: x0 - size.height * 0.38, y: size.height))
                    ctx.stroke(path, with: .color(.white.opacity(0.09)), lineWidth: 2)
                }
            }
        }
    }
}

// MARK: - The Outsider (deep purple + semi-circle motif)

private struct OutsiderBg: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.478, green: 0.310, blue: 0.749),
                         Color(red: 0.102, green: 0.039, blue: 0.188)],
                startPoint: .top, endPoint: .bottom
            )
            GeometryReader { geo in
                let r = geo.size.height * 0.55
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: geo.size.width + r * 0.42, y: geo.size.height * 0.52)
            }
        }
    }
}

// MARK: - The Pophead (hot-pink/purple gradient + animated spotlight sweep)

private struct PopheadBg: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate / 5.0
            let phase = (t - t.rounded(.down))
            ZStack {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.36, blue: 0.62),
                             Color(red: 0.82, green: 0.14, blue: 0.70),
                             Color(red: 0.62, green: 0.12, blue: 0.78)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // Rotating spotlight sweep
                GeometryReader { geo in
                    let cx = geo.size.width * 0.75
                    let cy = -geo.size.height * 0.1
                    let deg = phase * 30 - 15
                    RadialGradient(
                        colors: [.white.opacity(0.28), .clear],
                        center: .init(x: cx / geo.size.width,
                                      y: cy / geo.size.height),
                        startRadius: 0,
                        endRadius: geo.size.height * 0.9
                    )
                    .rotationEffect(.degrees(deg), anchor: .init(
                        x: cx / geo.size.width,
                        y: cy / geo.size.height
                    ))
                    .blendMode(.overlay)
                }
                // Concentric glow rings bottom-left (mic stand motif)
                Canvas { ctx2, size in
                    let cx = size.width * 0.12
                    let cy = size.height * 0.92
                    for i in 1 ... 4 {
                        let r = CGFloat(i) * 30.0
                        ctx2.stroke(
                            Circle().path(in: CGRect(x: cx - r, y: cy - r,
                                                     width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(0.10)),
                            lineWidth: 1.2
                        )
                    }
                }
            }
        }
    }
}

// MARK: - The Shapeshifter (animated hue-rotated radial overlay)

private struct ShapeshifterBg: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate / 6.0
            let hue = (t - t.rounded(.down)) * 60 - 30
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.130, green: 0.333, blue: 0.961),
                             Color(red: 0.071, green: 0.188, blue: 0.471)],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [.white.opacity(0.14), .clear],
                    center: .init(x: 0.5, y: 0.3),
                    startRadius: 0,
                    endRadius: 220
                )
                .hueRotation(.degrees(hue))
                .blendMode(.overlay)
            }
        }
    }
}
