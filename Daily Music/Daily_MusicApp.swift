//
//  Daily_MusicApp.swift
//  Daily Music
//
//  Created by Maxime Savehilaghi on 2026-05-30.
//

import SwiftUI
import UIKit
import UserNotifications

final class AppPushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var registration: PushRegistrationService?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { try? await Self.registration?.registerDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("Remote notification registration failed: \(error.localizedDescription)")
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard
            let value = response.notification.request.content.userInfo["url"] as? String,
            let url = URL(string: value)
        else { return }

        await MainActor.run {
            UIApplication.shared.open(url)
        }
    }
}

// @main marks the app's entry point — exactly one type per app has it. Conforming
// to the `App` protocol means SwiftUI owns the lifecycle (no AppDelegate/main()).
@main
struct Daily_MusicApp: App {
    @UIApplicationDelegateAdaptor(AppPushDelegate.self) private var pushDelegate
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
                    installPushRegistration(for: env)
                }
                .onAppear { installPushRegistration(for: env) }
            #else
            RootView()
                // `.environment(env)` injects the object into the SwiftUI
                // environment, so ANY descendant view can pull it out with
                // `@Environment(AppEnvironment.self)` — no manual passing down.
                .environment(env)
                .onAppear { installPushRegistration(for: env) }
            #endif
        }
    }

    private func installPushRegistration(for env: AppEnvironment) {
        AppPushDelegate.registration = env.pushRegistration

        Task {
            let status = await env.notifications.authorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else {
                return
            }

            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

// #Preview renders this view live in Xcode's canvas without launching the app.
#Preview {
    RootView()
        .environment(AppEnvironment.live())
}
