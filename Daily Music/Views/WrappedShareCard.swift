//
//  WrappedShareCard.swift
//  Daily Music
//
//  A shareable, story-shaped (9:16) card for the monthly recap — the month,
//  the archetype, and the big numbers, themed with the archetype's colors.
//  Same ImageRenderer + ShareLink pattern as the song ShareCard: the recap is
//  the app's most shareable asset (peak-end recall + identity flex), so it
//  should leave the app as easily as a song does.
//

import SwiftUI

struct WrappedShareCardView: View {
    let recap: WrappedViewModel.Recap

    private var accent: Color { recap.profile.colors[0] }
    private var accentAlt: Color {
        recap.profile.colors.count > 1 ? recap.profile.colors[1] : accent
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 4) {
                Text("MY")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .opacity(0.85)
                Text(recap.monthName.uppercased())
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text("in music")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .opacity(0.85)
            }

            VStack(spacing: 8) {
                Image(systemName: recap.profile.symbol)
                    .font(.system(size: 34, weight: .bold))
                    .frame(width: 68, height: 68)
                    .background(.white.opacity(0.16), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.35), lineWidth: 1) }
                Text(recap.profile.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 6)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    stat("\(recap.songsHeard)", "songs heard")
                    stat("\(recap.artistsDiscovered)", "artists")
                }
                HStack(spacing: 10) {
                    stat("\(recap.favourites)", "favorited")
                    stat("\(recap.streak.best)", "day streak", symbol: "flame.fill")
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text("DAILY MUSIC")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(2)
                .opacity(0.9)
                .padding(.bottom, 26)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(width: 320, height: 568)
        .background(
            LinearGradient(
                colors: [accent, accentAlt.opacity(0.8), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func stat(_ value: String, _ label: String, symbol: String? = nil) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                }
                Text(value)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
            }
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Sheet that previews the recap card and offers the share action.
struct WrappedShareSheet: View {
    let recap: WrappedViewModel.Recap

    @Environment(\.dismiss) private var dismiss
    // The rasterized card. nil until render() finishes → show a spinner meanwhile.
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                WrappedShareCardView(recap: recap)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(0.82)
                    .frame(maxHeight: .infinity)

                if let rendered {
                    ShareLink(
                        item: rendered,
                        preview: SharePreview("My \(recap.monthName) in music", image: rendered)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ProgressView().frame(height: 52)   // still rendering
                }
            }
            .padding()
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { render() }
    }

    // @MainActor because ImageRenderer + UI types must be touched on the main thread.
    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: WrappedShareCardView(recap: recap))
        renderer.scale = 3   // render at 3× so it's crisp on Retina displays
        if let ui = renderer.uiImage {
            rendered = Image(uiImage: ui)
        }
    }
}
