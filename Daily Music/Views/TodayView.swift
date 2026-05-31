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
                            albumArtHorizontalPadding: 24,
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

                ToolbarItem(placement: .topBarTrailing) {
                    TodayToolbarLiveBadge(count: model?.listenersToday)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .task {
            if model == nil {
                model = TodayViewModel(
                    entries: env.entries,
                    checkIns: env.checkIns,
                    sharedStats: env.sharedStats
                )
            }
            await model?.load()
        }
    }

    private var todayString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }
}

private struct TodayToolbarLiveBadge: View {
    let count: Int?
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.18))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.35 : 0.8)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)

                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            }

            Text(label)
                .font(.caption.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .onAppear { isPulsing = true }
    }

    private var label: String {
        guard let count else { return "Live" }
        return "\(count.formatted()) listening"
    }
}
