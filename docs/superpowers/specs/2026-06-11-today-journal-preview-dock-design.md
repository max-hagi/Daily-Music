# Today Journal Preview Dock — Design Spec

- **Date:** 2026-06-11
- **App:** Daily Music
- **Status:** Approved design direction; ready for implementation planning.
- **Goal:** Make the Today journal feel like a core part of the daily ritual instead of a hidden second section, while preserving the song-first emotional opening.

## 1. Problem

Today currently presents the song as a full-screen immersive zone and places the journal in a separate reading zone reached by scrolling. The bottom hint, `the story`, is elegant but too quiet: it reads like a decorative affordance rather than a major part of the experience. Users can miss that the journal exists, even though it is one of the app's defining pieces of content.

## 2. Chosen Direction

Use a **Journal Preview Dock** at the bottom of the Today song zone.

The song remains the first impression: artwork, title, artist, rating, reactions, and Open In keep their priority. The journal becomes visibly present as a rounded reading surface peeking up from the bottom of the viewport. This tells users that the story is waiting without turning Today into a text-first screen.

## 3. First-Screen Layout

Replace the existing bottom `Label("the story", systemImage: "chevron.down")` in the immersive Today layout with a compact dock containing:

- A centered grabber handle.
- A heading: `Today's journal`.
- Two or three preview lines derived from `entry.journalMarkdown`.
- A clear tap target that opens the full journal zone.

The dock should sit above the bottom safe area and visually overlap the artwork backdrop as a calm, opaque or near-opaque surface. It should feel like the top edge of the reading mode, not a floating promo card.

## 4. Interaction

- **Scroll:** Existing vertical scroll behavior remains. Dragging upward from the song zone still reveals the journal zone.
- **Tap:** Tapping the dock scrolls to the journal zone.
- **Motion:** The dock may use a subtle first-appearance lift or opacity transition. Respect Reduce Motion.
- **Snap:** Preserve the current snap behavior so the transition from song zone to reading zone remains intentional.

## 5. Reading Zone

The full journal zone remains the calm reading-mode surface:

- Opaque `systemBackground` or equivalent reading surface.
- Rounded top shape.
- Grabber handle.
- Title and `JournalText`.

The preview dock should visually connect to this zone. When users open the journal, it should feel like the dock became the reading surface rather than like a separate component disappeared.

## 6. Content Rules

Preview text should be derived from the first non-empty paragraph of `entry.journalMarkdown`.

- Strip Markdown enough for a clean preview.
- Limit to two or three lines.
- If the journal is empty or parsing fails, fall back to a quiet generic line such as `Read the story behind today's song.`
- Do not expose a separate long CTA label unless needed for accessibility. The dock itself is the affordance.

## 7. Accessibility

- The dock must be a single large accessible button.
- Accessibility label: `Read today's journal`.
- Accessibility hint: `Opens the story for today's song.`
- Dynamic Type should not break the song zone. The preview can clamp line count, while the full journal remains fully scalable.
- Reduce Motion disables any lift, pulse, or scroll-transition embellishment that is not essential.

## 8. Implementation Surface

Primary file:

- `Daily Music/Views/EntryDetailImmersive.swift`

Likely additions:

- `JournalPreviewDock` private view.
- A small helper to produce journal preview text.
- A scroll target or `ScrollViewReader` path so tapping the dock moves to the journal zone.

Keep the change scoped to the immersive Today/detail presentation. Vault and Favorites should not inherit a bottom dock unless they use the same immersive layout intentionally.

## 9. Non-Goals

- Do not redesign the entire Today screen.
- Do not make the journal the first hero.
- Do not add a modal sheet for the journal.
- Do not replace the existing full journal reading zone.
- Do not change journal Markdown rendering beyond preview extraction.

## 10. Success Criteria

- The journal is visibly discoverable on first load.
- The album art still feels like the primary emotional hook.
- The preview dock reads as a natural part of the screen, not an ad or unrelated card.
- Tapping the dock reliably opens the full journal.
- Existing scroll behavior, Reduce Motion support, and journal rendering continue to work.
