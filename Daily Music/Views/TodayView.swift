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
    var onReturnToPreviousScreen: (() -> Void)? = nil

    // The VM is OPTIONAL and built lazily in `.task` below. Why not just create it
    // here? Because it needs the services from `env`, which isn't available at
    // property-initialization time — only once the view is in the hierarchy.
    @State private var model: TodayViewModel?
    @State private var showingSettings = false   // drives the Settings sheet
    @State private var showingListening = false  // drives the immersive listen cover
    @AppStorage("heardEntryID") private var heardEntryID = ""  // last entry the user listened to

    var body: some View {
        // NavigationStack provides the nav bar + push/pop. Each tab has its own.
        NavigationStack {
            // `Group` is a transparent container — it lets us attach the toolbar/
            // sheet/task modifiers once to whichever branch (model vs spinner) shows.
            Group {
                if let model {
                    switch model.state {
                    case .loaded(let entry):
                        EntryDetailView(
                            entry: entry,
                            dateLabel: todayString,
                            preArtworkMessage: todayPrompt,
                            showsNavigationTitle: false,
                            albumArtHorizontalPadding: 28,
                            usesImmersiveBackdrop: true
                        )
                        .simultaneousGesture(returnSwipeGesture)

                    case .empty:
                        NewDropIncomingView(onRefresh: { await model.load() })

                    case .failed:
                        TodayErrorView(onRetry: { await model.load() })

                    case .loading:
                        loadingState
                    }
                } else {
                    loadingState
                }
            }
            // `.toolbar` adds bar buttons. Placement chooses the side.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let onReturnToPreviousScreen {
                        Button(action: onReturnToPreviousScreen) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Back")
                    } else {
                        Button {
                            showingSettings = true   // flip the @State → presents the sheet
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")   // VoiceOver reads this (icon has no text)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    TodayToolbarLiveBadge(count: model?.listenersToday)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingListening = true
                    } label: {
                        Image(systemName: "headphones")
                    }
                    .accessibilityLabel("Listen")
                    .disabled(loadedEntry == nil)
                }
            }
            // `.sheet(isPresented:)` shows a modal when the bound Bool is true.
            // `$showingSettings` passes a two-way BINDING so dismissing flips it back.
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingListening) {
                if let entry = loadedEntry {
                    ListeningView(entry: entry) {
                        heardEntryID = entry.id.uuidString
                        showingListening = false
                    }
                }
            }
            .onChange(of: loadedEntry?.id) { _, _ in
                guard let entry = loadedEntry else { return }
                let heard = heardEntryID.isEmpty ? nil : heardEntryID
                if ListeningCeremony.shouldAutoOpen(todayEntryID: entry.id, heardEntryID: heard) {
                    showingListening = true
                }
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

    private var loadingState: some View {
        MusicLoadingView(title: nil, tint: Theme.Brand.gradient[0])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
    }

    // e.g. "Monday, Jun 1" — today, formatted for the detail header.
    private var loadedEntry: DailyEntry? {
        if case .loaded(let entry) = model?.state { return entry }
        return nil
    }

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

    private var returnSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard value.translation.width > 80, abs(value.translation.height) < 60 else { return }
                onReturnToPreviousScreen?()
            }
    }
}

private struct NewDropIncomingView: View {
    let onRefresh: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: Theme.Spacing.lg)

            ZStack {
                Circle()
                    .fill(Theme.Brand.gradient[0].opacity(0.16))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isAnimating ? 1.08 : 0.94)
                    .opacity(isAnimating ? 0.55 : 1)
                    .animation(pulseAnimation, value: isAnimating)

                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 132, height: 132)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    }

                Image(systemName: "music.note")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Theme.Brand.gradient[0])
                    .symbolEffect(.bounce, value: isAnimating)
            }
            .padding(.top, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.sm) {
                Text("New drop incoming")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Today's song has not landed yet. Check back soon.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Button {
                Task {
                    Haptics.tap()
                    await onRefresh()
                }
            } label: {
                Label("Check again", systemImage: "arrow.clockwise")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.Brand.gradient[0])
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .onAppear { isAnimating = !reduceMotion }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Theme.Brand.gradient[0].opacity(0.30),
                Color(.systemBackground).opacity(0.95),
                Theme.Brand.gradient[1].opacity(0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var pulseAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
    }
}

private struct TodayErrorView: View {
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ContentUnavailableView(
                "Something went wrong",
                systemImage: "exclamationmark.triangle",
                description: Text("We couldn't load today's drop. Please try again.")
            )

            Button("Retry") {
                Task { await onRetry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// A small private subview: the pulsing "N listening" live badge. Private + in the
// same file because it's only used here.
private struct TodayToolbarLiveBadge: View {
    let count: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .glassPillStyle(tint: .red.opacity(0.08))
        .onAppear { isPulsing = !reduceMotion }
    }

    // Show the formatted count once we have it, otherwise just "Live".
    private var label: String {
        guard let count else { return "Live" }
        return "\(count.formatted()) listening"   // .formatted() adds locale thousands separators
    }
}
