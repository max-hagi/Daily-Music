//
//  ArchetypeRevealView.swift
//  Daily Music
//
//  Fullscreen reward moment for first archetype unlocks and weekly archetype
//  changes. A shared pulse/flood carries the system; flare data gives every
//  archetype its own dopamine hit.
//

import SwiftUI

struct ArchetypeRevealView: View {
    let request: ArchetypeRevealRequest
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var entered = false
    @State private var flooded = false
    @State private var flaring = false
    @State private var titleIn = false
    @State private var canClose = false
    @State private var didFinish = false
    @State private var timelineTask: Task<Void, Never>?
    @State private var hapticTask: Task<Void, Never>?

    private var flare: ArchetypeRevealFlare { .flare(for: request.newProfile) }
    private var oldColors: [Color] { request.previousProfile?.colors ?? TasteProfile.theShapeshifter.colors }
    private var newColors: [Color] { request.newProfile.colors }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: oldColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .opacity(flooded ? 0 : 1)

                LinearGradient(colors: newColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .opacity(reduceMotion ? (entered ? 1 : 0) : 0.92)
                    .animation(.easeInOut(duration: reduceMotion ? 1.1 : 0.55), value: entered)

                if !reduceMotion {
                    flood(proxy)
                    textureLayer(proxy)
                    lightLayer(proxy)
                    particleLayer(proxy)
                }

                centerContent
                    .padding(.horizontal, 28)

                if canClose {
                    closeButton
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .transition(.opacity)
                }
            }
            .background(Color.black)
            .task { timelineTask = Task { await runTimeline() } }
        }
    }

    private var centerContent: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.22), lineWidth: 2)
                    .frame(width: 132, height: 132)
                    .scaleEffect(flaring ? 1.55 : 0.72)
                    .opacity(flaring ? 0 : 1)

                Image(systemName: request.newProfile.symbol)
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 112, height: 112)
                    .background(.white.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                    .shadow(color: newColors[0].opacity(0.75), radius: 34)
                    .scaleEffect(symbolScale)
                    .rotationEffect(symbolRotation)
            }
            .opacity(entered ? 1 : 0)
            .offset(y: entered ? 0 : 24)

            VStack(spacing: 8) {
                Text(request.kind == .firstUnlock ? "YOUR TASTE OPENED INTO" : "YOUR TASTE GREW INTO")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.72))

                Text(request.newProfile.title)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)

                Text(request.reason)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var closeButton: some View {
        Button {
            finish()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.16), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
        }
        .accessibilityLabel("Close archetype reveal")
    }

    private var symbolScale: CGFloat {
        switch flare.symbolMotion {
        case .bounce: return flaring ? 1.12 : (entered ? 1 : 0.72)
        case .strike: return flaring ? 1.06 : (entered ? 1 : 0.7)
        case .surge: return flaring ? 1.18 : (entered ? 1 : 0.72)
        default: return entered ? 1 : 0.72
        }
    }

    private var symbolRotation: Angle {
        switch flare.symbolMotion {
        case .rotate: return .degrees(flaring ? 10 : -10)
        case .strike: return .degrees(flaring ? -4 : 3)
        default: return .degrees(0)
        }
    }

    private func flood(_ proxy: GeometryProxy) -> some View {
        Circle()
            .fill(LinearGradient(colors: newColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 180, height: 180)
            .scaleEffect(flooded ? max(proxy.size.width, proxy.size.height) / 56 : 0.01)
            .opacity(flooded ? 1 : 0)
            .blur(radius: flooded ? 0 : 12)
            .animation(.easeInOut(duration: 0.72), value: flooded)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .ignoresSafeArea()
    }

    private func textureLayer(_ proxy: GeometryProxy) -> some View {
        let blur = textureBlur
        return ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(.white.opacity(textureOpacity(index)))
                    .frame(width: CGFloat(70 + (index % 4) * 24), height: 2)
                    .rotationEffect(.degrees(Double(index * 17)))
                    .position(texturePoint(index, in: proxy.size))
                    .blur(radius: blur)
            }
        }
        .opacity(flaring ? 1 : 0)
        .animation(.easeOut(duration: 0.8), value: flaring)
    }

    private func lightLayer(_ proxy: GeometryProxy) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(lightGradient(index))
                    .frame(width: 14, height: proxy.size.height * 0.75)
                    .blur(radius: 8)
                    .rotationEffect(.degrees(Double(-28 + index * 18)))
                    .offset(x: CGFloat(index - 2) * 76, y: flaring ? -20 : 140)
                    .opacity(flaring ? lightOpacity : 0)
            }
        }
        .blendMode(.screen)
        .animation(.easeInOut(duration: 1.2), value: flaring)
    }

    private func particleLayer(_ proxy: GeometryProxy) -> some View {
        ZStack {
            ForEach(0..<26, id: \.self) { index in
                particle(index)
                    .position(particlePoint(index, in: proxy.size))
                    .offset(y: flaring ? CGFloat(20 + (index % 7) * 10) : -160)
                    .rotationEffect(.degrees(flaring ? Double(index * 31) : 0))
                    .opacity(flaring ? 1 : 0)
                    .animation(.spring(response: 1.1, dampingFraction: 0.78).delay(Double(index % 6) * 0.045), value: flaring)
            }
        }
    }

    @ViewBuilder
    private func particle(_ index: Int) -> some View {
        switch flare.particleStyle {
        case .confetti, .paperCutouts, .jaggedBursts:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(particleColor(index))
                .frame(width: 7 + CGFloat(index % 3) * 3, height: 14 + CGFloat(index % 4) * 3)
        case .heartGlints, .heartFragments, .softHearts:
            Image(systemName: index.isMultiple(of: 2) ? "heart.fill" : "sparkle")
                .font(.system(size: 10 + CGFloat(index % 5) * 2, weight: .bold))
                .foregroundStyle(particleColor(index))
        case .leafSweep, .petals:
            Image(systemName: index.isMultiple(of: 2) ? "leaf.fill" : "sparkle")
                .font(.system(size: 12 + CGFloat(index % 4), weight: .bold))
                .foregroundStyle(particleColor(index))
        case .rainSpecks, .mist, .lowMist, .violetSmoke, .smokePulse:
            Circle()
                .fill(particleColor(index).opacity(0.7))
                .frame(width: 4 + CGFloat(index % 5), height: 4 + CGFloat(index % 5))
                .blur(radius: 2)
        default:
            Image(systemName: particleSymbol)
                .font(.system(size: 9 + CGFloat(index % 5) * 2, weight: .heavy))
                .foregroundStyle(particleColor(index))
        }
    }

    private var particleSymbol: String {
        switch flare.particleStyle {
        case .waveformRibbons: return "waveform"
        case .speedLines, .boltCracks: return "bolt.fill"
        case .guitarSparks: return "guitars.fill"
        case .retroGrid, .mosaicTiles: return "diamond.fill"
        case .cassetteLines: return "rectangle.fill"
        case .waterRings, .moonRings: return "circle"
        default: return "sparkle"
        }
    }

    private var lightOpacity: Double {
        switch flare.lightStyle {
        case .noirPurple, .burgundyNoir, .halfMoon, .darkWave: 0.28
        case .partyBeams, .stageFlash, .arenaBeams: 0.62
        default: 0.42
        }
    }

    private var textureBlur: CGFloat {
        switch flare.texture {
        case .smoke, .mist, .softBlur, .ambientMist, .cloud: 10
        default: 2
        }
    }

    private func lightGradient(_ index: Int) -> LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(index.isMultiple(of: 2) ? 0.5 : 0.25),
                newColors[index % newColors.count].opacity(0.45),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func particleColor(_ index: Int) -> Color {
        let palette = [Color.white, newColors[0], newColors.count > 1 ? newColors[1] : newColors[0], .yellow.opacity(0.92)]
        return palette[index % palette.count]
    }

    private func particlePoint(_ index: Int, in size: CGSize) -> CGPoint {
        let x = size.width * CGFloat((Double((index * 37) % 100) / 100.0))
        let y = size.height * CGFloat(0.12 + Double((index * 19) % 72) / 100.0)
        return CGPoint(x: x, y: y)
    }

    private func texturePoint(_ index: Int, in size: CGSize) -> CGPoint {
        let x = size.width * CGFloat(0.12 + Double((index * 23) % 76) / 100.0)
        let y = size.height * CGFloat(0.16 + Double((index * 29) % 68) / 100.0)
        return CGPoint(x: x, y: y)
    }

    private func textureOpacity(_ index: Int) -> Double {
        switch flare.texture {
        case .scanlines, .film, .tape, .poster: 0.20
        case .sparkleBurst, .goldGlints, .starfield: index.isMultiple(of: 3) ? 0.52 : 0.18
        default: 0.16
        }
    }

    private func runTimeline() async {
        guard !entered else { return }
        hapticTask = Haptics.playArchetypeReveal(pattern: flare.hapticPattern, reduceMotion: reduceMotion)

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.45)) {
                entered = true
                titleIn = true
                flooded = true
            }
            try? await Task.sleep(for: .milliseconds(1600))
            finish()
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) { entered = true }
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeInOut(duration: 0.72)) { flooded = true }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(response: 0.8, dampingFraction: 0.72)) { flaring = true }
        try? await Task.sleep(for: .milliseconds(1200))
        withAnimation(.easeInOut(duration: 0.25)) { canClose = true }
        try? await Task.sleep(for: .milliseconds(1600))
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        timelineTask?.cancel()
        hapticTask?.cancel()
        onFinished()
        dismiss()
    }
}
