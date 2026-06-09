# Liquid Glass Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reusable Liquid Glass styling helpers and apply them to the app's strongest custom floating/card surfaces.

**Architecture:** Keep Liquid Glass adoption centralized in `Styles.swift` so repeated cards and pills can opt in without duplicating shape, tint, or stroke details. Migrate only surfaces that float over color/artwork or act as transient chrome; keep long reading surfaces and dense native lists opaque/native.

**Tech Stack:** SwiftUI, iOS 26 Liquid Glass (`glassEffect`), Swift Testing, Xcode project.

---

### Task 1: Reusable Glass Styles

**Files:**
- Modify: `Daily Music/DesignSystem/Styles.swift`
- Create: `Daily MusicTests/LiquidGlassStyleTests.swift`

- [ ] Add compile-time Swift Testing coverage for `glassCardStyle`, `glassPillStyle`, and `glassIconButtonStyle`.
- [ ] Run the focused test and verify it fails because the modifiers do not exist.
- [ ] Implement the three modifiers in `Styles.swift`.
- [ ] Run the focused test and verify it passes.

### Task 2: Migrate High-Value Surfaces

**Files:**
- Modify: `Daily Music/Views/EntryDetailView.swift`
- Modify: `Daily Music/Views/VaultView.swift`
- Modify: `Daily Music/Views/FavoritesView.swift`
- Modify: `Daily Music/Views/SongInfoSheet.swift`
- Modify: `Daily Music/Views/Components/UndoToast.swift`

- [ ] Replace eligible `.regularMaterial` and `Theme.Surface.card` capsules/cards with the reusable glass modifiers.
- [ ] Preserve opaque journal/story reading surfaces.
- [ ] Preserve saturated primary action buttons.
- [ ] Keep `TasteMirrorBoard.swift` changes minimal because the file already has local edits and already uses Liquid Glass heavily.

### Task 3: Verify

**Files:**
- Verify all modified Swift files.

- [ ] Run the new focused test.
- [ ] Run the available app test suite or, if simulator access is unavailable, at least run an Xcode build/test command and report the blocker precisely.
- [ ] Inspect `git diff` to ensure changes are scoped to Liquid Glass adoption.
