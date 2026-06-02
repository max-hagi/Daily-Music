//
//  SongInfoSheet.swift
//  Daily Music
//
//  The "more info" panel. Real catalog facts from the free iTunes lookup API
//  (album, release year, length, genre) plus the song's curated tags (mood,
//  energy, theme, decade, language). Degrades to tags-only if offline.
//

import SwiftUI

struct SongInfoSheet: View {
    let entry: DailyEntry
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var info: CatalogInfo?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                Section("Track") {
                    LabeledContent("Title", value: entry.title)
                    LabeledContent("Artist", value: entry.artist)
                    if let a = info?.album { LabeledContent("Album", value: a) }
                    if let y = info?.releaseYear { LabeledContent("Released", value: y) }
                    if let d = info?.durationText { LabeledContent("Length", value: d) }
                    if let g = info?.genre { LabeledContent("Genre", value: g) }
                    if !loaded { HStack { Text("Loading catalog info…").foregroundStyle(.secondary); Spacer(); ProgressView() } }
                }

                if hasTags {
                    Section("Your tags") {
                        if let m = entry.mood { LabeledContent("Mood", value: m) }
                        if let dec = entry.decade { LabeledContent("Era", value: dec) }
                        if let e = entry.energy { LabeledContent("Energy", value: "\(e)/5") }
                        if let t = entry.theme { LabeledContent("Theme", value: t) }
                        if let g = entry.genre { LabeledContent("Genre (curated)", value: g) }
                        if let l = entry.language { LabeledContent("Language", value: l) }
                    }
                }
            }
            .navigationTitle("Song info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .task {
            info = try? await env.catalogInfo.info(appleMusicID: entry.appleMusicID)
            loaded = true
        }
    }

    private var hasTags: Bool {
        entry.mood != nil || entry.decade != nil || entry.energy != nil
            || entry.theme != nil || entry.genre != nil || entry.language != nil
    }
}
