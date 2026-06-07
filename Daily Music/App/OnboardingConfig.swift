//
//  OnboardingConfig.swift
//  Daily Music
//
//  Onboarding versioning. Bump `currentVersion` when the first-run wizard changes
//  enough that users who already finished it should be shown it ONCE more. The gate
//  (RootView) re-shows onboarding while a device's completed version is behind this;
//  finishing the wizard stamps it, so it never nags again. Incomplete onboarding
//  (closed before Finish) already re-prompts because completion is only set in finish().
//
//  v1 = name + reminder + streaming. v2 = + taste-seed ("find your frequency").
//

import Foundation

enum OnboardingConfig {
    static let currentVersion = 2
}
