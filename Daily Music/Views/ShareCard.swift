//
//  ShareCard.swift
//  Daily Music
//
//  A shareable, story-shaped (9:16) card for the day's song — album art, the
//  song, a journal pull-quote, themed by the artwork color. Rendered to an image
//  with ImageRenderer and handed to the system share sheet via ShareLink.
//  Music discovery is a social flex; this makes it one tap.
//

import SwiftUI

// The CARD itself — just a normal SwiftUI view laid out at a fixed 320×568 (a 9:16
// story ratio). It's a regular view, but it's also what ImageRenderer rasterizes
// into a shareable PNG below. Takes a pre-loaded UIImage rather than a URL because
// ImageRenderer can't wait for an async download.
struct ShareCardView: View {
    let entry: DailyEntry
    let artwork: UIImage?
    let accent: Color

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            artworkView
                .frame(width: 196, height: 196)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

            VStack(spacing: 6) {
                Text(entry.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(entry.artist)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .opacity(0.85)
            }
            .multilineTextAlignment(.center)

            Text("“\(pullQuote)”")
                .font(.system(size: 17, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .opacity(0.95)
                .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 3) {
                Text("DAILY MUSIC")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2)
                Text(entry.date.formatted(.dateTime.month().day().year()))
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            .padding(.bottom, 28)
        }
        .foregroundStyle(.white)
        .frame(width: 320, height: 568)
        .background(
            LinearGradient(
                colors: [accent, accent.opacity(0.55), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork {
            Image(uiImage: artwork).resizable().scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.18))
                .overlay { Image(systemName: "music.note").font(.system(size: 44)) }
        }
    }

    /// First sentence of the journal (markdown stripped), or a short prefix.
    private var pullQuote: String {
        // Strip the Markdown markers (* and \) and flatten newlines to spaces so
        // the quote renders as clean prose on the card.
        let plain = entry.journalMarkdown
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // If we can find a sentence boundary (". "), cut there; otherwise just take
        // the first 140 characters. `plain[..<range.lowerBound]` slices up to the period.
        if let range = plain.range(of: ". ") {
            return String(plain[..<range.lowerBound]) + "."
        }
        return String(plain.prefix(140))
    }
}

/// Sheet that previews the card and offers the share action.
struct ShareCardSheet: View {
    let entry: DailyEntry
    let artwork: UIImage?
    let accent: Color

    // `@Environment(\.dismiss)` gives us a function to close this sheet — the
    // standard way a modal dismisses itself.
    @Environment(\.dismiss) private var dismiss
    // The rasterized card. nil until render() finishes → show a spinner meanwhile.
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // A live, scaled-down preview of the card (the same view we render).
                ShareCardView(entry: entry, artwork: artwork, accent: accent)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(0.82)
                    .frame(maxHeight: .infinity)

                if let rendered {
                    // ShareLink presents the system share sheet. `item:` is the image
                    // to share; `preview:` is what shows in the share UI itself.
                    ShareLink(item: rendered, preview: SharePreview(entry.title, image: rendered)) {
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
                    Button("Done") { dismiss() }   // close the sheet
                }
            }
        }
        // Re-render if the artwork arrives after the sheet opens. Using `artwork == nil`
        // as the id means: when that Bool flips (nil → image), re-run render().
        .task(id: artwork == nil) { render() }
    }

    // @MainActor because ImageRenderer + UI types must be touched on the main thread.
    @MainActor
    private func render() {
        // ImageRenderer rasterizes any SwiftUI view into a still image off-screen.
        let renderer = ImageRenderer(content: ShareCardView(entry: entry, artwork: artwork, accent: accent))
        renderer.scale = 3   // render at 3× so it's crisp on Retina displays
        if let ui = renderer.uiImage {
            rendered = Image(uiImage: ui)
        }
    }
}
