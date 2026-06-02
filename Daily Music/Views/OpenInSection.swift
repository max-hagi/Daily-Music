//
//  OpenInSection.swift
//  Daily Music
//
//  One primary "Open in [your default service]" button (logo + name) plus a ⋯
//  menu to open this song in another service without changing the default. The
//  default is read live from the synced setting via @AppStorage (same key the
//  SettingsViewModel writes).
//

import SwiftUI

struct OpenInSection: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]

    // Same UserDefaults key SettingsViewModel.Keys.preferredStreamingService writes.
    @AppStorage("settings.preferredStreamingService") private var preferredRaw = StreamingService.appleMusic.rawValue
    @Environment(\.openURL) private var openURL

    private var preferred: StreamingService { StreamingService(rawValue: preferredRaw) ?? .appleMusic }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let url = preferred.url(for: entry) { openURL(url) }
            } label: {
                HStack(spacing: 8) {
                    ServiceLogo(service: preferred)
                    Text("Open in \(preferred.displayName)")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.forward")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: accent))

            Menu {
                ForEach(StreamingService.allCases.filter { $0 != preferred }) { service in
                    Button {
                        if let url = service.url(for: entry) { openURL(url) }
                    } label: {
                        Label("Open in \(service.displayName)", systemImage: "arrow.up.forward.app")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .padding(.horizontal)
    }
}
