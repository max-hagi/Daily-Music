# Onboarding Bloom Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat gray onboarding wizard and taste-seed backdrops with an animated, hue-shifting "gradient bloom," polish all step content to a glass-card language, make the listen step non-skippable, and add a "You're all set" send-off that launches today's ceremony.

**Architecture:** One new reusable `OnboardingBloomBackground` view (drifting blurred circles over an adaptive base) driven by a per-step color palette, plus a `glassCard()` view modifier in the design system. `OnboardingView` gains per-step accents and a send-off phase; `TasteSeedView` swaps its flat tints and full-bleed cover backdrop for blooms (artwork-tinted during rating via the existing `ArtworkPalette`). No logic, persistence, or flow ordering changes except: Skip removed from the last wizard step, and the `hasCompletedOnboarding` flip moves from `finish()` to the send-off button.

**Tech Stack:** SwiftUI (iOS), existing design system (`Theme`, `PrimaryActionButtonStyle`, `ArtworkPalette`). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-10-onboarding-bloom-redesign-design.md`

**Build command (required — bare `xcodebuild` fails on this machine):**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
```

The app target uses a file-system-synchronized group: new `.swift` files under `Daily Music/` compile automatically, no pbxproj edit needed. This is view-only work — the existing unit tests are unaffected and no new test files are added (the test target requires Xcode to register new files). Each task's verification is a clean build; final verification is a manual run checklist.

---

### Task 1: `OnboardingBloomBackground` + `glassCard()` modifier

**Files:**
- Create: `Daily Music/Views/Onboarding/OnboardingBloomBackground.swift`
- Modify: `Daily Music/DesignSystem/Styles.swift` (append at end of file)

- [ ] **Step 1: Create the bloom background view**

Create `Daily Music/Views/Onboarding/OnboardingBloomBackground.swift`:

```swift
//
//  OnboardingBloomBackground.swift
//  Daily Music
//
//  The onboarding backdrop: 3 large blurred color blobs drifting slowly over an
//  adaptive base (near-white in light mode, near-black in dark / forceDark).
//  Changing `palette` crossfades the blob colors — callers animate step changes
//  by wrapping the palette change in withAnimation. Respects Reduce Motion
//  (no drift; palette crossfades still work).
//

import SwiftUI

struct OnboardingBloomBackground: View {
    /// Blob colors; cycled if fewer than 3. Animatable via the fills.
    var palette: [Color]
    /// Force the dark base regardless of system setting (used while rating,
    /// where the chrome is white-on-dark).
    var forceDark = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    private var isDark: Bool { forceDark || scheme == .dark }

    var body: some View {
        ZStack {
            (isDark ? Color(red: 0.05, green: 0.05, blue: 0.08)
                    : Color(red: 0.99, green: 0.99, blue: 1.0))
                .ignoresSafeArea()
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    blob(color(0), size: w * 1.1)
                        .position(x: drift ? w * 0.20 : w * 0.05,
                                  y: drift ? h * 0.05 : h * 0.18)
                    blob(color(1), size: w * 0.95)
                        .position(x: drift ? w * 0.85 : w * 1.00,
                                  y: drift ? h * 0.30 : h * 0.10)
                    blob(color(2), size: w * 1.25)
                        .position(x: drift ? w * 0.60 : w * 0.35,
                                  y: drift ? h * 1.00 : h * 0.88)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func color(_ i: Int) -> Color {
        palette.isEmpty ? Theme.Brand.gradient[0] : palette[i % palette.count]
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 80)
            .opacity(isDark ? 0.38 : 0.55)
    }
}

#Preview("Light") {
    OnboardingBloomBackground(palette: [.purple, .cyan, .pink])
}

#Preview("Force dark") {
    OnboardingBloomBackground(palette: [.orange, .pink, .yellow], forceDark: true)
}
```

- [ ] **Step 2: Add the `glassCard()` modifier**

Append to `Daily Music/DesignSystem/Styles.swift`:

```swift
/// The onboarding glass language: frosted card with a hairline highlight stroke
/// and a soft drop shadow, for content floating on the bloom backdrop.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 3: Build to verify**

Run the build command from the header. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingBloomBackground.swift" "Daily Music/DesignSystem/Styles.swift"
git commit -m "feat(onboarding): bloom background component + glassCard modifier"
```

---

### Task 2: Wizard chrome — bloom backdrop, per-step accents, no Skip on last step

**Files:**
- Modify: `Daily Music/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add accents/palettes and swap the background**

In `OnboardingView`, add below `private let totalSteps = 3`:

```swift
    /// Per-step accent (dots, button, selection marks) and bloom palette.
    private static let accents: [Color] = [.purple, .cyan, .orange]
    private static let palettes: [[Color]] = [
        [.purple, .cyan, .pink],          // 1 · say hello — violet
        [.cyan, .purple, .teal],          // 2 · reminder — cyan
        [Color.orange, .pink, .yellow],   // 3 · listen — amber
    ]
    private var stepAccent: Color { Self.accents[min(step, Self.accents.count - 1)] }
    private var stepPalette: [Color] { Self.palettes[min(step, Self.palettes.count - 1)] }
```

Replace the background line in `body`:

```swift
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
```

with:

```swift
        .background(OnboardingBloomBackground(palette: stepPalette).ignoresSafeArea())
```

(The palette crossfade animates because `advance()`/`goBack()` already wrap the `step` change in `withAnimation`.)

- [ ] **Step 2: Tint the chrome with the step accent**

In `progressDots`, change the fill:

```swift
                    .fill(i == step ? stepAccent : Color.secondary.opacity(0.3))
```

In `buttons`, change the primary button style:

```swift
            .buttonStyle(PrimaryActionButtonStyle(tint: stepAccent))
```

In `onboardingStepLoader`, change the tint:

```swift
        MusicLoadingView(title: nil, tint: stepAccent)
```

- [ ] **Step 3: Remove Skip from the last step**

In `buttons`, replace the skip block:

```swift
            // Skip is offered only on the optional steps (2 & 3), never on step 1.
            if step > 0 {
                Button(step == totalSteps - 1 ? "Skip" : "Skip for now") { skipAction() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isSaving || isApplyingReminder)
            }
```

with:

```swift
            // Skip is offered only on the reminder step. The listen step always
            // saves a choice (preferredStreamingService defaults to Apple Music).
            if step == 1 {
                Button("Skip for now") { skipAction() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .disabled(isSaving || isApplyingReminder)
            }
```

(`skipAction()` keeps its `guard step == 1` shape and is now only reachable from step 1 — no other change needed.)

- [ ] **Step 4: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingView.swift"
git commit -m "feat(onboarding): bloom backdrop, per-step accents, listen step no longer skippable"
```

---

### Task 3: Step content polish — glass cards on all three steps

**Files:**
- Modify: `Daily Music/Views/Components/ProfileEditor.swift`
- Modify: `Daily Music/Views/Onboarding/OnboardingHelloStep.swift`
- Modify: `Daily Music/Views/Onboarding/OnboardingReminderStep.swift`
- Modify: `Daily Music/Views/Onboarding/OnboardingListenStep.swift`
- Modify: `Daily Music/Views/Onboarding/OnboardingView.swift` (pass accents)

- [ ] **Step 1: ProfileEditor — optional accent shadow + glass field**

In `ProfileEditor.swift`, add a parameter after `nameRequired`:

```swift
    /// Optional accent for the onboarding bloom look: colored glow behind the
    /// avatar and the glass treatment on the name field. Settings leaves it nil.
    var accent: Color? = nil
```

Replace the `AvatarPickerView` call:

```swift
            AvatarPickerView(avatarURL: $avatarURL,
                             displayName: displayName.isEmpty ? nil : displayName)
```

with:

```swift
            AvatarPickerView(avatarURL: $avatarURL,
                             displayName: displayName.isEmpty ? nil : displayName)
                .shadow(color: (accent ?? .clear).opacity(0.35), radius: 18, y: 8)
```

Replace the text field's background line:

```swift
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
```

with:

```swift
                    .glassCard()
```

(With `accent == nil` the shadow is clear, so the Settings edit-profile sheet only picks up the glass field — consistent with the design system.)

- [ ] **Step 2: Hello step — pass the accent**

In `OnboardingHelloStep.swift`, add a property and pass it through:

```swift
struct OnboardingHelloStep: View {
    @Binding var displayName: String
    @Binding var avatarURL: String?
    var accent: Color = .purple

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Say hello 👋")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("What should we call you?")
                .foregroundStyle(.secondary)
            ProfileEditor(displayName: $displayName, avatarURL: $avatarURL,
                          nameRequired: true, accent: accent)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 3: Reminder step — wheel picker on a glass card**

In `OnboardingReminderStep.swift`, replace the `DatePicker` block:

```swift
            DatePicker("Reminder time", selection: $settings.reminderTime,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
```

with:

```swift
            DatePicker("Reminder time", selection: $settings.reminderTime,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .glassCard(cornerRadius: 20)
```

- [ ] **Step 4: Listen step — glass rows with an accent border on the selection**

In `OnboardingListenStep.swift`, add an accent property and restyle the row. Full new body:

```swift
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
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }
}
```

- [ ] **Step 5: Pass accents from the wizard**

In `OnboardingView.stepContent`, update the two calls:

```swift
        case 0:
            OnboardingHelloStep(displayName: $displayName, avatarURL: $avatarURL,
                                accent: stepAccent)
```

and:

```swift
            if let settings {
                OnboardingListenStep(settings: settings, accent: stepAccent)
```

(The reminder step needs no accent parameter — its glass card is neutral.)

- [ ] **Step 6: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add "Daily Music/Views/Components/ProfileEditor.swift" "Daily Music/Views/Onboarding/OnboardingHelloStep.swift" "Daily Music/Views/Onboarding/OnboardingReminderStep.swift" "Daily Music/Views/Onboarding/OnboardingListenStep.swift" "Daily Music/Views/Onboarding/OnboardingView.swift"
git commit -m "feat(onboarding): glass-card polish on all wizard steps"
```

---

### Task 4: "You're all set" send-off

**Files:**
- Modify: `Daily Music/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add send-off state and view**

In `OnboardingView`, add state next to `isSaving`:

```swift
    @State private var showingSendOff = false
```

Add a computed first name (used by the send-off copy):

```swift
    private var firstName: String {
        let n = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return n.trimmingCharacters(in: .whitespaces)
    }
```

Add the send-off view:

```swift
    /// Shown after a successful Finish: one celebratory beat, then straight
    /// into today's listening ceremony.
    private var sendOff: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Text("🎧")
                .font(.system(size: 64))
            Text("You're all set\(firstName.isEmpty ? "" : ", \(firstName)")")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Your first song is waiting.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                env.launchIntoCeremony = true
                completedOnboardingVersion = OnboardingConfig.currentVersion
                hasCompletedOnboarding = true   // flips RootView into the app
            } label: {
                Text("Hear today's song").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: stepAccent))
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
        .transition(.opacity.combined(with: .scale(scale: 1.05)))
    }
```

- [ ] **Step 2: Branch the body and rewire `finish()`**

Replace the `VStack` contents of `body` (keeping all modifiers on it unchanged):

```swift
        VStack(spacing: 0) {
            if showingSendOff {
                sendOff
            } else {
                header.padding(.top, 16)
                Spacer(minLength: 0)
                stepContent
                    .id(step)
                    .transition(stepTransition)
                Spacer(minLength: 0)
                buttons.padding(.horizontal, 28).padding(.bottom, 32)
            }
        }
```

In `finish()`, replace the success lines:

```swift
                try await env.profileStore.markOnboarded()   // server source of truth
                hasCompletedOnboarding = true                // local cache of the above
                completedOnboardingVersion = OnboardingConfig.currentVersion   // this device saw the current wizard
                Haptics.success()   // welcome in
```

with:

```swift
                try await env.profileStore.markOnboarded()   // server source of truth
                Haptics.success()   // welcome in
                // The local flags flip on the send-off button so RootView holds
                // here for one last beat before the ceremony.
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showingSendOff = true
                }
```

(On save failure nothing changes: the error shows and the wizard stays put. Note the server's `markOnboarded()` has already run when the send-off shows; if the app dies before the button tap, the next launch re-runs the wizard once and re-finishes — same recoverable behavior as today's save path.)

- [ ] **Step 3: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "Daily Music/Views/Onboarding/OnboardingView.swift"
git commit -m "feat(onboarding): 'You're all set' send-off that launches today's ceremony"
```

---

### Task 5: Taste-seed flow restyle

**Files:**
- Modify: `Daily Music/Views/Onboarding/TasteSeedView.swift`

- [ ] **Step 1: Replace the flat backdrop with phase-driven blooms**

In `TasteSeedView`, add state for the artwork palette next to `read`:

```swift
    @State private var artPalette = ArtworkPalette()
```

Add a computed bloom palette + dark flag:

```swift
    /// Bloom colors per phase: brand violet for the intro, the current card's
    /// artwork color while rating, the archetype's colors at reveal.
    private var bloomPalette: [Color] {
        switch phase {
        case .intro:
            return [.purple, .pink, .indigo]
        case .rating:
            let a = artPalette.accent
            return [a, a, .indigo]
        case .reveal:
            let profile = TasteMirror.build(from: deck.picks).archetype ?? .theShapeshifter
            return profile.colors.isEmpty ? [.purple, .pink, .indigo] : profile.colors
        }
    }
```

Replace the first three background layers of the `ZStack` in `body`:

```swift
            Theme.Brand.gradient.first.map { $0.opacity(0.12) }?.ignoresSafeArea()
            Color(.systemGroupedBackground).opacity(0.6).ignoresSafeArea()
            // While rating, the current cover blooms across the whole screen —
            // same visual language as the listening ceremony's backdrop.
            if phase == .rating, let song = deck.current {
                ratingBackdrop(song)
            }
```

with:

```swift
            // One bloom backdrop across all phases; while rating it tints from
            // the current card's artwork and forces the dark base so the white
            // chrome stays legible.
            OnboardingBloomBackground(palette: bloomPalette, forceDark: phase == .rating)
                .ignoresSafeArea()
```

Delete the now-unused `ratingBackdrop(_:)` function entirely.

- [ ] **Step 2: Load the artwork palette per card**

Extend the existing `.onChange(of: phase)` and add an index observer. Replace:

```swift
        .onChange(of: phase) { _, newPhase in
            // Begin tapped → rating starts → first preview auto-plays. The Begin
            // tap is the consenting user gesture for audio.
            guard newPhase == .rating, let song = deck.current else { return }
            Task { await player.toggle(song) }
        }
```

with:

```swift
        .onChange(of: phase) { _, newPhase in
            // Begin tapped → rating starts → first preview auto-plays. The Begin
            // tap is the consenting user gesture for audio.
            guard newPhase == .rating, let song = deck.current else { return }
            Task { await player.toggle(song) }
            Task { await artPalette.load(from: song.albumArtURL) }
        }
        .onChange(of: deck.index) { _, _ in
            // Each swipe re-tints the bloom from the next card's artwork.
            guard phase == .rating, let song = deck.current else { return }
            Task { await artPalette.load(from: song.albumArtURL) }
        }
```

- [ ] **Step 3: Accent the rating chrome from the artwork**

In `deckDots`, tint the current dot:

```swift
                Circle()
                    .fill(i == deck.index ? artPalette.accent
                          : i < deck.index ? Color.white : Color.white.opacity(0.28))
                    .frame(width: i == deck.index ? 9 : 6, height: i == deck.index ? 9 : 6)
```

In `ratingView`, change the thumbs-up tint:

```swift
                judgmentButton(value: 1, symbol: "hand.thumbsup.fill", tint: artPalette.accent)
```

In `songMeta`, give the tag capsules the glass treatment — replace the tag background line:

```swift
                        .background(.white.opacity(0.14), in: Capsule())
```

with:

```swift
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
```

- [ ] **Step 4: Reveal — glass card for the read**

In `reveal`, wrap the read block in a glass card. Replace the middle of the `VStack` (icon through body copy):

```swift
            Image(systemName: profile.symbol)
                .font(.system(size: 56))
                .foregroundStyle(profile.colors.first ?? Theme.Brand.gradient[0])
            Text("Your starting frequency")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(readHeadline)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Text("Your taste mirror starts here and sharpens every day you rate a song. Today's song is waiting once you finish setup.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
```

with:

```swift
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(profile.colors.first ?? Theme.Brand.gradient[0])
                Text("Your starting frequency")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(readHeadline)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Your taste mirror starts here and sharpens every day you rate a song. Today's song is waiting once you finish setup.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.lg)
            .glassCard(cornerRadius: 24)
            .padding(.horizontal, Theme.Spacing.lg)
```

(The intro phase needs no structural change — it inherits the violet bloom from Step 1, and its Begin button already uses `PrimaryActionButtonStyle`, which renders a gradient from its tint.)

- [ ] **Step 5: Build to verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add "Daily Music/Views/Onboarding/TasteSeedView.swift"
git commit -m "feat(onboarding): taste-seed bloom restyle — artwork-tinted rating backdrop, glass reveal"
```

---

### Task 6: Final verification

**Files:** none (manual run)

- [ ] **Step 1: Run existing tests**

```bash
cd "/Users/maximesavehilaghi/Developer/Daily Music"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test
```

Expected: all existing tests pass (this change is view-only).

- [ ] **Step 2: Manual run checklist (simulator)**

Launch the app fresh (delete it from the simulator first so onboarding shows) and verify:

1. Wizard light mode: blooms drift; palette crossfades violet → cyan → amber as you advance and back.
2. Wizard dark mode (simulator: Settings → Developer → Dark Appearance): same blooms glowing on near-black; text legible.
3. Reduce Motion on (Settings → Accessibility → Motion): backdrops static, step transitions still work.
4. Hello step: avatar has a violet glow, name field is a glass card; Continue disabled until a name is typed.
5. Taste seed: intro shows violet bloom; while rating, the backdrop tints from each card's artwork and crossfades per swipe; thumbs-up and the current deck dot match the artwork color; reveal shows the glass card on an archetype-colored bloom.
6. Reminder step: wheel picker sits on a glass card; Skip for now appears on this step only.
7. Listen step: glass rows, orange border on the selection, **no Skip button**; leaving it untouched and tapping Finish saves Apple Music (check Settings after).
8. Send-off appears after Finish ("You're all set, <name>"); tapping **Hear today's song** lands directly in today's listening ceremony.
9. Settings → Edit profile: name field shows the glass card, no colored avatar glow (accent is nil there).

- [ ] **Step 3: Update the architecture map**

Per project convention, add `OnboardingBloomBackground` and the send-off phase to `docs/ARCHITECTURE.md` (Onboarding section), then:

```bash
git add docs/ARCHITECTURE.md
git commit -m "docs: architecture map — onboarding bloom redesign"
```
