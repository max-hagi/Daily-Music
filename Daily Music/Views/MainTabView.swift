//
//  MainTabView.swift
//  Daily Music
//
//  The signed-in shell: Today, Vault, Favorites. Settings opens from the gear
//  in Today's toolbar.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        // TabView draws the bottom tab bar. Each `Tab` provides a label + SF Symbol
        // and the screen to show when selected. (This `Tab { }` builder is the
        // iOS 18+ API; older code used `.tabItem`.)
        TabView {
            Tab("Today", systemImage: "music.note") {
                TodayView()
            }
            Tab("Vault", systemImage: "calendar") {
                VaultView()
            }
            Tab("Favorites", systemImage: "heart") {
                FavoritesView()
            }
            Tab("Insights", systemImage: "chart.bar.fill") {
                InsightsView()
            }
        }
    }
}
