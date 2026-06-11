# Today Journal Preview Dock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the quiet Today "the story" scroll hint with a tappable journal preview dock that visibly introduces the full journal reading zone.

**Architecture:** Add a pure `JournalPreview` helper for preview extraction, test it directly, then wire a private `JournalPreviewDock` into the existing immersive SwiftUI layout. Use `ScrollViewReader` and stable section IDs so tapping the dock scrolls to the journal zone while preserving the existing snap behavior.

**Tech Stack:** Swift, SwiftUI, Swift Testing, Xcode project.

---

### Task 1: Journal Preview Extraction

**Files:**
- Create: `Daily Music/Models/JournalPreview.swift`
- Modify: `Daily MusicTests/ReminderCopyTests.swift`
- Modify: `Daily Music.xcodeproj/project.pbxproj` only if a new test file is chosen instead of reusing an existing test file.

- [ ] **Step 1: Write the failing test**

Add these tests to an existing `Daily MusicTests` file so the target already includes them:

```swift
@Test func journalPreviewUsesFirstNonEmptyParagraphAndStripsMarkdown() {
    let markdown = """

    **Tonight** starts with a bassline that feels like a streetlight turning on.

    The second paragraph should not be part of the preview.
    """

    #expect(JournalPreview.text(from: markdown) == "Tonight starts with a bassline that feels like a streetlight turning on.")
}

@Test func journalPreviewFallsBackWhenMarkdownIsEmpty() {
    #expect(JournalPreview.text(from: "   \n\n ") == "Read the story behind today's song.")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/ReminderCopyTests
```

Expected: fail because `JournalPreview` is not defined.

- [ ] **Step 3: Write minimal implementation**

Create `Daily Music/Models/JournalPreview.swift`:

```swift
import Foundation

enum JournalPreview {
    static let fallback = "Read the story behind today's song."

    static func text(from markdown: String) -> String {
        let paragraph = markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        let stripped = stripInlineMarkdown(from: paragraph)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped.isEmpty ? fallback : stripped
    }

    private static func stripInlineMarkdown(from text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "`", with: "")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS.

### Task 2: Tappable Preview Dock

**Files:**
- Modify: `Daily Music/Views/EntryDetailImmersive.swift`

- [ ] **Step 1: Add scroll target IDs and reader**

Wrap the immersive scroll in `ScrollViewReader`, assign IDs to the song and journal zones, and pass a scroll action into `songZone`.

- [ ] **Step 2: Replace the bottom story label**

Replace:

```swift
Label("the story", systemImage: "chevron.down")
```

with:

```swift
JournalPreviewDock(preview: JournalPreview.text(from: entry.journalMarkdown)) {
    scrollToJournal(proxy)
}
```

- [ ] **Step 3: Add dock view**

Add a private SwiftUI view in `EntryDetailImmersive.swift` that renders a grabber, `Today's journal`, and preview text. It must be a large plain button with accessibility label `Read today's journal` and hint `Opens the story for today's song.`

- [ ] **Step 4: Preserve Reduce Motion**

Use the existing `reduceMotion` environment value to disable animated scrolling when needed.

### Task 3: Verification

**Files:**
- No new files.

- [ ] **Step 1: Run focused tests**

```bash
xcodebuild test -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:Daily_MusicTests/ReminderCopyTests
```

Expected: PASS.

- [ ] **Step 2: Run a build**

```bash
xcodebuild build -scheme "Daily Music" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Review changed files**

```bash
git diff -- "Daily Music/Models/JournalPreview.swift" "Daily Music/Views/EntryDetailImmersive.swift" "Daily MusicTests/ReminderCopyTests.swift" docs/superpowers/plans/2026-06-11-today-journal-preview-dock.md
```

Expected: only the helper, tests, immersive view, and plan changed by this task.
