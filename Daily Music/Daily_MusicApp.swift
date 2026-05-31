//
//  Daily_MusicApp.swift
//  Daily Music
//
//  Created by Maxime Savehilaghi on 2026-05-30.
//

import SwiftUI

@main
struct Daily_MusicApp: App {
    // The composition root. Now using live Supabase entries; the remaining
    // services swap to live the same way, one at a time.
    @State private var env = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
        }
    }
}
