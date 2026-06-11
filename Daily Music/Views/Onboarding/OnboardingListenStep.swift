//
//  OnboardingListenStep.swift
//  Daily Music
//
//  Step 3: the preferred streaming service ("Open in…" default). Rendered from
//  StreamingService.allCases so Apple Music / Spotify / Tidal all appear, and any
//  future service is automatic.
//

import SwiftUI

struct OnboardingListenStep: View {
    @Bindable var settings: SettingsViewModel
    var accent: Color = .orange

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Where do you listen?")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("It's ok we don't judge.")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(StreamingService.allCases) { service in
                    let selected = settings.preferredStreamingService == service
                    Button {
                        settings.preferredStreamingService = service
                    } label: {
                        HStack(spacing: 12) {
                            ServiceLogo(service: service)
                            Text(service.displayName).fontWeight(.semibold)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(accent)
                            }
                        }
                        .padding()
                        .glassCard()
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selected ? accent : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .animation(.spring(response: 0.3, dampingFraction: 0.8),
                       value: settings.preferredStreamingService)

            if FeatureFlags.appleMusicConnect,
               settings.preferredStreamingService == .appleMusic {
                AppleMusicConnectPrompt(accent: accent)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}

/// Optional, skippable connect nudge for users who picked Apple Music.
/// Never blocks onboarding — it's an upgrade, not a gate.
private struct AppleMusicConnectPrompt: View {
    var accent: Color
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let session = env.appleMusic
        Group {
            switch session.status {
            case .connected:
                Label("Apple Music connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            case .notConnected:
                Button {
                    Task { await session.connect() }
                } label: {
                    HStack(spacing: 8) {
                        if session.isConnecting {
                            ProgressView()
                        } else {
                            Image(systemName: "applelogo")
                        }
                        Text("Connect Apple Music for full songs")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                    .glassCard()
                }
                .buttonStyle(.plain)
                .tint(accent)
                .disabled(session.isConnecting)
            }
        }
    }
}

#Preview {
    let env = AppEnvironment.mock()

    OnboardingListenStep(
        settings: SettingsViewModel(
            notifications: env.notifications,
            settings: env.settings,
            syncAutomatically: false
        )
    )
    .environment(env)
}
