//
//  VariantGalleryView.swift
//  Daily Music
//
//  DEBUG-only. The single control surface for the four taste calls (spec §11):
//  flip each one with a segmented control and see it live. Never ships — the whole
//  file is behind `#if DEBUG`, so release builds are pinned to VariantConfig's
//  locked defaults with no way to change them. "One compile, four decisions."
//
//  Wire an entry point to this from a debug menu when convenient; it also renders
//  in Xcode via the #Preview entries below.
//

#if DEBUG
import SwiftUI

struct VariantGalleryView: View {
    @State private var config = VariantConfig()

    var body: some View {
        @Bindable var config = config
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                section("Sleeve states (live)") {
                    HStack(spacing: 16) {
                        labelled("pending") {
                            SleeveView(entry: Self.samples[0].0, status: .unheard, size: 76)
                        }
                        labelled("mint") {
                            SleeveView(entry: Self.samples[1].0, status: .heardSameDay, size: 76)
                        }
                        labelled("secondhand") {
                            SleeveView(entry: Self.samples[2].0, status: .caughtUp, size: 76,
                                       secondhandVariant: config.secondhand)
                        }
                        labelled("missing") {
                            SleeveView(entry: Self.samples[3].0, status: .missed, size: 76,
                                       missingVariant: config.missingSleeve)
                        }
                    }
                }

                section("1 · Missing sleeve") {
                    picker($config.missingSleeve)
                    HStack(spacing: 16) {
                        ForEach(MissingSleeveVariant.allCases) { v in
                            labelled(v.label) {
                                SleeveView(entry: Self.samples[3].0, status: .missed, size: 76,
                                           missingVariant: v)
                            }
                        }
                    }
                }

                section("2 · Secondhand treatment") {
                    picker($config.secondhand)
                    HStack(spacing: 16) {
                        ForEach(SecondhandVariant.allCases) { v in
                            labelled(v.label) {
                                SleeveView(entry: Self.samples[2].0, status: .caughtUp, size: 76,
                                           secondhandVariant: v)
                            }
                        }
                    }
                }

                section("3 · Crate feel") {
                    picker($config.crateFeel)
                    CrateFeelPreview(feel: config.crateFeel, entries: Self.samples)
                }

                section("4 · Collection moment") {
                    picker($config.momentTiming)
                    Text("Drives the Today→Vault collection moment (built in step 5).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Variant gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
    }

    private func picker<T: VariantOption>(_ selection: Binding<T>) -> some View {
        Picker("", selection: selection) {
            ForEach(Array(T.allCases)) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func labelled<Content: View>(_ title: String,
                                         @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    static let samples: [(DailyEntry, ListenStatus)] = {
        let statuses: [ListenStatus] = [
            .unheard, .heardSameDay, .heardSameDay, .caughtUp,
            .missed, .heardSameDay, .caughtUp, .missed
        ]
        return statuses.enumerated().map { idx, status in
            (DailyEntry(id: UUID(), date: Date(), title: "Song \(idx + 1)", artist: "Artist",
                        albumArtURL: nil, journalMarkdown: "", appleMusicID: "1",
                        spotifyURI: "spotify:track:1"), status)
        }
    }()
}

/// A horizontal crate strip that demonstrates one `CrateFeel`. The center-tilt math
/// uses `scrollTransition` (the technique the production Crate will reuse in step 3).
struct CrateFeelPreview: View {
    let feel: CrateFeel
    let entries: [(DailyEntry, ListenStatus)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, pair in
                    SleeveView(entry: pair.0, status: pair.1, size: 92)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .rotation3DEffect(
                                    .degrees(feel == .centerTilt ? phase.value * -20 : 0),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                                .scaleEffect(feel == .centerTilt ? 1 - abs(phase.value) * 0.12 : 1)
                                .opacity(feel == .centerTilt ? 1 - abs(phase.value) * 0.15 : 1)
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 60)
            .padding(.vertical, 14)
        }
        .crateSnapPaging(feel == .snapPaging)
    }
}

#Preview("Variant gallery") {
    NavigationStack { VariantGalleryView() }
}

#Preview("Crate feels") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(CrateFeel.allCases) { feel in
                VStack(alignment: .leading, spacing: 8) {
                    Text(feel.label).font(.headline)
                    CrateFeelPreview(feel: feel, entries: VariantGalleryView.samples)
                }
            }
        }
        .padding(.vertical)
    }
}
#endif
