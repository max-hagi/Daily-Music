# Today Pull Artwork Bleed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Today's existing album-art backdrop through the pull indicator region while preserving the ring's colors and guaranteeing local contrast.

**Architecture:** Extract the immersive backdrop recipe into a reusable SwiftUI view and make Today own that backdrop outside the receding `EntryDetailView`, eliminating the exposed system-background edge. Add a pure ring-style policy that enables an adaptive material backing only for Today's entrance ring, leaving Listening's exit ring unchanged.

**Tech Stack:** Swift 6, SwiftUI, UIKit artwork images, Swift Testing, Xcode 26/iOS 26 simulator

## Global Constraints

- Preserve the ring's existing neutral tint while pulling and green tint when armed.
- Reuse the exact existing blur, saturation, opacity, and immersive gradient values.
- Do not change pull distance, gesture recognition, commit velocity, haptics, transition timing, playback, or collection behavior.
- Keep Listening's exit ring unbacked.
- Preserve Reduce Motion behavior.
- Preserve all existing unstaged return-transition work in `ListeningTransition.swift`, `UIKitListeningTransitionHost.swift`, `TodayView.swift`, and `TodayListeningTests.swift`.
- Do not stage or commit implementation files while they contain pre-existing unstaged work; leave the final implementation as a reviewable working-tree diff.

---

## File Map

- Modify `Daily Music/Views/Components/PullArmingRing.swift`: define the semantic ring placement/style policy and render the optional material backing without changing layout.
- Modify `Daily Music/Views/EntryDetailView.swift`: define backdrop ownership, extract the reusable immersive renderer, and let parent-hosted details omit their own backdrop.
- Modify `Daily Music/Views/TodayView.swift`: host the unscaled shared backdrop and opt the entrance ring into contrast backing.
- Modify `Daily MusicTests/TodayListeningTests.swift`: add focused policy regressions without disturbing the existing transition tests.

### Task 1: Today-Only Pull Ring Contrast

**Files:**
- Modify: `Daily MusicTests/TodayListeningTests.swift`
- Modify: `Daily Music/Views/Components/PullArmingRing.swift`
- Modify: `Daily Music/Views/TodayView.swift`

**Interfaces:**
- Produces: `PullArmingRingPlacement`, `PullArmingRingBacking`, and `PullArmingRingStylePolicy.backing(for:)`.
- Consumes: Today's existing `PullArmingRing` call site and the existing `progress > 0.02` visibility threshold.

- [ ] **Step 1: Write the failing style-policy tests**

Append to `Daily MusicTests/TodayListeningTests.swift`:

```swift
struct PullArmingRingStylePolicyTests {
    @Test func todayEntranceUsesAdaptiveMaterialBacking() {
        #expect(
            PullArmingRingStylePolicy.backing(for: .todayEntrance) == .adaptiveMaterial
        )
    }

    @Test func listeningExitKeepsItsExistingClearBacking() {
        #expect(
            PullArmingRingStylePolicy.backing(for: .listeningExit) == .none
        )
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -only-testing:'Daily MusicTests/PullArmingRingStylePolicyTests'
```

Expected: build fails because `PullArmingRingStylePolicy` and its related types do not exist.

- [ ] **Step 3: Add the minimal style policy**

Add above `PullArmingRing` in `Daily Music/Views/Components/PullArmingRing.swift`:

```swift
enum PullArmingRingPlacement: Equatable {
    case todayEntrance
    case listeningExit
}

enum PullArmingRingBacking: Equatable {
    case none
    case adaptiveMaterial
}

enum PullArmingRingStylePolicy {
    static func backing(for placement: PullArmingRingPlacement) -> PullArmingRingBacking {
        placement == .todayEntrance ? .adaptiveMaterial : .none
    }
}
```

- [ ] **Step 4: Verify the policy test turns GREEN**

Run the Step 2 command again.

Expected: `PullArmingRingStylePolicyTests` passes.

- [ ] **Step 5: Render the backing without changing ring geometry**

Add this property to `PullArmingRing`:

```swift
var placement: PullArmingRingPlacement = .listeningExit
```

Attach this background after the existing `VStack` content and before its opacity:

```swift
.background {
    if PullArmingRingStylePolicy.backing(for: placement) == .adaptiveMaterial {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            }
            .padding(.horizontal, -10)
            .padding(.vertical, -8)
    }
}
```

Because `background` does not participate in layout, the ring and label retain their existing size and position.

- [ ] **Step 6: Opt Today into the material-backed placement**

Update Today's `PullArmingRing` call in `TodayView.enterRingOverlay`:

```swift
PullArmingRing(
    progress: enterArm,
    armed: enterArm >= 1,
    label: enterArm >= 1 ? "Release to listen" : "Keep pulling…",
    tint: .primary,
    pointsUp: false,
    placement: .todayEntrance
)
```

Leave `ListeningView` unchanged so its default `.listeningExit` placement remains unbacked.

- [ ] **Step 7: Run focused tests and review the checkpoint**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -only-testing:'Daily MusicTests/PullArmingRingStylePolicyTests' \
  -only-testing:'Daily MusicTests/TransitionResolverTests' \
  -only-testing:'Daily MusicTests/TransitionMathTests'

git diff --check -- \
  "Daily Music/Views/Components/PullArmingRing.swift" \
  "Daily Music/Views/TodayView.swift" \
  "Daily MusicTests/TodayListeningTests.swift"
```

Expected: all selected tests pass and `git diff --check` prints nothing.

### Task 2: Unscaled Shared Artwork Backdrop

**Files:**
- Modify: `Daily MusicTests/TodayListeningTests.swift`
- Modify: `Daily Music/Views/EntryDetailView.swift`
- Modify: `Daily Music/Views/TodayView.swift`

**Interfaces:**
- Produces: `ImmersiveBackdropOwner`, `ImmersiveBackdropOwnershipPolicy.rendersInEntryDetail(owner:)`, and `ImmersiveArtworkBackdrop(image:accent:)`.
- Consumes: `ArtworkPalette.image`, `ArtworkPalette.accent`, `ArtworkPalette.isLoaded`, and `ArtworkPalette.cached(for:)`.

- [ ] **Step 1: Write the failing backdrop-ownership tests**

Append to `Daily MusicTests/TodayListeningTests.swift`:

```swift
struct ImmersiveBackdropOwnershipPolicyTests {
    @Test func standaloneDetailRendersItsOwnBackdrop() {
        #expect(
            ImmersiveBackdropOwnershipPolicy.rendersInEntryDetail(owner: .entryDetail)
        )
    }

    @Test func todayHostedDetailLeavesBackdropToItsParent() {
        #expect(
            ImmersiveBackdropOwnershipPolicy.rendersInEntryDetail(owner: .parent) == false
        )
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -only-testing:'Daily MusicTests/ImmersiveBackdropOwnershipPolicyTests'
```

Expected: build fails because `ImmersiveBackdropOwnershipPolicy` and `ImmersiveBackdropOwner` do not exist.

- [ ] **Step 3: Add the ownership policy and opt-in property**

Add above `EntryDetailView` in `Daily Music/Views/EntryDetailView.swift`:

```swift
enum ImmersiveBackdropOwner: Equatable {
    case entryDetail
    case parent
}

enum ImmersiveBackdropOwnershipPolicy {
    static func rendersInEntryDetail(owner: ImmersiveBackdropOwner) -> Bool {
        owner == .entryDetail
    }
}
```

Add this property beside `usesImmersiveBackdrop`:

```swift
var immersiveBackdropOwner: ImmersiveBackdropOwner = .entryDetail
```

- [ ] **Step 4: Verify the ownership test turns GREEN**

Run the Step 2 command again.

Expected: `ImmersiveBackdropOwnershipPolicyTests` passes.

- [ ] **Step 5: Extract the exact immersive renderer**

Add this reusable view below the ownership policy:

```swift
struct ImmersiveArtworkBackdrop: View {
    let image: UIImage?
    let accent: Color

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 48)
                    .saturation(1.25)
                    .opacity(0.46)
            }

            LinearGradient(
                colors: [
                    accent.opacity(0.62),
                    accent.opacity(0.28),
                    Color(.systemBackground).opacity(0.9),
                    accent.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
```

Replace `EntryDetailView.backdrop` with a conditional that uses the shared renderer for immersive details and retains the standard gradient verbatim:

```swift
@ViewBuilder
private var backdropContent: some View {
    if usesImmersiveBackdrop {
        ImmersiveArtworkBackdrop(image: backdropImage, accent: backdropAccent)
    } else {
        LinearGradient(
            colors: standardBackdropColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private var backdrop: some View {
    backdropContent
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: palette.accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: palette.isLoaded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: palette.didFinishLoading)
}
```

Delete the now-unused `immersiveBackdropColors` property. Replace `.background(backdrop)` on the root with:

```swift
.background {
    if ImmersiveBackdropOwnershipPolicy.rendersInEntryDetail(owner: immersiveBackdropOwner) {
        backdrop
    }
}
```

- [ ] **Step 6: Make Today own the fixed backdrop**

Pass parent ownership into Today's loaded `EntryDetailView`:

```swift
usesImmersiveBackdrop: true,
immersiveBackdropOwner: .parent,
```

Add this computed view to `TodayView`:

```swift
@ViewBuilder
private var todayArtworkBackdrop: some View {
    if let entry = loadedEntry {
        let cached = ArtworkPalette.cached(for: entry.albumArtURL)
        ImmersiveArtworkBackdrop(
            image: artwork.image ?? cached?.image,
            accent: artwork.isLoaded ? artwork.accent : cached?.accent ?? artwork.accent
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: artwork.accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: artwork.isLoaded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: artwork.didFinishLoading)
    }
}
```

Attach it to the `NavigationStack` content `Group`, outside the scaled loaded branch:

```swift
.background { todayArtworkBackdrop }
```

This keeps the backdrop stationary while the content recedes, so the pull region reveals the same artwork treatment instead of the system window color.

- [ ] **Step 7: Run the focused Today/Listening regression suites**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6' \
  -only-testing:'Daily MusicTests/PullArmingRingStylePolicyTests' \
  -only-testing:'Daily MusicTests/ImmersiveBackdropOwnershipPolicyTests' \
  -only-testing:'Daily MusicTests/TransitionResolverTests' \
  -only-testing:'Daily MusicTests/TransitionMathTests' \
  -only-testing:'Daily MusicTests/ListeningHostMachineTests' \
  -only-testing:'Daily MusicTests/ListeningHostAnimationPolicyTests' \
  -only-testing:'Daily MusicTests/TodayReturnMachineTests'
```

Expected: all selected tests pass with no new warnings.

- [ ] **Step 8: Run the full suite and inspect the final diff**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project "Daily Music.xcodeproj" \
  -scheme "Daily Music" \
  -destination 'platform=iOS Simulator,id=0FE45C94-06D9-4521-904B-F5C95960DEE6'

git diff --check
git diff -- \
  "Daily Music/Views/Components/PullArmingRing.swift" \
  "Daily Music/Views/EntryDetailView.swift" \
  "Daily Music/Views/TodayView.swift" \
  "Daily MusicTests/TodayListeningTests.swift"
```

Expected: the full suite passes; the diff contains only the shared backdrop, Today ownership, Today-only ring backing, tests, and the preserved pre-existing return-transition changes.

- [ ] **Step 9: Verify the interaction visually**

Run Today with one bright and one dark cover in both light and dark system appearances. Pull below threshold and cancel, then pull to commit. Confirm that the album-art bleed remains continuous above the receding content, the ring and label remain legible on their material surface, and there is no white/black cutoff or change to either transition's motion.
