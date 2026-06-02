//
//  Daily_MusicApp.swift
//  Daily Music
//
//  Created by Maxime Savehilaghi on 2026-05-30.
//

import SwiftUI

// @main marks the app's entry point — exactly one type per app has it. Conforming
// to the `App` protocol means SwiftUI owns the lifecycle (no AppDelegate/main()).
@main
struct Daily_MusicApp: App {
    // The composition root. Now using live Supabase entries; the remaining
    // services swap to live the same way, one at a time.
    // @State here OWNS the environment object for the app's whole lifetime — it's
    // created once and survives view redraws (SwiftUI keeps @State alive across
    // re-renders rather than recreating it).
    #if DEBUG
    // Dev-only: lets the login screen swap between the live Supabase backend and
    // the seeded mock environment. Compiled out of release builds, so it can
    // never ship to the App Store.
    @AppStorage("dev_useMock") private var useMock = false
    @State private var env: AppEnvironment =
        UserDefaults.standard.bool(forKey: "dev_useMock") ? .mock() : .live()
    #else
    @State private var env = AppEnvironment.live()
    #endif

    // `body` returns a Scene (the top-level container) rather than a View.
    var body: some Scene {
        // WindowGroup is the app's main window (and supports multiple on iPad/Mac).
        WindowGroup {
            #if DEBUG
            RootView()
                .environment(env)
                // Rebuild the tree (fresh session restore) whenever the env swaps.
                .id(useMock)
                .onChange(of: useMock) { _, mock in
                    env = mock ? .mock() : .live()
                }
            #else
            RootView()
                // `.environment(env)` injects the object into the SwiftUI
                // environment, so ANY descendant view can pull it out with
                // `@Environment(AppEnvironment.self)` — no manual passing down.
                .environment(env)
            #endif
        }
    }
}

// #Preview renders this view live in Xcode's canvas without launching the app.
#Preview {
    RootView()
        .environment(AppEnvironment.live())
}
