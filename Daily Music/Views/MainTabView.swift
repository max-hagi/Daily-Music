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

    var body: some View {
        TabView {
            Tab("Today", systemImage: "music.note") { TodayView() }
            Tab("Vault", systemImage: "calendar") { VaultView() }
            Tab("Favorites", systemImage: "heart") { FavoritesView() }
            Tab("Friends", systemImage: "person.2") { FriendsView() }
                .badge(env.friendsStore.requestCount)
            Tab("Insights", systemImage: "chart.bar.fill") { InsightsView() }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task { await env.friendsStore.load() }   // so the badge is populated app-wide
    }
}
