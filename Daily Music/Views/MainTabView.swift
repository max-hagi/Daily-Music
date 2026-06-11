//
//  MainTabView.swift
//  Daily Music
//
//  The signed-in shell: Today, Vault, Favorites. Settings opens from the gear
//  in Today's toolbar.
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selectedTab: MainTab = .today
    @State private var entryToOpenInVault: DailyEntry?
    @State private var tabToReturnToAfterOpeningEntry: MainTab?
    // Cached inputs for the Vault "missed drops" badge, so catching up in the
    // Vault recomputes the count instantly without refetching.
    @State private var publishedEntries: [DailyEntry] = []
    @State private var checkInDays: Set<Date> = []
    @AppStorage("pendingTodayRoute") private var pendingTodayRoute = false
    @AppStorage("pendingWrappedRoute") private var pendingWrappedRoute = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "music.note", value: .today) {
                TodayView(onReturnToPreviousScreen: tabToReturnToAfterOpeningEntry.map { _ in returnToPreviousScreen })
            }
            Tab("Vault", systemImage: "calendar", value: .vault) {
                VaultView(entryToOpen: $entryToOpenInVault, onReturnFromOpenedEntry: returnToPreviousScreen)
            }
            // Missed drops from the past week — clears live as they're caught up.
            .badge(missedDropCount)
            Tab("Favorites", systemImage: "heart", value: .favorites) { FavoritesView() }
            Tab("Friends", systemImage: "person.2", value: .friends) {
                FriendsView(onOpenEntry: openMatchedEntry)
            }
            .badge(env.friendsStore.requestCount)
            Tab("Insights", systemImage: "chart.bar.fill", value: .insights) { InsightsView() }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task { await env.friendsStore.load() }   // so the badge is populated app-wide
        .task { await refreshReminderWindow() }
        .task {
            publishedEntries = (try? await env.entries.publishedHistory()) ?? []
            checkInDays = (try? await env.checkIns.checkInDates()) ?? []
        }
        .onAppear {
            consumePendingTodayRouteIfNeeded()
            consumePendingWrappedRouteIfNeeded()
        }
        .onChange(of: pendingTodayRoute) { _, _ in consumePendingTodayRouteIfNeeded() }
        .onChange(of: pendingWrappedRoute) { _, _ in consumePendingWrappedRouteIfNeeded() }
    }

    /// Recomputes on any state it reads (entries, check-ins, catch-up log), so
    /// opening a missed song in the Vault decrements the badge immediately.
    private var missedDropCount: Int {
        CatchUp.missedEntries(
            in: publishedEntries,
            checkInDays: checkInDays,
            heardEntryIDs: env.catchUpLog.heardEntryIDs
        ).count
    }

    private func openMatchedEntry(_ entry: DailyEntry) {
        tabToReturnToAfterOpeningEntry = selectedTab
        if Calendar.current.isDateInToday(entry.date) {
            selectedTab = .today
        } else {
            entryToOpenInVault = entry
            selectedTab = .vault
        }
        Haptics.tap()
    }

    private func returnToPreviousScreen() {
        guard let tabToReturnToAfterOpeningEntry else { return }
        selectedTab = tabToReturnToAfterOpeningEntry
        self.tabToReturnToAfterOpeningEntry = nil
        Haptics.tap()
    }

    /// Re-schedule the rolling reminder window on every app open: keeps the
    /// two-week window topped up AND refreshes the streak count baked into
    /// tomorrow's notification copy. Keys match SettingsViewModel.
    private func refreshReminderWindow() async {
        let defaults = UserDefaults.standard
        guard await env.notifications.authorizationStatus() == .authorized else { return }

        // The monthly recap announcement is independent of the daily reminder.
        let recapEnabled = defaults.object(forKey: "settings.weeklyRecapEnabled") as? Bool ?? true
        await env.notifications.setMonthlyRecapAnnouncement(enabled: recapEnabled)

        guard defaults.bool(forKey: "reminderEnabled"),
              let time = defaults.object(forKey: "reminderTime") as? Date else { return }

        let streak = Streak.compute(from: (try? await env.checkIns.checkInDates()) ?? [])
        SharedStreak.publish(streak)   // keep the widget's flame fresh
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        await env.notifications.scheduleDailyReminder(at: comps, streak: streak.current)
    }

    private func consumePendingTodayRouteIfNeeded() {
        guard pendingTodayRoute else { return }
        selectedTab = .today
        pendingTodayRoute = false
    }

    private func consumePendingWrappedRouteIfNeeded() {
        guard pendingWrappedRoute else { return }
        selectedTab = .insights
        pendingWrappedRoute = false
        // InsightsView watches this flag and presents last month's Wrapped.
        UserDefaults.standard.set(true, forKey: "pendingWrappedOpen")
    }

    private enum MainTab: Hashable {
        case today
        case vault
        case favorites
        case friends
        case insights
    }
}
