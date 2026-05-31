//
//  TodayView.swift
//  Daily Music
//
//  The hero tab: today's curated song + journal. Reuses EntryDetailView so it
//  looks identical to the Vault detail.
//

import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: TodayViewModel?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No song today — yet",
                        emptyMessage: "Today's pick hasn't been published. Check back soon.",
                        onRetry: { await model.load() }
                    ) { entry in
                        EntryDetailView(
                            entry: entry,
                            dateLabel: todayString,
                            showsNavigationTitle: false,
                            albumArtHorizontalPadding: 18,
                            usesImmersiveBackdrop: true
                        )
                    }
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .task {
            if model == nil { model = TodayViewModel(entries: env.entries, checkIns: env.checkIns) }
            await model?.load()
        }
    }

    private var todayString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }
}
