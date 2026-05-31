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
