# Open Row Library Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move save-to-library from the Today identity controls into the Open In row, shown only when a save-capable streaming service is linked.

**Architecture:** Extract a tiny pure `OpenInRowState` value so row composition is testable without SwiftUI view introspection. `OpenInSection` owns the visual CTA row and receives save availability/state/actions from `EntryDetailView`; `EntryDetailView` removes save from the title-side controls and existing action cluster to avoid duplicate save affordances.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing `AppEnvironment`, `SavedTracksLog`, and `MusicServiceConnection` save flow.

---

### Task 1: Add Row State Coverage

**Files:**
- Modify: `Daily Music/Views/OpenInSection.swift`
- Test: `Daily MusicTests/OpenInSectionTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Daily MusicTests/OpenInSectionTests.swift`:

```swift
import Testing
@testable import Daily_Music

struct OpenInSectionTests {
    @Test func rowShowsSaveOnlyWhenServiceCanSave() {
        #expect(OpenInRowState(canSaveToLibrary: true, isSaved: false).showsSaveButton)
        #expect(!OpenInRowState(canSaveToLibrary: false, isSaved: false).showsSaveButton)
    }

    @Test func savedRowsRenderAddedStateButStillShowSaveSlot() {
        let state = OpenInRowState(canSaveToLibrary: true, isSaved: true)

        #expect(state.showsSaveButton)
        #expect(state.saveIconName == "checkmark.circle.fill")
        #expect(state.isSaveDisabled)
    }

    @Test func unsavedRowsRenderAddStateAndRemainEnabled() {
        let state = OpenInRowState(canSaveToLibrary: true, isSaved: false)

        #expect(state.saveIconName == "plus.circle")
        #expect(!state.isSaveDisabled)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DailyMusicTests/OpenInSectionTests
```

Expected: FAIL because `OpenInRowState` does not exist yet.

- [ ] **Step 3: Add the pure row state**

Add this near the top of `Daily Music/Views/OpenInSection.swift`, below imports:

```swift
struct OpenInRowState: Equatable {
    let canSaveToLibrary: Bool
    let isSaved: Bool

    var showsSaveButton: Bool { canSaveToLibrary }
    var isSaveDisabled: Bool { isSaved }
    var saveIconName: String { isSaved ? "checkmark.circle.fill" : "plus.circle" }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command as Step 2.

Expected: PASS for `OpenInSectionTests`.

### Task 2: Move Save Into OpenInSection

**Files:**
- Modify: `Daily Music/Views/OpenInSection.swift`
- Modify: `Daily Music/Views/EntryDetailView.swift`
- Modify: `Daily Music/Views/EntryActionCluster.swift`
- Test: `Daily MusicTests/OpenInSectionTests.swift`

- [ ] **Step 1: Update `OpenInSection` API and UI**

Change `OpenInSection` to accept row state and save action:

```swift
struct OpenInSection: View {
    let entry: DailyEntry
    var accent: Color = Theme.Brand.gradient[0]
    var rowState = OpenInRowState(canSaveToLibrary: false, isSaved: false)
    var saveAction: () -> Void = {}

    @AppStorage("settings.preferredStreamingService") private var preferredRaw = StreamingService.appleMusic.rawValue
    @Environment(\.openURL) private var openURL

    private var preferred: StreamingService { StreamingService(rawValue: preferredRaw) ?? .appleMusic }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let url = preferred.url(for: entry) { openURL(url) }
            } label: {
                ZStack {
                    Text("Open in \(preferred.displayName)")
                        .lineLimit(1)

                    HStack {
                        ServiceLogo(service: preferred)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.forward")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.md)
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: accent))

            if rowState.showsSaveButton {
                Button(action: saveAction) {
                    Image(systemName: rowState.saveIconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(rowState.isSaved ? .green : accent)
                        .frame(width: 48, height: 48)
                        .symbolEffect(.bounce, value: rowState.isSaved)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(rowState.isSaveDisabled)
                .accessibilityLabel(rowState.isSaved ? "Added to your Daily Music playlist" : "Save to your Daily Music playlist")
            }

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
            .accessibilityLabel("More streaming services")
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Remove duplicate save controls from identity/action clusters**

In `Daily Music/Views/EntryDetailView.swift`, remove the `if canSaveToLibrary { saveButton(...) }` block from `entryIdentityWithInlineControls`.

In `Daily Music/Views/EntryActionCluster.swift`, remove the same save block from `actionCluster` and `compactActions`, then replace `private func saveToLibrary()` with internal `func saveToLibrary()` so `OpenInSection` can call it from another extension file.

- [ ] **Step 3: Wire `EntryDetailView` into `OpenInSection`**

Add a helper in `EntryActionCluster.swift`:

```swift
var openInRowState: OpenInRowState {
    OpenInRowState(
        canSaveToLibrary: canSaveToLibrary,
        isSaved: env.savedTracks.isSaved(entry)
    )
}
```

Update both `OpenInSection` call sites in `EntryDetailView.swift` and `EntryDetailImmersive.swift`:

```swift
OpenInSection(
    entry: entry,
    accent: palette.accent,
    rowState: openInRowState,
    saveAction: saveToLibrary
)
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DailyMusicTests/OpenInSectionTests
```

Expected: PASS.

- [ ] **Step 5: Run a compile-oriented app test target check**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DailyMusicTests/StreamingServiceTests
```

Expected: PASS, proving the app and test target compile with the changed SwiftUI signatures.

### Task 3: Final Verification

**Files:**
- Verify: changed files from Tasks 1-2

- [ ] **Step 1: Inspect the final diff**

Run:

```bash
git diff -- "Daily Music/Views/OpenInSection.swift" "Daily Music/Views/EntryDetailView.swift" "Daily Music/Views/EntryDetailImmersive.swift" "Daily Music/Views/EntryActionCluster.swift" "Daily MusicTests/OpenInSectionTests.swift"
```

Expected: Diff shows Save removed from identity/action clusters and added to `OpenInSection`.

- [ ] **Step 2: Run focused verification**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DailyMusicTests/OpenInSectionTests -only-testing:DailyMusicTests/StreamingServiceTests
```

Expected: PASS.
