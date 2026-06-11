//
//  FeatureFlags.swift
//  Daily Music
//
//  Compile-time switches for features that ship dormant.
//

enum FeatureFlags {
    /// Gates every "Connect Apple Music" surface (Settings, onboarding) and the
    /// live full-track engine. Flip to true once the paid Apple Developer
    /// account provisions the MusicKit entitlement — see the activation
    /// checklist in FullTrackMusicEngine.swift.
    static let appleMusicConnect = false
}
