//
//  RootView.swift
//  Daily Music
//
//  The auth gate. Restores any existing session on launch, then shows either the
//  sign-in screen or the main tabs. Also loads favorites once signed in.
//

import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var didRestore = false

    var body: some View {
        Group {
            if !didRestore {
                ProgressView()
            } else if env.session.isSignedIn {
                MainTabView()
                    .task { await env.favoritesStore.load() }
            } else {
                SignInView()
            }
        }
        .task {
            if !didRestore {
                await env.session.restore()
                didRestore = true
            }
        }
    }
}
