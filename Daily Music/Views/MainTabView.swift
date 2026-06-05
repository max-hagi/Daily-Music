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

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "music.note", value: .today) {
                TodayView(onReturnToPreviousScreen: tabToReturnToAfterOpeningEntry.map { _ in returnToPreviousScreen })
            }
            Tab("Vault", systemImage: "calendar", value: .vault) {
                VaultView(entryToOpen: $entryToOpenInVault, onReturnFromOpenedEntry: returnToPreviousScreen)
            }
            Tab("Favorites", systemImage: "heart", value: .favorites) { FavoritesView() }
            Tab("Friends", systemImage: "person.2", value: .friends) {
                FriendsView(onOpenEntry: openMatchedEntry)
            }
            .badge(env.friendsStore.requestCount)
            Tab("Insights", systemImage: "chart.bar.fill", value: .insights) { InsightsView() }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task { await env.friendsStore.load() }   // so the badge is populated app-wide
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

    private enum MainTab: Hashable {
        case today
        case vault
        case favorites
        case friends
        case insights
    }
}
