//
//  CollectionShareCard.swift
//  Daily Music
//
//  A shareable, story-shaped (9:16) card for the whole collection: a mosaic of
//  recent covers, the collection count, and the current nudge line. People
//  screenshot identity, not numbers — this is the organic acquisition loop
//  (Collection Redesign §4/§7). Mirrors ShareCard's ImageRenderer + ShareLink flow.
//

import SwiftUI

struct CollectionShareCardView: View {
    let count: Int
    let subtitle: String
    let covers: [UIImage]   // newest-first, pre-loaded; up to 9 used

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            mosaic
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

            VStack(spacing: 6) {
                Text("\(count)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .opacity(0.85)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 3) {
                Text("DAILY MUSIC")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2)
                Text("my collection")
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            .padding(.bottom, 28)
        }
        .foregroundStyle(.white)
        .frame(width: 320, height: 568)
        .background(
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.13, blue: 0.11),
                         Color(red: 0.10, green: 0.09, blue: 0.08),
                         .black],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var mosaic: some View {
        let cells = Array(covers.prefix(9))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 3), count: 3),
                         spacing: 3) {
            ForEach(0..<9, id: \.self) { i in
                Group {
                    if i < cells.count {
                        Image(uiImage: cells[i]).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(.white.opacity(0.08))
                    }
                }
                .frame(width: 78, height: 78)
                .clipped()
            }
        }
    }
}

/// Sheet that previews the collection card and offers the share action.
struct CollectionShareSheet: View {
    let count: Int
    let subtitle: String
    let covers: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                cardView
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .scaleEffect(0.82)
                    .frame(maxHeight: .infinity)

                if let rendered {
                    ShareLink(item: rendered,
                              preview: SharePreview("My collection", image: rendered)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ProgressView().frame(height: 52)
                }
            }
            .padding()
            .navigationTitle("Share collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { render() }
    }

    private var cardView: CollectionShareCardView {
        CollectionShareCardView(count: count, subtitle: subtitle, covers: covers)
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3
        if let ui = renderer.uiImage { rendered = Image(uiImage: ui) }
    }
}
