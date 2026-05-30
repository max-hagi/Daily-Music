//
//  Daily_MusicApp.swift
//  Daily Music
//
//  Created by Maxime Savehilaghi on 2026-05-30.
//

import SwiftUI

@main
struct Daily_MusicApp: App {
    // The composition root. Swap AppEnvironment.mock() for a live-services
    // factory when Supabase/MusicKit are wired up.
    @State private var env = AppEnvironment.mock()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
        }
    }
}
