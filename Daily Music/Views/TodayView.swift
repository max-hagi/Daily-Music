//
//  TodayView.swift
//  Daily Music
//
//  The hero tab: today's curated song + journal. Reuses EntryDetailView with
//  Today's immersive artwork backdrop and tighter hero layout.
//

import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    // The VM is OPTIONAL and built lazily in `.task` below. Why not just create it
    // here? Because it needs the services from `env`, which isn't available at
    // property-initialization time — only once the view is in the hierarchy.
    @State private var model: TodayViewModel?
    @State private var showingSettings = false   // drives the Settings sheet

    var body: some View {
        // NavigationStack provides the nav bar + push/pop. Each tab has its own.
        NavigationStack {
            // `Group` is a transparent container — it lets us attach the toolbar/
            // sheet/task modifiers once to whichever branch (model vs spinner) shows.
            Group {
                if let model {
                    LoadStateView(
                        state: model.state,
                        emptyTitle: "No song today — yet",
                        emptyMessage: "Today's pick hasn't been published. Check back soon.",
                        onRetry: { await model.load() }
                    ) { entry in
                        // The trailing closure is LoadStateView's @ViewBuilder content:
                        // only runs for the .loaded case, with the unwrapped entry.
                        EntryDetailView(
                            entry: entry,
                            dateLabel: todayString,
                            preArtworkMessage: todayPrompt,
                            showsNavigationTitle: false,
                            albumArtHorizontalPadding: 68,
                            usesImmersiveBackdrop: true
                        )
                    }
                } else {
                    ProgressView()   // while the VM is being constructed
                }
            }
            // `.toolbar` adds bar buttons. Placement chooses the side.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true   // flip the @State → presents the sheet
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")   // VoiceOver reads this (icon has no text)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    TodayToolbarLiveBadge(count: model?.listenersToday)
                }
            }
            // `.sheet(isPresented:)` shows a modal when the bound Bool is true.
            // `$showingSettings` passes a two-way BINDING so dismissing flips it back.
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .task {
            // Build the VM once (guard against re-runs), then load.
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

    // e.g. "Monday, Jun 1" — today, formatted for the detail header.
    private var todayString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    private var todayPrompt: String {
        "Hey \(listenerName), today's song is ready."
    }

    private var listenerName: String {
        guard let displayName = env.session.session?.displayName, !displayName.isEmpty else {
            return "there"
        }

        let name = displayName.split(separator: "@").first.map(String.init) ?? displayName
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// A small private subview: the pulsing "N listening" live badge. Private + in the
// same file because it's only used here.
private struct TodayToolbarLiveBadge: View {
    let count: Int?
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 7) {
            // ZStack layers the expanding ring behind the solid dot.
            ZStack {
                Circle()
                    .fill(.red.opacity(0.18))
                    .frame(width: 14, height: 14)
                    // Animate scale up + fade out → a "radar ping" pulse.
                    .scaleEffect(isPulsing ? 1.35 : 0.8)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)

                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            }

            Text(label)
                .font(.caption.weight(.heavy))
                .monospacedDigit()   // digits keep constant width so the count doesn't jitter
                .foregroundStyle(.primary)
                .contentTransition(.numericText())   // animates digit changes like a counter
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())   // frosted-glass pill
        .onAppear { isPulsing = true }
    }

    // Show the formatted count once we have it, otherwise just "Live".
    private var label: String {
        guard let count else { return "Live" }
        return "\(count.formatted()) listening"   // .formatted() adds locale thousands separators
    }
}
